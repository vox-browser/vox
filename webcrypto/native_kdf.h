/* SPDX-License-Identifier: BSD-2-Clause */
#ifndef VOX_NATIVE_KDF_H
#define VOX_NATIVE_KDF_H
#include <stdint.h>
#include <string.h>
#include <openssl/core_names.h>
#include <openssl/evp.h>
#include <openssl/kdf.h>
#include <openssl/params.h>
#if OPENSSL_VERSION_NUMBER >= 0x30200000L
#include <openssl/thread.h>
#endif

/* LibCrypto/Hash/HKDF.cpp and PBKDF2.cpp provider parameters/derivation. */
#include "openssl_dispatch_darwin.h"

static int vox_kdf_derive(int pbkdf2, const char* hash, const unsigned char* key, size_t key_size,
    const unsigned char* salt, size_t salt_size, const unsigned char* info, size_t info_size,
    uint32_t iterations, unsigned char* output, size_t output_size)
{
    if (!vox_crypto_prepare()) return 0;
    int success = 0;
    static unsigned char empty_salt = 0;
    EVP_KDF* kdf = EVP_KDF_fetch(NULL, pbkdf2 ? "PBKDF2" : "HKDF", NULL);
    EVP_KDF_CTX* ctx = kdf ? EVP_KDF_CTX_new(kdf) : NULL;
    OSSL_PARAM params[5] = { OSSL_PARAM_END, OSSL_PARAM_END, OSSL_PARAM_END, OSSL_PARAM_END, OSSL_PARAM_END };
    if (!ctx) goto cleanup;
    params[0] = (OSSL_PARAM)OSSL_PARAM_utf8_string(OSSL_KDF_PARAM_DIGEST, (char*)hash, strlen(hash));
    params[1] = (OSSL_PARAM)OSSL_PARAM_octet_string(pbkdf2 ? OSSL_KDF_PARAM_PASSWORD : OSSL_KDF_PARAM_KEY, (void*)key, key_size);
    if (pbkdf2) {
        params[2] = (OSSL_PARAM)OSSL_PARAM_octet_string(OSSL_KDF_PARAM_SALT, (void*)salt, salt_size);
        params[3] = (OSSL_PARAM)OSSL_PARAM_uint32(OSSL_KDF_PARAM_ITER, &iterations);
    } else {
        params[2] = (OSSL_PARAM)OSSL_PARAM_octet_string(OSSL_KDF_PARAM_INFO, (void*)info, info_size);
        /* Upstream explicitly supplies a non-null pointer for present empty salt. */
        params[3] = (OSSL_PARAM)OSSL_PARAM_octet_string(OSSL_KDF_PARAM_SALT, (void*)(salt ? salt : &empty_salt), salt_size);
    }
    success = EVP_KDF_derive(ctx, output, output_size, params) == 1;
cleanup:
    EVP_KDF_CTX_free(ctx); EVP_KDF_free(kdf);
    return success;
}
/* LibCrypto/Hash/Argon2.cpp keeps optional secret/ad and the native thread cap. */
static const char* vox_argon2(const char* name, const unsigned char* password, size_t password_size,
    const unsigned char* nonce, size_t nonce_size, uint32_t parallelism, uint32_t memory,
    uint32_t passes, const unsigned char* secret, size_t secret_size, int has_secret,
    const unsigned char* ad, size_t ad_size, int has_ad, unsigned char* output, uint32_t tag_size)
{
    if (!vox_crypto_prepare()) return "OpenSSL WebCrypto backend is unavailable";
#if OPENSSL_VERSION_NUMBER >= 0x30200000L
    EVP_KDF* kdf = EVP_KDF_fetch(NULL, name, NULL);
    EVP_KDF_CTX* ctx = kdf ? EVP_KDF_CTX_new(kdf) : NULL;
    const char* failure = NULL;
    uint32_t version = 19;
    uint32_t threads = OSSL_get_max_threads(NULL);
    if (threads > parallelism) threads = parallelism;
    OSSL_PARAM params[11] = {
        OSSL_PARAM_uint32(OSSL_KDF_PARAM_ARGON2_LANES, &parallelism),
        OSSL_PARAM_uint32(OSSL_KDF_PARAM_ARGON2_MEMCOST, &memory),
        OSSL_PARAM_octet_string(OSSL_KDF_PARAM_SALT, (void*)nonce, nonce_size),
        OSSL_PARAM_octet_string(OSSL_KDF_PARAM_PASSWORD, (void*)password, password_size),
        OSSL_PARAM_uint32(OSSL_KDF_PARAM_ARGON2_VERSION, &version),
        OSSL_PARAM_uint32(OSSL_KDF_PARAM_ITER, &passes),
        OSSL_PARAM_uint32(OSSL_KDF_PARAM_SIZE, &tag_size),
        OSSL_PARAM_END, OSSL_PARAM_END, OSSL_PARAM_END, OSSL_PARAM_END,
    };
    if (!ctx) { failure = "EVP_KDF_CTX_new(m_kdf) failed"; goto cleanup; }
    int index = 7;
    if (threads) params[index++] = (OSSL_PARAM)OSSL_PARAM_uint32(OSSL_KDF_PARAM_THREADS, &threads);
    if (has_secret) params[index++] = (OSSL_PARAM)OSSL_PARAM_octet_string(OSSL_KDF_PARAM_SECRET, (void*)secret, secret_size);
    if (has_ad) params[index++] = (OSSL_PARAM)OSSL_PARAM_octet_string(OSSL_KDF_PARAM_ARGON2_AD, (void*)ad, ad_size);
    if (EVP_KDF_derive(ctx, output, tag_size, params) != 1)
        failure = "EVP_KDF_derive(ctx.ptr(), buf.data(), tag_length, params) failed";
cleanup:
    EVP_KDF_CTX_free(ctx); EVP_KDF_free(kdf);
    return failure;
#else
    return "Argon2 requires OpenSSL 3.2 or newer";
#endif
}
#endif
