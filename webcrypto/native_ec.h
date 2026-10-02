/* SPDX-License-Identifier: BSD-2-Clause */
#ifndef VOX_NATIVE_EC_H
#define VOX_NATIVE_EC_H
#include <string.h>
#include <openssl/core_names.h>
#include <openssl/evp.h>
#include <openssl/ec.h>
#include <openssl/bn.h>

/* LibCrypto/Curves/SECPxxxr1.cpp generate_private_key, scalar_to_bytes. */
static int vox_ec_private(const char* curve, unsigned char* output, size_t size)
{
    EVP_PKEY* key = EVP_PKEY_Q_keygen(NULL, NULL, "EC", curve);
    BIGNUM* scalar = NULL;
    int success = key && EVP_PKEY_get_bn_param(key, OSSL_PKEY_PARAM_PRIV_KEY, &scalar) == 1
        && BN_bn2binpad(scalar, output, size) == (int)size;
    BN_free(scalar);
    EVP_PKEY_free(key);
    return success;
}

/* generate_public_key: multiply the curve generator by the private scalar. */
static int vox_ec_public(const char* curve, const unsigned char* scalar, size_t scalar_size,
    unsigned char* x_out, unsigned char* y_out, size_t size)
{
    int success = 0;
    EC_GROUP* group = EC_GROUP_new_by_curve_name(EC_curve_nist2nid(curve));
    EC_POINT* point = group ? EC_POINT_new(group) : NULL;
    BIGNUM* d = BN_bin2bn(scalar, scalar_size, NULL);
    BIGNUM* x = BN_new();
    BIGNUM* y = BN_new();
    if (!group || !point || !d || !x || !y) goto cleanup;
    if (EC_POINT_mul(group, point, d, NULL, NULL, NULL) != 1
        || EC_POINT_get_affine_coordinates(group, point, x, y, NULL) != 1) goto cleanup;
    success = BN_bn2binpad(x, x_out, size) == (int)size && BN_bn2binpad(y, y_out, size) == (int)size;
cleanup:
    BN_free(y); BN_free(x); BN_free(d);
    EC_POINT_free(point); EC_GROUP_free(group);
    return success;
}

/* is_valid_point: set_affine checks curve membership, then compare d*G. */
static int vox_ec_valid(const char* curve, const unsigned char* x_bytes, size_t x_size,
    const unsigned char* y_bytes, size_t y_size, const unsigned char* d_bytes, size_t d_size, int private_key)
{
    int result = -1;
    EC_GROUP* group = EC_GROUP_new_by_curve_name(EC_curve_nist2nid(curve));
    EC_POINT* point = group ? EC_POINT_new(group) : NULL;
    EC_POINT* expected = NULL;
    BIGNUM* x = BN_bin2bn(x_bytes, x_size, NULL);
    BIGNUM* y = BN_bin2bn(y_bytes, y_size, NULL);
    BIGNUM* d = NULL;
    if (!group || !point || !x || !y) goto cleanup;
    if (EC_POINT_set_affine_coordinates(group, point, x, y, NULL) != 1) { result = 0; goto cleanup; }
    if (!private_key) { result = 1; goto cleanup; }
    d = BN_bin2bn(d_bytes, d_size, NULL);
    expected = EC_POINT_new(group);
    if (!d || !expected || EC_POINT_mul(group, expected, d, NULL, NULL, NULL) != 1) goto cleanup;
    result = EC_POINT_cmp(group, expected, point, NULL) == 0;
cleanup:
    BN_free(d); BN_free(y); BN_free(x);
    EC_POINT_free(expected); EC_POINT_free(point); EC_GROUP_free(group);
    return result;
}
#endif
