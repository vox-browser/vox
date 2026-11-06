#ifndef VOX_HTTP_TLS_SESSIONS_H
#define VOX_HTTP_TLS_SESSIONS_H
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <time.h>
#include "mbedtls/ssl.h"
#include "mbedtls/sha256.h"
#include "vox_native_state.h"

#define VOX_TLS12_SESSION_LIMIT 64
#define VOX_TLS12_SESSION_LIFETIME_NS UINT64_C(60000000000)
typedef struct {
    bool occupied;
    unsigned char key[32];
    unsigned char identity[32];
    uint64_t saved_ns, used_ns;
    mbedtls_x509_time valid_from, valid_to;
    mbedtls_ssl_session session;
} VoxTLS12Session;
VOX_NATIVE_STATE pthread_mutex_t vox_tls12_sessions_lock VOX_NATIVE_STATE_INIT(PTHREAD_MUTEX_INITIALIZER);
VOX_NATIVE_STATE pthread_once_t vox_tls12_sessions_once VOX_NATIVE_STATE_INIT(PTHREAD_ONCE_INIT);
VOX_NATIVE_STATE VoxTLS12Session vox_tls12_sessions[VOX_TLS12_SESSION_LIMIT];

static uint64_t vox_tls12_monotonic_ns(void)
{
    struct timespec now;
    if (clock_gettime(CLOCK_MONOTONIC, &now) || now.tv_sec < 0)
        return 0;
    return (uint64_t)now.tv_sec * UINT64_C(1000000000) + (uint64_t)now.tv_nsec;
}

static void vox_tls12_drop(VoxTLS12Session* entry)
{
    if (entry->occupied)
        mbedtls_ssl_session_free(&entry->session);
    memset(entry, 0, sizeof(*entry));
}

static void vox_tls12_sessions_clear(void)
{
    pthread_mutex_lock(&vox_tls12_sessions_lock);
    for (unsigned index = 0; index < VOX_TLS12_SESSION_LIMIT; ++index)
        vox_tls12_drop(&vox_tls12_sessions[index]);
    pthread_mutex_unlock(&vox_tls12_sessions_lock);
}

static void vox_tls12_sessions_init(void)
{
    if (atexit(vox_tls12_sessions_clear))
        abort();
}

static bool vox_tls12_hash_part(mbedtls_sha256_context* hash, const void* bytes, size_t length)
{
    unsigned char size[8];
    for (unsigned index = 0; index < sizeof(size); ++index)
        size[index] = (unsigned char)((uint64_t)length >> (index * 8));
    return !mbedtls_sha256_update(hash, size, sizeof(size))
        && (!length || !mbedtls_sha256_update(hash, bytes, length));
}

// Avoid hashing an entire system trust store on connections to TLS1.3-only
// origins: compute the trust key only when a TLS1.2 entry can be restored, or
// after a newly authenticated TLS1.2 handshake can produce one.
static bool vox_tls12_session_identity(unsigned char output[32], const void* identity,
    uint64_t identity_length, const void* protocols)
{
    if (!identity || !identity_length)
        return false;
    const char* const* alpn = protocols;
    mbedtls_sha256_context hash;mbedtls_sha256_init(&hash);
    static const char domain[] = "Vox TLS1.2 identity";
    bool valid = !mbedtls_sha256_starts(&hash, 0)
        && vox_tls12_hash_part(&hash, domain, sizeof(domain) - 1)
        && vox_tls12_hash_part(&hash, identity, (size_t)identity_length);
    if (alpn) {
        for (unsigned index = 0; valid && alpn[index]; ++index)
            valid = index < 64 && vox_tls12_hash_part(&hash, alpn[index], strlen(alpn[index]));
    }
    if (valid)
        valid = !mbedtls_sha256_finish(&hash, output);
    mbedtls_sha256_free(&hash);return valid;
}

