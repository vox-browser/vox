/* SPDX-License-Identifier: BSD-2-Clause
 * LibCrypto/Cipher/AES.cpp native operation-local EVP ownership. */
#ifndef VOX_WEBCRYPTO_NATIVE_AES_H
#define VOX_WEBCRYPTO_NATIVE_AES_H
#include <openssl/evp.h>

#include "openssl_dispatch_darwin.h"

static int vox_aes_cbc(int decrypt, int no_padding, unsigned char const* key,
    size_t key_size, unsigned char const* input, size_t input_size,
    unsigned char const* iv, unsigned char* output, size_t* output_size)
{
    if (!vox_crypto_prepare()) return 0;
    EVP_CIPHER const* cipher = key_size == 16 ? EVP_aes_128_cbc()
        : key_size == 24 ? EVP_aes_192_cbc() : key_size == 32 ? EVP_aes_256_cbc() : NULL;
    if (!cipher)
        return 0;
    EVP_CIPHER_CTX* ctx = EVP_CIPHER_CTX_new();
    if (!ctx)
        return 0;
    int out_size = 0, final_size = 0;
    int ok;
    if (decrypt) {
        ok = EVP_DecryptInit(ctx, cipher, key, iv)
            && EVP_CIPHER_CTX_set_padding(ctx, no_padding ? 0 : 1)
            && EVP_DecryptUpdate(ctx, output, &out_size, input, (int)input_size)
            && EVP_DecryptFinal(ctx, output + out_size, &final_size);
    } else {
        ok = EVP_EncryptInit(ctx, cipher, key, iv)
            && EVP_CIPHER_CTX_set_padding(ctx, no_padding ? 0 : 1)
            && EVP_EncryptUpdate(ctx, output, &out_size, input, (int)input_size)
            && EVP_EncryptFinal(ctx, output + out_size, &final_size);
    }
    if (ok)
        *output_size = (size_t)(out_size + final_size);
    EVP_CIPHER_CTX_free(ctx);
    return ok;
}
/* LibCrypto/Cipher/AES.cpp AESCTRCipher::{encrypt,decrypt}. */
static int vox_aes_ctr(int decrypt, unsigned char const* key, size_t key_size,
    unsigned char const* input, size_t input_size, unsigned char const* iv,
    unsigned char* output, size_t* output_size)
{
    if (!vox_crypto_prepare()) return 0;
    EVP_CIPHER const* cipher = key_size == 16 ? EVP_aes_128_ctr()
        : key_size == 24 ? EVP_aes_192_ctr() : key_size == 32 ? EVP_aes_256_ctr() : NULL;
    if (!cipher)
        return 0;
    EVP_CIPHER_CTX* ctx = EVP_CIPHER_CTX_new();
    if (!ctx)
        return 0;
    int out_size = 0, final_size = 0;
    int ok;
    if (decrypt) {
        ok = EVP_DecryptInit(ctx, cipher, key, iv)
            && EVP_DecryptUpdate(ctx, output, &out_size, input, (int)input_size)
            && EVP_DecryptFinal(ctx, output + out_size, &final_size);
    } else {
        ok = EVP_EncryptInit(ctx, cipher, key, iv)
            && EVP_EncryptUpdate(ctx, output, &out_size, input, (int)input_size)
            && EVP_EncryptFinal(ctx, output + out_size, &final_size);
    }
    if (ok)
        *output_size = (size_t)(out_size + final_size);
    EVP_CIPHER_CTX_free(ctx);
    return ok;
}

/* LibCrypto/Cipher/AES.cpp AESGCMCipher::{encrypt,decrypt}. */
static int vox_aes_gcm(int decrypt, unsigned char const* key, size_t key_size,
    unsigned char const* input, size_t input_size, unsigned char const* iv, size_t iv_size,
    unsigned char const* aad, size_t aad_size, unsigned char const* tag, size_t tag_size,
    unsigned char* output, size_t* output_size)
{
    if (!vox_crypto_prepare()) return 0;
    EVP_CIPHER const* cipher = key_size == 16 ? EVP_aes_128_gcm()
        : key_size == 24 ? EVP_aes_192_gcm() : key_size == 32 ? EVP_aes_256_gcm() : NULL;
    if (!cipher)
        return 0;
    EVP_CIPHER_CTX* ctx = EVP_CIPHER_CTX_new();
    if (!ctx)
        return 0;
    int out_size = 0, final_size = 0, aad_written = 0;
    int ok;
    if (decrypt) {
        ok = EVP_DecryptInit(ctx, cipher, NULL, NULL)
            && EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, (int)iv_size, NULL)
            && EVP_DecryptInit(ctx, NULL, key, iv)
            && EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, (int)tag_size, (void*)tag);
        if (ok && aad_size)
            ok = EVP_DecryptUpdate(ctx, NULL, &aad_written, aad, (int)aad_size);
        if (ok)
            ok = EVP_DecryptUpdate(ctx, output, &out_size, input, (int)input_size)
                && EVP_DecryptFinal(ctx, output + out_size, &final_size);
    } else {
        ok = EVP_EncryptInit(ctx, cipher, NULL, NULL)
            && EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, (int)iv_size, NULL)
            && EVP_EncryptInit(ctx, NULL, key, iv);
        if (ok && aad_size)
            ok = EVP_EncryptUpdate(ctx, NULL, &aad_written, aad, (int)aad_size);
        if (ok)
            ok = EVP_EncryptUpdate(ctx, output, &out_size, input, (int)input_size)
                && EVP_EncryptFinal(ctx, output + out_size, &final_size)
                && EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, (int)tag_size, output + out_size + final_size);
    }
    if (ok)
        *output_size = (size_t)(out_size + final_size) + (decrypt ? 0 : tag_size);
    EVP_CIPHER_CTX_free(ctx);
    return ok;
}

/* LibCrypto/Cipher/AES.cpp AESKWCipher::{wrap,unwrap}. */
static int vox_aes_kw(int decrypt, unsigned char const* key, size_t key_size,
    unsigned char const* input, size_t input_size, unsigned char* output, size_t* output_size)
{
    if (!vox_crypto_prepare()) return 0;
    EVP_CIPHER const* cipher = key_size == 16 ? EVP_aes_128_wrap()
        : key_size == 24 ? EVP_aes_192_wrap() : key_size == 32 ? EVP_aes_256_wrap() : NULL;
    if (!cipher)
        return 0;
    EVP_CIPHER_CTX* ctx = EVP_CIPHER_CTX_new();
    if (!ctx)
        return 0;
    int out_size = 0, final_size = 0;
    int ok;
    if (decrypt) {
        ok = EVP_DecryptInit(ctx, cipher, key, NULL)
            && EVP_DecryptUpdate(ctx, output, &out_size, input, (int)input_size)
            && EVP_DecryptFinal(ctx, output + out_size, &final_size);
    } else {
        ok = EVP_EncryptInit(ctx, cipher, key, NULL)
            && EVP_EncryptUpdate(ctx, output, &out_size, input, (int)input_size)
            && EVP_EncryptFinal(ctx, output + out_size, &final_size);
    }
    if (ok)
        *output_size = (size_t)(out_size + final_size);
    EVP_CIPHER_CTX_free(ctx);
    return ok;
}

#endif
