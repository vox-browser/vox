/* SPDX-License-Identifier: BSD-2-Clause
 * LibCrypto/Cipher/AES.cpp native operation-local EVP ownership. */
#ifndef VOX_WEBCRYPTO_NATIVE_AES_H
#define VOX_WEBCRYPTO_NATIVE_AES_H
#include <openssl/evp.h>

static int vox_aes_cbc(int decrypt, int no_padding, unsigned char const* key,
    size_t key_size, unsigned char const* input, size_t input_size,
    unsigned char const* iv, unsigned char* output, size_t* output_size)
{
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

#endif