static bool vox_tls12_entry_valid(const VoxTLS12Session* entry, uint64_t now)
{
    return now >= entry->saved_ns && now - entry->saved_ns < VOX_TLS12_SESSION_LIFETIME_NS
        && !mbedtls_x509_time_is_future(&entry->valid_from)
        && !mbedtls_x509_time_is_past(&entry->valid_to);
}

static bool vox_tls12_identity_cached(const unsigned char identity[32], uint64_t now)
{
    if (!now)
        return false;
    pthread_once(&vox_tls12_sessions_once, vox_tls12_sessions_init);
    bool found = false;pthread_mutex_lock(&vox_tls12_sessions_lock);
    for (unsigned index = 0; index < VOX_TLS12_SESSION_LIMIT; ++index) {
        VoxTLS12Session* entry = &vox_tls12_sessions[index];
        if (!entry->occupied || memcmp(entry->identity, identity, 32))
            continue;
        if (!vox_tls12_entry_valid(entry, now))
            vox_tls12_drop(entry);
        else
            found = true;
    }
    pthread_mutex_unlock(&vox_tls12_sessions_lock);return found;
}

// The existing transport identity partitions origin, proxy, protocol options,
// verification policy and client credentials. Hash the actual parsed trust
// bytes too: changing a CA file at the same path must never resume old trust.
static bool vox_tls12_session_key(unsigned char output[32], const void* identity,
    uint64_t identity_length, const void* trust, const void* protocols)
{
    const mbedtls_x509_crt* ca = trust;
    const char* const* alpn = protocols;
    if (!identity || !identity_length || !ca || !ca->raw.p || !ca->raw.len)
        return false;
    mbedtls_sha256_context hash;
    mbedtls_sha256_init(&hash);
    bool valid = !mbedtls_sha256_starts(&hash, 0)
        && vox_tls12_hash_part(&hash, "Vox verified TLS 1.2", 20)
        && vox_tls12_hash_part(&hash, identity, (size_t)identity_length);
    unsigned count = 0;
    for (; valid && ca; ca = ca->next) {
        // Refuse caching for an empty, unusually large or time-invalid trust
        // set. The caller still performs its ordinary verified full handshake.
        valid = ++count <= 1024 && ca->raw.p && ca->raw.len
            && !mbedtls_x509_time_is_future(&ca->valid_from)
            && !mbedtls_x509_time_is_past(&ca->valid_to)
            && vox_tls12_hash_part(&hash, ca->raw.p, ca->raw.len);
    }
    if (valid)
        valid = vox_tls12_hash_part(&hash, NULL, 0);
    if (alpn) {
        for (unsigned index = 0; valid && alpn[index]; ++index)
            valid = index < 64 && vox_tls12_hash_part(&hash, alpn[index], strlen(alpn[index]));
    }
    if (valid)
        valid = !mbedtls_sha256_finish(&hash, output);
    mbedtls_sha256_free(&hash);
    return valid;
}

// 0 is a miss, 1 a loaded session, negative values are backend errors. A failed
// copy can partly modify the SSL context; the caller must close it on an error.
static int vox_tls12_session_restore(void* context, const unsigned char key[32], uint64_t now)
{
    if (!now)
        return false;
    pthread_once(&vox_tls12_sessions_once, vox_tls12_sessions_init);
    int restored = 0;
    pthread_mutex_lock(&vox_tls12_sessions_lock);
    for (unsigned index = 0; index < VOX_TLS12_SESSION_LIMIT; ++index) {
        VoxTLS12Session* entry = &vox_tls12_sessions[index];
        if (!entry->occupied || memcmp(entry->key, key, 32))
            continue;
        if (!vox_tls12_entry_valid(entry, now)) {
            vox_tls12_drop(entry);
        } else {
            int result = mbedtls_ssl_set_session(context, &entry->session);
            if (!result) {
                entry->used_ns = now;
                restored = 1;
            } else {
                restored = result;
            }
        }
        break;
    }
    pthread_mutex_unlock(&vox_tls12_sessions_lock);
    return restored;
}

