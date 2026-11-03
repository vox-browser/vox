/* SPDX-License-Identifier: BSD-2-Clause
 * LibCrypto/Cipher/ChaCha.cpp operation-local EVP ownership and diagnostics. */
#ifndef VOX_WEBCRYPTO_NATIVE_CHACHA_H
#define VOX_WEBCRYPTO_NATIVE_CHACHA_H
#include <openssl/evp.h>

#include "openssl_dispatch_darwin.h"

static char const* vox_chacha20_poly1305(int decrypt, unsigned char const* key,
    size_t key_size, unsigned char const* nonce, size_t nonce_size,
    unsigned char const* input, size_t input_size, unsigned char const* aad,
    size_t aad_size, unsigned char* output, size_t* output_size)
{
    if (!vox_crypto_prepare()) return "OpenSSL WebCrypto backend is unavailable";
    if (key_size != 32)
        return "ChaCha20-Poly1305 key must be 32 bytes";
    if (nonce_size != 12)
        return "ChaCha20-Poly1305 nonce must be 12 bytes";
    if (decrypt && input_size < 16)
        return "Ciphertext too short";
    EVP_CIPHER_CTX* ctx = EVP_CIPHER_CTX_new();
    if (!ctx)
        return "EVP_CIPHER_CTX_new() failed";
    char const* failure = NULL;
    int out_len = 0, final_len = 0, aad_len = 0;
#define VOX_CHACHA_TRY(call, source) do { if ((call) != 1) { failure = source " failed"; goto done; } } while (0)
    if (decrypt) {
        size_t ciphertext_size = input_size - 16;
        unsigned char const* tag = input + ciphertext_size;
        VOX_CHACHA_TRY(EVP_DecryptInit_ex(ctx, EVP_chacha20_poly1305(), NULL, NULL, NULL), "EVP_DecryptInit_ex(ctx.ptr(), chacha20_poly1305_cipher(), nullptr, nullptr, nullptr)");
        VOX_CHACHA_TRY(EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_IVLEN, (int)nonce_size, NULL), "EVP_CIPHER_CTX_ctrl(ctx.ptr(), EVP_CTRL_AEAD_SET_IVLEN, nonce.size(), nullptr)");
        VOX_CHACHA_TRY(EVP_DecryptInit_ex(ctx, NULL, NULL, key, nonce), "EVP_DecryptInit_ex(ctx.ptr(), nullptr, nullptr, key.data(), nonce.data())");
        VOX_CHACHA_TRY(EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_TAG, 16, (void*)tag), "EVP_CIPHER_CTX_ctrl(ctx.ptr(), EVP_CTRL_AEAD_SET_TAG, tag.size(), const_cast<u8*>(tag.data()))");
        if (aad_size)
            VOX_CHACHA_TRY(EVP_DecryptUpdate(ctx, NULL, &aad_len, aad, (int)aad_size), "EVP_DecryptUpdate(ctx.ptr(), nullptr, &aad_len, aad.data(), aad.size())");
        VOX_CHACHA_TRY(EVP_DecryptUpdate(ctx, output, &out_len, input, (int)ciphertext_size), "EVP_DecryptUpdate(ctx.ptr(), plaintext.data(), &out_len, ciphertext.data(), ciphertext.size())");
        VOX_CHACHA_TRY(EVP_DecryptFinal_ex(ctx, output + out_len, &final_len), "EVP_DecryptFinal_ex(ctx.ptr(), plaintext.data() + out_len, &final_len)");
        *output_size = (size_t)(out_len + final_len);
    } else {
        VOX_CHACHA_TRY(EVP_EncryptInit_ex(ctx, EVP_chacha20_poly1305(), NULL, NULL, NULL), "EVP_EncryptInit_ex(ctx.ptr(), chacha20_poly1305_cipher(), nullptr, nullptr, nullptr)");
        VOX_CHACHA_TRY(EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_IVLEN, (int)nonce_size, NULL), "EVP_CIPHER_CTX_ctrl(ctx.ptr(), EVP_CTRL_AEAD_SET_IVLEN, nonce.size(), nullptr)");
        VOX_CHACHA_TRY(EVP_EncryptInit_ex(ctx, NULL, NULL, key, nonce), "EVP_EncryptInit_ex(ctx.ptr(), nullptr, nullptr, key.data(), nonce.data())");
        if (aad_size)
            VOX_CHACHA_TRY(EVP_EncryptUpdate(ctx, NULL, &aad_len, aad, (int)aad_size), "EVP_EncryptUpdate(ctx.ptr(), nullptr, &aad_len, aad.data(), aad.size())");
        VOX_CHACHA_TRY(EVP_EncryptUpdate(ctx, output, &out_len, input, (int)input_size), "EVP_EncryptUpdate(ctx.ptr(), ciphertext.data(), &out_len, plaintext.data(), plaintext.size())");
        VOX_CHACHA_TRY(EVP_EncryptFinal_ex(ctx, output + out_len, &final_len), "EVP_EncryptFinal_ex(ctx.ptr(), ciphertext.data() + out_len, &final_len)");
        VOX_CHACHA_TRY(EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_GET_TAG, 16, output + input_size), "EVP_CIPHER_CTX_ctrl(ctx.ptr(), EVP_CTRL_AEAD_GET_TAG, tag_size, tag.data())");
        *output_size = input_size + 16;
    }
done:
#undef VOX_CHACHA_TRY
    EVP_CIPHER_CTX_free(ctx);
    return failure;
}
#endif
