/* Copyright (c) 2026, Ladybird contributors
 * SPDX-License-Identifier: BSD-2-Clause
 * LibCrypto/Authentication/KMAC.cpp EVP ownership and operation sequence.
 */
#ifndef VOX_WEBCRYPTO_NATIVE_CRYPTO_H
#define VOX_WEBCRYPTO_NATIVE_CRYPTO_H
#include <openssl/core_names.h>
#include <openssl/evp.h>

static int vox_kmac(char const* name, unsigned char const* key, size_t key_size,
    unsigned char const* message, size_t message_size, unsigned char const* custom,
    size_t custom_size, unsigned char* output, size_t output_size)
{
    EVP_MAC* mac = EVP_MAC_fetch(NULL, name, NULL);
    if (!mac)
        return 0;
    EVP_MAC_CTX* ctx = EVP_MAC_CTX_new(mac);
    EVP_MAC_free(mac);
    if (!ctx)
        return 0;
    OSSL_PARAM params[] = {
        OSSL_PARAM_size_t(OSSL_MAC_PARAM_SIZE, &output_size),
        OSSL_PARAM_octet_string(OSSL_MAC_PARAM_CUSTOM, (void*)custom, custom_size),
        OSSL_PARAM_END,
    };
    size_t written = 0;
    int ok = EVP_MAC_init(ctx, key, key_size, params)
        && EVP_MAC_update(ctx, message, message_size)
        && EVP_MAC_final(ctx, output, &written, output_size)
        && written == output_size;
    EVP_MAC_CTX_free(ctx);
    return ok;
}
#endif
