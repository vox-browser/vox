/* SPDX-License-Identifier: BSD-2-Clause */
#ifndef VOX_NATIVE_RSA_H
#define VOX_NATIVE_RSA_H
#include <openssl/core_names.h>
#include <openssl/evp.h>
#include <openssl/param_build.h>
#include <openssl/bn.h>
#include <openssl/rsa.h>

typedef struct VoxRsaPart { unsigned char* bytes; size_t length; } VoxRsaPart;

/* LibCrypto/PK/RSA.cpp generate_key_pair and OpenSSL.cpp integer export. */
static int vox_rsa_generate(size_t bits, const unsigned char* exponent, size_t exponent_size, VoxRsaPart* output)
{
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
#endif
