/* Copyright (c) 2026, Ladybird contributors
 * SPDX-License-Identifier: BSD-2-Clause
 * LibCrypto/Authentication/KMAC.cpp EVP ownership and operation sequence.
 */
#ifndef VOX_WEBCRYPTO_NATIVE_CRYPTO_H
#define VOX_WEBCRYPTO_NATIVE_CRYPTO_H
#include <openssl/core_names.h>
#include <openssl/evp.h>
#include <string.h>

/* LibCrypto/Authentication/HMAC.cpp: reset, update, digest. */
#include "openssl_dispatch_darwin.h"

static int vox_hmac(char const* hash, unsigned char const* key, size_t key_size,
    unsigned char const* message, size_t message_size, unsigned char* output, size_t* output_size)
{
    if (!vox_crypto_prepare()) return 0;
    EVP_MAC* mac = EVP_MAC_fetch(NULL, "HMAC", NULL);
    if (!mac)
        return 0;
    EVP_MAC_CTX* ctx = EVP_MAC_CTX_new(mac);
    EVP_MAC_free(mac);
    if (!ctx)
        return 0;
    OSSL_PARAM params[] = {
        OSSL_PARAM_utf8_string(OSSL_MAC_PARAM_DIGEST, (char*)hash, strlen(hash)),
        OSSL_PARAM_END,
    };
    int ok = EVP_MAC_init(ctx, key, key_size, params)
        && EVP_MAC_update(ctx, message, message_size);
    if (ok) {
        size_t size = EVP_MAC_CTX_get_mac_size(ctx);
        ok = size <= *output_size && EVP_MAC_final(ctx, output, &size, size);
        if (ok)
            *output_size = size;
    }
    EVP_MAC_CTX_free(ctx);
    return ok;
}

static int vox_kmac(char const* name, unsigned char const* key, size_t key_size,
    unsigned char const* message, size_t message_size, unsigned char const* custom,
    size_t custom_size, unsigned char* output, size_t output_size)
{
    if (!vox_crypto_prepare()) return 0;
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
/* LibCrypto/Cipher/AES.cpp AESOCBCipher::{encrypt,decrypt}. */
/* LibCrypto/Cipher/AES.cpp AESOCBCipher exact operation diagnostics. */
static char const* vox_aes_ocb(int decrypt, unsigned char const* key, size_t key_size,
    unsigned char const* input, size_t input_size, unsigned char const* iv, size_t iv_size,
    unsigned char const* aad, size_t aad_size, size_t tag_size, unsigned char* output)
{
    if (!vox_crypto_prepare()) return "OpenSSL WebCrypto backend is unavailable";
    EVP_CIPHER const* cipher = key_size == 16 ? EVP_aes_128_ocb()
        : key_size == 24 ? EVP_aes_192_ocb() : key_size == 32 ? EVP_aes_256_ocb() : NULL;
    if (!cipher)
        return "No AES-OCB cipher for this key size";
    EVP_CIPHER_CTX* ctx = EVP_CIPHER_CTX_new();
    if (!ctx)
        return "EVP_CIPHER_CTX_new() failed";
    char const* failure = NULL;
    int out_len = 0, final_len = 0, aad_len = 0;
#define VOX_OCB_TRY(call, source) do { if ((call) != 1) { failure = source " failed"; goto done; } } while (0)
    if (decrypt) {
        size_t payload_size = input_size - tag_size;
        VOX_OCB_TRY(EVP_DecryptInit_ex(ctx, cipher, NULL, NULL, NULL), "EVP_DecryptInit_ex(ctx.ptr(), m_cipher, nullptr, nullptr, nullptr)");
        VOX_OCB_TRY(EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_IVLEN, (int)iv_size, NULL), "EVP_CIPHER_CTX_ctrl(ctx.ptr(), EVP_CTRL_AEAD_SET_IVLEN, iv.size(), nullptr)");
        VOX_OCB_TRY(EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_TAG, (int)tag_size, NULL), "EVP_CIPHER_CTX_ctrl(ctx.ptr(), EVP_CTRL_AEAD_SET_TAG, tag_length_bytes, nullptr)");
        VOX_OCB_TRY(EVP_DecryptInit_ex(ctx, NULL, NULL, key, iv), "EVP_DecryptInit_ex(ctx.ptr(), nullptr, nullptr, m_key.data(), iv.data())");
        if (aad_size)
            VOX_OCB_TRY(EVP_DecryptUpdate(ctx, NULL, &aad_len, aad, (int)aad_size), "EVP_DecryptUpdate(ctx.ptr(), nullptr, &aad_len, aad.data(), aad.size())");
        VOX_OCB_TRY(EVP_DecryptUpdate(ctx, output, &out_len, input, (int)payload_size), "EVP_DecryptUpdate(ctx.ptr(), plaintext.data(), &out_len, ciphertext.data(), ciphertext.size())");
        VOX_OCB_TRY(EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_TAG, (int)tag_size, (void*)(input + payload_size)), "EVP_CIPHER_CTX_ctrl(ctx.ptr(), EVP_CTRL_AEAD_SET_TAG, tag_length_bytes, mutable_tag)");
        VOX_OCB_TRY(EVP_DecryptFinal_ex(ctx, output + out_len, &final_len), "EVP_DecryptFinal_ex(ctx.ptr(), plaintext.data() + out_len, &final_len)");
    } else {
        VOX_OCB_TRY(EVP_EncryptInit_ex(ctx, cipher, NULL, NULL, NULL), "EVP_EncryptInit_ex(ctx.ptr(), m_cipher, nullptr, nullptr, nullptr)");
        VOX_OCB_TRY(EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_IVLEN, (int)iv_size, NULL), "EVP_CIPHER_CTX_ctrl(ctx.ptr(), EVP_CTRL_AEAD_SET_IVLEN, iv.size(), nullptr)");
        VOX_OCB_TRY(EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_SET_TAG, (int)tag_size, NULL), "EVP_CIPHER_CTX_ctrl(ctx.ptr(), EVP_CTRL_AEAD_SET_TAG, tag_length_bytes, nullptr)");
        VOX_OCB_TRY(EVP_EncryptInit_ex(ctx, NULL, NULL, key, iv), "EVP_EncryptInit_ex(ctx.ptr(), nullptr, nullptr, m_key.data(), iv.data())");
        if (aad_size)
            VOX_OCB_TRY(EVP_EncryptUpdate(ctx, NULL, &aad_len, aad, (int)aad_size), "EVP_EncryptUpdate(ctx.ptr(), nullptr, &aad_len, aad.data(), aad.size())");
        VOX_OCB_TRY(EVP_EncryptUpdate(ctx, output, &out_len, input, (int)input_size), "EVP_EncryptUpdate(ctx.ptr(), ciphertext.data(), &out_len, plaintext.data(), plaintext.size())");
        VOX_OCB_TRY(EVP_EncryptFinal_ex(ctx, output + out_len, &final_len), "EVP_EncryptFinal_ex(ctx.ptr(), ciphertext.data() + out_len, &final_len)");
        VOX_OCB_TRY(EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_AEAD_GET_TAG, (int)tag_size, output + input_size), "EVP_CIPHER_CTX_ctrl(ctx.ptr(), EVP_CTRL_AEAD_GET_TAG, tag_length_bytes, tag.data())");
    }
done:
#undef VOX_OCB_TRY
    EVP_CIPHER_CTX_free(ctx);
    return failure;
}

#endif
