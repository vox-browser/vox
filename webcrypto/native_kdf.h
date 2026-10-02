/* SPDX-License-Identifier: BSD-2-Clause */
#ifndef VOX_NATIVE_KDF_H
#define VOX_NATIVE_KDF_H
#include <stdint.h>
#include <string.h>
#include <openssl/core_names.h>
#include <openssl/evp.h>
#include <openssl/kdf.h>
#include <openssl/params.h>

/* LibCrypto/Hash/HKDF.cpp and PBKDF2.cpp provider parameters/derivation. */
static int vox_kdf_derive(int pbkdf2, const char* hash, const unsigned char* key, size_t key_size,
    const unsigned char* salt, size_t salt_size, const unsigned char* info, size_t info_size,
    uint32_t iterations, unsigned char* output, size_t output_size)
{
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
#endif
