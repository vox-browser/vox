/* SPDX-License-Identifier: BSD-2-Clause */
#ifndef VOX_NATIVE_EDWARDS_H
#define VOX_NATIVE_EDWARDS_H
#include <openssl/evp.h>

/* Translation of LibCrypto/Curves/EdwardsCurve.cpp. Keys remain raw bytes;
 * every temporary EVP object has the same operation-local ownership as source. */
static int vox_edwards_private(const char* name, unsigned char* out, size_t* size)
{
    EVP_PKEY* key = EVP_PKEY_Q_keygen(NULL, NULL, name);
    if (!key) return 0;
    int result = EVP_PKEY_get_raw_private_key(key, out, size);
    EVP_PKEY_free(key);
    return result;
}

static int vox_edwards_public(const char* name, const unsigned char* private_bytes,
    size_t private_size, unsigned char* out, size_t* size)
{
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
#endif
