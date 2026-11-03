/* SPDX-License-Identifier: BSD-2-Clause */
#ifndef VOX_NATIVE_RSA_H
#define VOX_NATIVE_RSA_H
#include <string.h>
#include <openssl/core_names.h>
#include <openssl/evp.h>
#include <openssl/param_build.h>
#include <openssl/bn.h>
#include <openssl/rsa.h>

typedef struct VoxRsaPart { unsigned char* bytes; size_t length; } VoxRsaPart;

/* LibCrypto/PK/RSA.cpp generate_key_pair and OpenSSL.cpp integer export. */
#include "openssl_dispatch_darwin.h"

static int vox_rsa_generate(size_t bits, const unsigned char* exponent, size_t exponent_size, VoxRsaPart* output)
{
    if (!vox_crypto_prepare()) return 0;
    int success = 0;
    EVP_PKEY_CTX* ctx = EVP_PKEY_CTX_new_from_name(NULL, "RSA", NULL);
    EVP_PKEY* key = NULL;
    BIGNUM* e = BN_bin2bn(exponent, exponent_size, NULL);
    BIGNUM* value = NULL;
    OSSL_PARAM_BLD* builder = NULL;
    OSSL_PARAM* params = NULL;
    const char* names[7] = { OSSL_PKEY_PARAM_RSA_N, OSSL_PKEY_PARAM_RSA_D,
        OSSL_PKEY_PARAM_RSA_FACTOR1, OSSL_PKEY_PARAM_RSA_FACTOR2,
        OSSL_PKEY_PARAM_RSA_EXPONENT1, OSSL_PKEY_PARAM_RSA_EXPONENT2,
        OSSL_PKEY_PARAM_RSA_COEFFICIENT1 };
    if (!ctx || !e || EVP_PKEY_keygen_init(ctx) != 1) goto cleanup;
    builder = OSSL_PARAM_BLD_new();
    if (!builder || OSSL_PARAM_BLD_push_size_t(builder, OSSL_PKEY_PARAM_RSA_BITS, bits) != 1
        || OSSL_PARAM_BLD_push_BN(builder, OSSL_PKEY_PARAM_RSA_E, e) != 1) goto cleanup;
    params = OSSL_PARAM_BLD_to_param(builder);
    if (!params || EVP_PKEY_CTX_set_params(ctx, params) != 1 || EVP_PKEY_generate(ctx, &key) != 1) goto cleanup;
    for (int i = 0; i < 7; ++i) {
        if (EVP_PKEY_get_bn_param(key, names[i], &value) != 1) goto cleanup;
        size_t length = BN_num_bytes(value);
        if (length > output[i].length) goto cleanup;
        if (BN_bn2bin(value, output[i].bytes) != (int)length) goto cleanup;
        output[i].length = length;
        BN_free(value);
        value = NULL;
    }
    success = 1;
cleanup:
    BN_free(value);
    OSSL_PARAM_free(params);
    OSSL_PARAM_BLD_free(builder);
    BN_free(e);
    EVP_PKEY_free(key);
    EVP_PKEY_CTX_free(ctx);
    return success;
}

/* LibCrypto/PK/RSA.cpp *_key_to_openssl_pkey. */
static EVP_PKEY* vox_rsa_key(VoxRsaPart* values, int private_key)
{
    if (!vox_crypto_prepare()) return NULL;
    EVP_PKEY* key = NULL;
    EVP_PKEY_CTX* ctx = EVP_PKEY_CTX_new_from_name(NULL, "RSA", NULL);
    OSSL_PARAM_BLD* builder = NULL;
    OSSL_PARAM* params = NULL;
    BIGNUM* bns[8] = { NULL };
    const char* names[8] = { OSSL_PKEY_PARAM_RSA_N, OSSL_PKEY_PARAM_RSA_E, OSSL_PKEY_PARAM_RSA_D,
        OSSL_PKEY_PARAM_RSA_FACTOR1, OSSL_PKEY_PARAM_RSA_FACTOR2, OSSL_PKEY_PARAM_RSA_EXPONENT1,
        OSSL_PKEY_PARAM_RSA_EXPONENT2, OSSL_PKEY_PARAM_RSA_COEFFICIENT1 };
    if (!ctx || EVP_PKEY_fromdata_init(ctx) != 1) goto cleanup;
    builder = OSSL_PARAM_BLD_new();
    if (!builder) goto cleanup;
    for (int i = 0; i < (private_key ? 8 : 2); ++i) {
        bns[i] = BN_bin2bn(values[i].bytes, values[i].length, NULL);
        if (!bns[i]) goto cleanup;
        if (!BN_is_zero(bns[i]) && OSSL_PARAM_BLD_push_BN(builder, names[i], bns[i]) != 1) goto cleanup;
    }
    params = OSSL_PARAM_BLD_to_param(builder);
    if (!params || EVP_PKEY_fromdata(ctx, &key, private_key ? EVP_PKEY_KEYPAIR : EVP_PKEY_PUBLIC_KEY, params) != 1) {
        EVP_PKEY_free(key); key = NULL;
    }
cleanup:
    OSSL_PARAM_free(params);
    OSSL_PARAM_BLD_free(builder);
    for (int i = 0; i < 8; ++i) BN_free(bns[i]);
    EVP_PKEY_CTX_free(ctx);
    return key;
}

