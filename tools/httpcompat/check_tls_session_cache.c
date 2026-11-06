/* Independent primitive/lifetime checks for the same native session owner. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "mbedtls/net_sockets.h"
#include "mbedtls/entropy.h"
#include "mbedtls/ctr_drbg.h"
#include "psa/crypto.h"
#include "vox_tls_sessions.h"

#define REQUIRE(value) do { if (!(value)) { fprintf(stderr, "check line=%d\n", __LINE__); exit(2); } } while (0)
#define OK(expr) do { int result_ = (expr); if (result_) { fprintf(stderr, "backend line=%d code=%d\n", __LINE__, result_); exit(3); } } while (0)
typedef struct {
    mbedtls_net_context net;
    mbedtls_ssl_context ssl;
    mbedtls_ssl_config conf;
    mbedtls_x509_crt ca;
    mbedtls_entropy_context entropy;
    mbedtls_ctr_drbg_context rng;
} Connection;
static const char* const protocols[] = { "http/1.1", NULL };
static const char* endpoint;
static const char* trust_path;

static void initialize(Connection* connection)
{
    memset(connection, 0, sizeof(*connection));
    mbedtls_net_init(&connection->net);
    mbedtls_ssl_init(&connection->ssl);
    mbedtls_ssl_config_init(&connection->conf);
    mbedtls_x509_crt_init(&connection->ca);
    mbedtls_entropy_init(&connection->entropy);
    mbedtls_ctr_drbg_init(&connection->rng);
    OK(mbedtls_ctr_drbg_seed(&connection->rng, mbedtls_entropy_func, &connection->entropy, NULL, 0));
    OK(mbedtls_x509_crt_parse_file(&connection->ca, trust_path));
    OK(mbedtls_ssl_config_defaults(&connection->conf, MBEDTLS_SSL_IS_CLIENT,
        MBEDTLS_SSL_TRANSPORT_STREAM, MBEDTLS_SSL_PRESET_DEFAULT));
    mbedtls_ssl_conf_rng(&connection->conf, mbedtls_ctr_drbg_random, &connection->rng);
    mbedtls_ssl_conf_authmode(&connection->conf, MBEDTLS_SSL_VERIFY_REQUIRED);
    mbedtls_ssl_conf_ca_chain(&connection->conf, &connection->ca, NULL);
    mbedtls_ssl_conf_min_tls_version(&connection->conf, MBEDTLS_SSL_VERSION_TLS1_2);
    mbedtls_ssl_conf_max_tls_version(&connection->conf, MBEDTLS_SSL_VERSION_TLS1_2);
    OK(mbedtls_ssl_conf_alpn_protocols(&connection->conf, (const char**)protocols));
    OK(mbedtls_ssl_setup(&connection->ssl, &connection->conf));
    OK(mbedtls_ssl_set_hostname(&connection->ssl, "localhost"));
}

static void key_for(Connection* connection, const char* identity, unsigned char key[32], unsigned char group[32])
{
    REQUIRE(vox_tls12_session_identity(group, identity, strlen(identity), protocols));
    REQUIRE(vox_tls12_session_key(key, identity, strlen(identity), &connection->ca, protocols));
}

static void connect_and_fetch(Connection* connection, const char* name, unsigned action)
{
    OK(mbedtls_net_connect(&connection->net, "127.0.0.1", endpoint, MBEDTLS_NET_PROTO_TCP));
    mbedtls_ssl_set_bio(&connection->ssl, &connection->net, mbedtls_net_send, mbedtls_net_recv, NULL);
    int result;
    do { result = mbedtls_ssl_handshake(&connection->ssl); }
    while (result == MBEDTLS_ERR_SSL_WANT_READ || result == MBEDTLS_ERR_SSL_WANT_WRITE);
    OK(result);
    REQUIRE(!mbedtls_ssl_get_verify_result(&connection->ssl));
    REQUIRE(!strcmp(mbedtls_ssl_get_version(&connection->ssl), "TLSv1.2"));
    char request[512];
    int length = snprintf(request, sizeof(request), "GET /same HTTP/1.1\r\nHost: localhost\r\n"
        "X-Vox-TLS-Case: native-%s\r\nX-Vox-TLS-Action: %u-0\r\nConnection: close\r\n\r\n", name, action);
    REQUIRE(length > 0 && (size_t)length < sizeof(request));
    for (size_t sent = 0; sent < (size_t)length;) {
        result = mbedtls_ssl_write(&connection->ssl, (unsigned char*)request + sent, (size_t)length - sent);
        REQUIRE(result > 0);sent += (size_t)result;
    }
    char response[4096] = { 0 };size_t used = 0;
    while (!strstr(response, "\r\n\r\nok")) {
        result = mbedtls_ssl_read(&connection->ssl, (unsigned char*)response + used, sizeof(response) - used - 1);
        if (result == MBEDTLS_ERR_SSL_WANT_READ || result == MBEDTLS_ERR_SSL_WANT_WRITE)
            continue;
        REQUIRE(result > 0);used += (size_t)result;REQUIRE(used < sizeof(response) - 1);response[used] = 0;
    }
    REQUIRE(strstr(response, " 200 "));
}

static void release(Connection* connection)
{
    mbedtls_ssl_free(&connection->ssl);mbedtls_ssl_config_free(&connection->conf);
    mbedtls_net_free(&connection->net);mbedtls_x509_crt_free(&connection->ca);
    mbedtls_ctr_drbg_free(&connection->rng);mbedtls_entropy_free(&connection->entropy);
}

static unsigned entries(void)
{
    unsigned count = 0;pthread_mutex_lock(&vox_tls12_sessions_lock);
    for (unsigned index = 0; index < VOX_TLS12_SESSION_LIMIT; ++index)
        count += vox_tls12_sessions[index].occupied ? 1 : 0;
    pthread_mutex_unlock(&vox_tls12_sessions_lock);return count;
}

static void check_expiry_and_inflight_ownership(void)
{
    vox_tls12_sessions_clear();Connection first;initialize(&first);unsigned char key[32], group[32];
    key_for(&first, "expiry", key, group);connect_and_fetch(&first, "expiry", 0);
    uint64_t now = vox_tls12_monotonic_ns();REQUIRE(now);
    REQUIRE(vox_tls12_session_save(&first.ssl, key, group, now));release(&first);REQUIRE(entries() == 1);
    REQUIRE(vox_tls12_identity_cached(group, now + UINT64_C(59000000000)));
    Connection in_flight;initialize(&in_flight);
    REQUIRE(vox_tls12_session_restore(&in_flight.ssl, key, now + UINT64_C(59000000000)) == 1);
    // Expiry removes the cache owner, while the earlier copy remains usable.
    REQUIRE(vox_tls12_session_restore(&in_flight.ssl, key, now + UINT64_C(61000000000)) == 0);
    REQUIRE(!vox_tls12_identity_cached(group, now));
    REQUIRE(entries() == 0);connect_and_fetch(&in_flight, "expiry", 1);release(&in_flight);
    Connection fresh;initialize(&fresh);
    REQUIRE(vox_tls12_session_restore(&fresh.ssl, key, vox_tls12_monotonic_ns()) == 0);
    connect_and_fetch(&fresh, "expiry", 2);release(&fresh);
    puts("CACHE_CASE expiry passed");
}

static void check_eviction_and_existing_key_after_a_hole(void)
{
    vox_tls12_sessions_clear();unsigned char keys[66][32], groups[66][32];
    uint64_t now = vox_tls12_monotonic_ns();REQUIRE(now);
    for (unsigned index = 0; index < 64; ++index) {
        // Since Mbed TLS3.0 a session can be exported only once. Use a fresh
        // verified connection for each exported owner, as production does.
        Connection seed;initialize(&seed);connect_and_fetch(&seed, "eviction", index);
        char identity[64];snprintf(identity, sizeof(identity), "eviction-%u", index);
        key_for(&seed, identity, keys[index], groups[index]);
        REQUIRE(vox_tls12_session_save(&seed.ssl, keys[index], groups[index], now + index));
        release(&seed);
    }
    REQUIRE(entries() == 64);Connection reader;initialize(&reader);
    REQUIRE(vox_tls12_session_restore(&reader.ssl, keys[0], now + 1000) == 1);
    Connection overflow;initialize(&overflow);connect_and_fetch(&overflow, "eviction", 64);
    key_for(&overflow, "eviction-64", keys[64], groups[64]);
    REQUIRE(vox_tls12_session_save(&overflow.ssl, keys[64], groups[64], now + 2000));REQUIRE(entries() == 64);
    release(&overflow);connect_and_fetch(&reader, "eviction", 65);release(&reader);
    Connection missing;initialize(&missing);
    REQUIRE(vox_tls12_session_restore(&missing.ssl, keys[1], now + 3000) == 0);
    connect_and_fetch(&missing, "eviction", 66);
    Connection expired;initialize(&expired);
    REQUIRE(vox_tls12_session_restore(&expired.ssl, keys[10], now + UINT64_C(61000000000)) == 0);
    REQUIRE(entries() == 63);
    REQUIRE(!vox_tls12_session_save(&missing.ssl, keys[53], groups[53], now + 4000));REQUIRE(entries() == 63);
    key_for(&missing, "eviction-65", keys[65], groups[65]);
    REQUIRE(vox_tls12_session_save(&missing.ssl, keys[65], groups[65], now + 5000));REQUIRE(entries() == 64);
    release(&expired);release(&missing);vox_tls12_sessions_clear();REQUIRE(entries() == 0);
    puts("CACHE_CASE eviction passed");
}

static void check_failed_copy_does_not_become_a_hit(void)
{
    vox_tls12_sessions_clear();Connection first;initialize(&first);unsigned char key[32], group[32];
    key_for(&first, "copy-error", key, group);connect_and_fetch(&first, "copy-error", 0);
    REQUIRE(vox_tls12_session_save(&first.ssl, key, group, vox_tls12_monotonic_ns()));release(&first);
    mbedtls_ssl_context unset;mbedtls_ssl_init(&unset);
    REQUIRE(vox_tls12_session_restore(&unset, key, vox_tls12_monotonic_ns()) < 0);
    mbedtls_ssl_free(&unset);REQUIRE(entries() == 1);
    Connection good;initialize(&good);
    REQUIRE(vox_tls12_session_restore(&good.ssl, key, vox_tls12_monotonic_ns()) == 1);
    vox_tls12_session_forget(key);REQUIRE(entries() == 0);
    REQUIRE(!vox_tls12_identity_cached(group, vox_tls12_monotonic_ns()));
    connect_and_fetch(&good, "copy-error", 1);release(&good);
    Connection fresh;initialize(&fresh);
    REQUIRE(vox_tls12_session_restore(&fresh.ssl, key, vox_tls12_monotonic_ns()) == 0);
    connect_and_fetch(&fresh, "copy-error", 2);release(&fresh);vox_tls12_sessions_clear();
    puts("CACHE_CASE copy-error passed");
}

int main(int argc, char** argv)
{
    REQUIRE(argc == 3);endpoint = argv[1];trust_path = argv[2];OK(psa_crypto_init());
    check_expiry_and_inflight_ownership();check_eviction_and_existing_key_after_a_hole();
    check_failed_copy_does_not_become_a_hit();return 0;
}