static void vox_tls12_session_forget(const unsigned char key[32])
{
    pthread_mutex_lock(&vox_tls12_sessions_lock);
    for (unsigned index = 0; index < VOX_TLS12_SESSION_LIMIT; ++index) {
        VoxTLS12Session* entry = &vox_tls12_sessions[index];
        if (entry->occupied && !memcmp(entry->key, key, 32))
            vox_tls12_drop(entry);
    }
    pthread_mutex_unlock(&vox_tls12_sessions_lock);
}

static int vox_tls12_compare_time(const mbedtls_x509_time* a, const mbedtls_x509_time* b)
{
    const int left[] = { a->year, a->mon, a->day, a->hour, a->min, a->sec };
    const int right[] = { b->year, b->mon, b->day, b->hour, b->min, b->sec };
    for (unsigned index = 0; index < sizeof(left) / sizeof(left[0]); ++index) {
        if (left[index] != right[index])
            return left[index] < right[index] ? -1 : 1;
    }
    return 0;
}

static bool vox_tls12_authenticated(const void* context)
{
    const mbedtls_ssl_context* ssl = context;
    return !strcmp(mbedtls_ssl_get_version(ssl), "TLSv1.2")
        && !mbedtls_ssl_get_verify_result(ssl) && mbedtls_ssl_get_peer_cert(ssl);
}

static bool vox_tls12_session_save(const void* context, const unsigned char key[32],
    const unsigned char identity[32], uint64_t now)
{
    const mbedtls_ssl_context* ssl = context;
    // TLS 1.3 tickets arrive during later reads. Leave that existing backend
    // path unchanged rather than treating its handshake as a usable ticket.
    if (!now || !vox_tls12_authenticated(ssl))
        return false;
    const mbedtls_x509_crt* peer = mbedtls_ssl_get_peer_cert(ssl);
    if (!peer)
        return false;
    mbedtls_x509_time from = peer->valid_from, to = peer->valid_to;
    unsigned count = 0;
    for (; peer; peer = peer->next) {
        if (++count > 64 || mbedtls_x509_time_is_future(&peer->valid_from)
            || mbedtls_x509_time_is_past(&peer->valid_to))
            return false;
        if (vox_tls12_compare_time(&from, &peer->valid_from) < 0)
            from = peer->valid_from;
        if (vox_tls12_compare_time(&to, &peer->valid_to) > 0)
            to = peer->valid_to;
    }
    pthread_once(&vox_tls12_sessions_once, vox_tls12_sessions_init);
    pthread_mutex_lock(&vox_tls12_sessions_lock);
    unsigned selected = 0;
    bool empty = false;
    for (unsigned index = 0; index < VOX_TLS12_SESSION_LIMIT; ++index) {
        VoxTLS12Session* entry = &vox_tls12_sessions[index];
        if (entry->occupied && !memcmp(entry->key, key, 32)) {
            // Keep the original full-handshake certificate window and fixed
            // lifetime. Concurrent initial dials must not refresh an entry.
            pthread_mutex_unlock(&vox_tls12_sessions_lock);
            return false;
        }
        if (!entry->occupied && !empty) {
            selected = index;
            empty = true;
        } else if (!empty && entry->used_ns < vox_tls12_sessions[selected].used_ns) {
            selected = index;
        }
    }
    VoxTLS12Session* entry = &vox_tls12_sessions[selected];
    vox_tls12_drop(entry);
    mbedtls_ssl_session_init(&entry->session);
    bool saved = !mbedtls_ssl_get_session(ssl, &entry->session);
    if (saved) {
        memcpy(entry->key, key, 32);
        memcpy(entry->identity, identity, 32);
        entry->saved_ns = entry->used_ns = now;
        entry->valid_from = from;
        entry->valid_to = to;
        entry->occupied = true;
    } else {
        mbedtls_ssl_session_free(&entry->session);
    }
    pthread_mutex_unlock(&vox_tls12_sessions_lock);
    return saved;
}
#endif