static const EVP_MD* vox_rsa_hash(const char* name)
{
    if (!vox_crypto_prepare()) return NULL;
    if (!strcmp(name, "SHA-1")) return EVP_sha1();
    if (!strcmp(name, "SHA-256")) return EVP_sha256();
    if (!strcmp(name, "SHA-384")) return EVP_sha384();
    if (!strcmp(name, "SHA-512")) return EVP_sha512();
    return NULL;
}

/* RSA_OAEP_EME::configure, RSA::encrypt/decrypt. */
static int vox_rsa_oaep(VoxRsaPart* values, int decrypt, const char* hash_name,
    const unsigned char* label, size_t label_size, const unsigned char* input, size_t input_size,
    unsigned char* output, size_t* output_size)
{
    if (!vox_crypto_prepare()) return 0;
    int success = 0;
    EVP_PKEY* key = vox_rsa_key(values, decrypt);
    EVP_PKEY_CTX* ctx = key ? EVP_PKEY_CTX_new_from_pkey(NULL, key, NULL) : NULL;
    const EVP_MD* hash = vox_rsa_hash(hash_name);
    void* owned_label = NULL;
    size_t capacity = *output_size;
    if (!ctx || !hash) goto cleanup;
    if ((decrypt ? EVP_PKEY_decrypt_init(ctx) : EVP_PKEY_encrypt_init(ctx)) != 1) goto cleanup;
    if (EVP_PKEY_CTX_set_rsa_padding(ctx, RSA_PKCS1_OAEP_PADDING) != 1
        || EVP_PKEY_CTX_set_rsa_oaep_md(ctx, hash) != 1 || EVP_PKEY_CTX_set_rsa_mgf1_md(ctx, hash) != 1) goto cleanup;
    if (label_size) {
        owned_label = OPENSSL_malloc(label_size);
        if (!owned_label) goto cleanup;
        memcpy(owned_label, label, label_size);
        if (EVP_PKEY_CTX_set0_rsa_oaep_label(ctx, owned_label, label_size) != 1) goto cleanup;
        owned_label = NULL; /* Context owns the source's copied label. */
    }
    if ((decrypt ? EVP_PKEY_decrypt(ctx, NULL, output_size, input, input_size) : EVP_PKEY_encrypt(ctx, NULL, output_size, input, input_size)) != 1) goto cleanup;
    if (*output_size > capacity) goto cleanup;
    success = (decrypt ? EVP_PKEY_decrypt(ctx, output, output_size, input, input_size) : EVP_PKEY_encrypt(ctx, output, output_size, input, input_size)) == 1;
cleanup:
    OPENSSL_free(owned_label);
    EVP_PKEY_CTX_free(ctx);
    EVP_PKEY_free(key);
    return success;
}

static int vox_rsa_emsa_configure(EVP_PKEY_CTX* ctx, const EVP_MD* hash, int pss, unsigned int salt_size)
{
    if (!vox_crypto_prepare()) return 0;
    if (EVP_PKEY_CTX_set_rsa_padding(ctx, pss ? RSA_PKCS1_PSS_PADDING : RSA_PKCS1_PADDING) != 1) return 0;
    if (pss && (EVP_PKEY_CTX_set_rsa_mgf1_md(ctx, hash) != 1 || EVP_PKEY_CTX_set_rsa_pss_saltlen(ctx, (int)salt_size) != 1)) return 0;
    return 1;
}

/* RSA_EMSA::sign/verify and RSA_PSS_EMSA/RSA_PKCS1_EMSA::configure. */
static int vox_rsa_sign(VoxRsaPart* values, const char* hash_name, int pss, unsigned int salt_size,
    const unsigned char* message, size_t message_size, unsigned char* signature, size_t* signature_size)
{
    if (!vox_crypto_prepare()) return 0;
    int success = 0;
    EVP_PKEY* key = vox_rsa_key(values, 1);
    EVP_MD_CTX* ctx = EVP_MD_CTX_new();
    EVP_PKEY_CTX* key_ctx = key ? EVP_PKEY_CTX_new(key, NULL) : NULL;
    const EVP_MD* hash = vox_rsa_hash(hash_name);
    size_t capacity = *signature_size;
    if (!ctx || !key_ctx || !hash) goto cleanup;
    EVP_MD_CTX_set_pkey_ctx(ctx, key_ctx);
    if (EVP_DigestSignInit(ctx, NULL, hash, NULL, key) != 1) goto cleanup;
    if (!vox_rsa_emsa_configure(key_ctx, hash, pss, salt_size)) goto cleanup;
    if (EVP_DigestSign(ctx, NULL, signature_size, message, message_size) != 1) goto cleanup;
    if (*signature_size > capacity) goto cleanup;
    success = EVP_DigestSign(ctx, signature, signature_size, message, message_size) == 1;
cleanup:
    EVP_MD_CTX_free(ctx);
    EVP_PKEY_CTX_free(key_ctx);
    EVP_PKEY_free(key);
    return success;
}

