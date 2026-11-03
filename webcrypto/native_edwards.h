/* SPDX-License-Identifier: BSD-2-Clause */
#ifndef VOX_NATIVE_EDWARDS_H
#define VOX_NATIVE_EDWARDS_H
#include <openssl/evp.h>
#include <openssl/core_names.h>

/* Translation of LibCrypto/Curves/EdwardsCurve.cpp. Keys remain raw bytes;
 * every temporary EVP object has the same operation-local ownership as source. */
#include "openssl_dispatch_darwin.h"

static int vox_edwards_private(const char* name, unsigned char* out, size_t* size)
{
    if (!vox_crypto_prepare()) return 0;
    EVP_PKEY* key = EVP_PKEY_Q_keygen(NULL, NULL, name);
    if (!key) return 0;
    int result = EVP_PKEY_get_raw_private_key(key, out, size);
    EVP_PKEY_free(key);
    return result;
}

static int vox_edwards_public(const char* name, const unsigned char* private_bytes,
    size_t private_size, unsigned char* out, size_t* size)
{
    if (!vox_crypto_prepare()) return 0;
    EVP_PKEY* key = EVP_PKEY_new_raw_private_key_ex(NULL, name, NULL, private_bytes, private_size);
    if (!key) return 0;
    int result = EVP_PKEY_get_raw_public_key(key, out, size);
    EVP_PKEY_free(key);
    return result;
}

static int vox_edwards_coordinate(const char* name, const unsigned char* private_bytes,
    size_t private_size, const unsigned char* public_bytes, size_t public_size,
    unsigned char* out, size_t* size)
{
    if (!vox_crypto_prepare()) return 0;
    EVP_PKEY* key = EVP_PKEY_new_raw_private_key_ex(NULL, name, NULL, private_bytes, private_size);
    EVP_PKEY* peer = EVP_PKEY_new_raw_public_key_ex(NULL, name, NULL, public_bytes, public_size);
    EVP_PKEY_CTX* context = key ? EVP_PKEY_CTX_new(key, NULL) : NULL;
    int result = context && peer && EVP_PKEY_derive_init(context) == 1
        && EVP_PKEY_derive_set_peer(context, peer) == 1
        && EVP_PKEY_derive(context, NULL, size) == 1
        && EVP_PKEY_derive(context, out, size) == 1;
    EVP_PKEY_CTX_free(context);
    EVP_PKEY_free(peer);
    EVP_PKEY_free(key);
    return result;
}
static int vox_edwards_sign(const char* name, const unsigned char* private_bytes,
    size_t private_size, const unsigned char* message, size_t message_size,
    unsigned char* context, size_t context_size, unsigned char* signature, size_t* size)
{
    if (!vox_crypto_prepare()) return 0;
#ifndef OSSL_SIGNATURE_PARAM_CONTEXT_STRING
    if (context_size) return 0;
#endif
    EVP_PKEY* key = EVP_PKEY_new_raw_private_key_ex(NULL, name, NULL, private_bytes, private_size);
    EVP_MD_CTX* ctx = EVP_MD_CTX_new();
    OSSL_PARAM params[2] = { OSSL_PARAM_END, OSSL_PARAM_END };
#ifdef OSSL_SIGNATURE_PARAM_CONTEXT_STRING
    if (context_size) params[0] = (OSSL_PARAM)OSSL_PARAM_octet_string(OSSL_SIGNATURE_PARAM_CONTEXT_STRING, context, context_size);
#endif
    int result = key && ctx
        && EVP_DigestSignInit_ex(ctx, NULL, NULL, NULL, NULL, key, params) == 1
        && EVP_DigestSign(ctx, NULL, size, message, message_size) == 1
        && EVP_DigestSign(ctx, signature, size, message, message_size) == 1;
    EVP_MD_CTX_free(ctx);
    EVP_PKEY_free(key);
    return result;
}

static int vox_edwards_verify(const char* name, const unsigned char* public_bytes,
    size_t public_size, const unsigned char* signature, size_t signature_size,
    const unsigned char* message, size_t message_size, unsigned char* context, size_t context_size)
{
    if (!vox_crypto_prepare()) return 0;
#ifndef OSSL_SIGNATURE_PARAM_CONTEXT_STRING
    if (context_size) return -3;
#endif
    EVP_PKEY* key = EVP_PKEY_new_raw_public_key_ex(NULL, name, NULL, public_bytes, public_size);
    if (!key) return -1;
    EVP_MD_CTX* ctx = EVP_MD_CTX_new();
    if (!ctx) { EVP_PKEY_free(key); return -2; }
    OSSL_PARAM params[2] = { OSSL_PARAM_END, OSSL_PARAM_END };
#ifdef OSSL_SIGNATURE_PARAM_CONTEXT_STRING
    if (context_size) params[0] = (OSSL_PARAM)OSSL_PARAM_octet_string(OSSL_SIGNATURE_PARAM_CONTEXT_STRING, context, context_size);
#endif
    int result;
    if (EVP_DigestVerifyInit_ex(ctx, NULL, NULL, NULL, NULL, key, params) != 1) result = -3;
    else {
        result = EVP_DigestVerify(ctx, signature, signature_size, message, message_size);
        if (result != 0 && result != 1) result = -4;
    }
    EVP_MD_CTX_free(ctx);
    EVP_PKEY_free(key);
    return result;
}
#endif