static int vox_rsa_verify(VoxRsaPart* values, const char* hash_name, int pss, unsigned int salt_size,
    const unsigned char* signature, size_t signature_size, const unsigned char* message, size_t message_size)
{
    if (!vox_crypto_prepare()) return 0;
    int result = -1;
    EVP_PKEY* key = vox_rsa_key(values, 0);
    EVP_MD_CTX* ctx = EVP_MD_CTX_new();
    EVP_PKEY_CTX* key_ctx = key ? EVP_PKEY_CTX_new(key, NULL) : NULL;
    const EVP_MD* hash = vox_rsa_hash(hash_name);
    if (!ctx || !key_ctx || !hash) goto cleanup;
    EVP_MD_CTX_set_pkey_ctx(ctx, key_ctx);
    if (EVP_DigestVerifyInit(ctx, NULL, hash, NULL, key) != 1) goto cleanup;
    if (!vox_rsa_emsa_configure(key_ctx, hash, pss, salt_size)) goto cleanup;
    result = EVP_DigestVerify(ctx, signature, signature_size, message, message_size);
cleanup:
    EVP_MD_CTX_free(ctx);
    EVP_PKEY_CTX_free(key_ctx);
    EVP_PKEY_free(key);
    return result;
}

/* Direct translation of RSAPublicKey/RSAPrivateKey::is_valid. */
static int vox_rsa_valid(VoxRsaPart* values, int private_key)
{
    if (!vox_crypto_prepare()) return 0;
    int result = -1;
    BIGNUM* bns[8] = { NULL };
    BIGNUM* three = BN_new();
    BIGNUM* temp = BN_new();
    BIGNUM* p1 = BN_new();
    BIGNUM* q1 = BN_new();
    BIGNUM* divisor = BN_new();
    BIGNUM* lambda = BN_new();
    BN_CTX* ctx = BN_CTX_new();
    if (!three || !temp || !p1 || !q1 || !divisor || !lambda || !ctx || BN_set_word(three, 3) != 1) goto cleanup;
    for (int i = 0; i < (private_key ? 8 : 2); ++i) {
        bns[i] = BN_bin2bn(values[i].bytes, values[i].length, NULL);
        if (!bns[i]) goto cleanup;
    }
    result = 0;
    if (!BN_is_odd(bns[1]) || BN_cmp(bns[1], three) < 0 || BN_cmp(bns[1], bns[0]) >= 0) goto cleanup;
    if (!private_key) { result = 1; goto cleanup; }
    if (!BN_is_zero(bns[3]) && !BN_is_zero(bns[4]) && !BN_is_zero(bns[5]) && !BN_is_zero(bns[6]) && !BN_is_zero(bns[7])) {
        if (BN_cmp(bns[5], bns[3]) >= 0 || BN_cmp(bns[6], bns[4]) >= 0 || BN_cmp(bns[7], bns[3]) >= 0) goto cleanup;
        result = -1;
        if (!BN_mul(temp, bns[3], bns[4], ctx)) goto cleanup;
        result = 0;
        if (BN_cmp(temp, bns[0]) != 0) goto cleanup;
        result = -1;
        if (!BN_sub(p1, bns[3], BN_value_one()) || !BN_sub(q1, bns[4], BN_value_one())) goto cleanup;
        if (!BN_mod_mul(temp, bns[1], bns[5], p1, ctx)) goto cleanup;
        result = 0;
        if (!BN_is_one(temp)) goto cleanup;
        result = -1;
        if (!BN_mod_mul(temp, bns[1], bns[6], q1, ctx)) goto cleanup;
        result = 0;
        if (!BN_is_one(temp)) goto cleanup;
        result = -1;
        if (!BN_mod_mul(temp, bns[4], bns[7], bns[3], ctx)) goto cleanup;
        result = 0;
        if (!BN_is_one(temp)) goto cleanup;
        if (!BN_is_zero(bns[2])) {
            if (BN_cmp(bns[2], bns[0]) >= 0) goto cleanup;
            result = -1;
            if (!BN_gcd(divisor, p1, q1, ctx) || !BN_mul(temp, p1, q1, ctx) || !BN_div(lambda, NULL, temp, divisor, ctx)
                || !BN_mod_mul(temp, bns[2], bns[1], lambda, ctx)) goto cleanup;
            result = 0;
            if (!BN_is_one(temp)) goto cleanup;
        }
        result = 1;
        goto cleanup;
    }
    if (!BN_is_zero(bns[0]) && !BN_is_zero(bns[2]) && BN_cmp(bns[2], bns[0]) < 0) result = 1;
cleanup:
    for (int i = 0; i < 8; ++i) BN_free(bns[i]);
    BN_free(three); BN_free(temp); BN_free(p1); BN_free(q1); BN_free(divisor); BN_free(lambda); BN_CTX_free(ctx);
    return result;
}
#endif
