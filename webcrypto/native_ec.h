/* SPDX-License-Identifier: BSD-2-Clause */
#ifndef VOX_NATIVE_EC_H
#define VOX_NATIVE_EC_H
#include <string.h>
#include <openssl/core_names.h>
#include <openssl/evp.h>
#include <openssl/ec.h>
#include <openssl/bn.h>
#include <openssl/param_build.h>

/* LibCrypto/Curves/SECPxxxr1.cpp generate_private_key, scalar_to_bytes. */
#include "openssl_dispatch_darwin.h"

static int vox_ec_private(const char* curve, unsigned char* output, size_t size)
{
    if (!vox_crypto_prepare()) return 0;
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
    if (!vox_crypto_prepare()) return 0;
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
    if (!vox_crypto_prepare()) return -1;
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

/* SECPxxxr1Point::from_compressed selects its curve from the encoded size. */
static int vox_ec_decompress(const char* curve, const unsigned char* bytes, size_t length,
    unsigned char* x_out, unsigned char* y_out, size_t size)
{
    if (!vox_crypto_prepare()) return 0;
    int success = 0;
    EC_GROUP* group = EC_GROUP_new_by_curve_name(EC_curve_nist2nid(curve));
    EC_POINT* point = group ? EC_POINT_new(group) : NULL;
    BIGNUM* x = BN_new();
    BIGNUM* y = BN_new();
    if (!group || !point || !x || !y) goto cleanup;
    if (EC_POINT_oct2point(group, point, bytes, length, NULL) != 1
        || EC_POINT_get_affine_coordinates(group, point, x, y, NULL) != 1) goto cleanup;
    success = BN_bn2binpad(x, x_out, size) == (int)size && BN_bn2binpad(y, y_out, size) == (int)size;
cleanup:
    BN_free(y); BN_free(x); EC_POINT_free(point); EC_GROUP_free(group);
    return success;
}
/* sign/verify import the same group-name and scalar/point parameters upstream uses. */
static const char* vox_ec_import(const char* curve, const unsigned char* bytes, size_t size, int private_key, EVP_PKEY** key)
{
    if (!vox_crypto_prepare()) return "OpenSSL WebCrypto backend is unavailable";
    const char* failure = NULL;
    EVP_PKEY_CTX* ctx = EVP_PKEY_CTX_new_from_name(NULL, "EC", NULL);
    OSSL_PARAM_BLD* builder = NULL;
    OSSL_PARAM* params = NULL;
    BIGNUM* d = NULL;
    if (!ctx) { failure = "EVP_PKEY_CTX_new_from_name(nullptr, \"EC\", nullptr) failed"; goto cleanup; }
    if (EVP_PKEY_fromdata_init(ctx) != 1) { failure = "EVP_PKEY_fromdata_init(ctx_import.ptr()) failed"; goto cleanup; }
    builder = OSSL_PARAM_BLD_new();
    if (!builder) { failure = "OSSL_PARAM_BLD_new() failed"; goto cleanup; }
    if (OSSL_PARAM_BLD_push_utf8_string(builder, OSSL_PKEY_PARAM_GROUP_NAME, curve, strlen(curve)) != 1) {
        failure = "OSSL_PARAM_BLD_push_utf8_string(params_bld, OSSL_PKEY_PARAM_GROUP_NAME, m_curve_name, strlen(m_curve_name)) failed"; goto cleanup;
    }
    if (private_key) {
        d = BN_bin2bn(bytes, size, NULL);
        if (!d) { failure = "BN_bin2bn(bytes.data(), bytes.size(), nullptr) failed"; goto cleanup; }
        if (OSSL_PARAM_BLD_push_BN(builder, OSSL_PKEY_PARAM_PRIV_KEY, d) != 1) {
            failure = "OSSL_PARAM_BLD_push_BN(params_bld, OSSL_PKEY_PARAM_PRIV_KEY, d.ptr()) failed"; goto cleanup;
        }
    } else if (OSSL_PARAM_BLD_push_octet_string(builder, OSSL_PKEY_PARAM_PUB_KEY, bytes, size) != 1) {
        failure = "OSSL_PARAM_BLD_push_octet_string(params_bld, OSSL_PKEY_PARAM_PUB_KEY, pubkey_bytes.data(), pubkey_bytes.size()) failed"; goto cleanup;
    }
    params = OSSL_PARAM_BLD_to_param(builder);
    if (!params) { failure = "OSSL_PARAM_BLD_to_param(params_bld) failed"; goto cleanup; }
    if (EVP_PKEY_fromdata(ctx, key, private_key ? EVP_PKEY_KEYPAIR : EVP_PKEY_PUBLIC_KEY, params) != 1)
        failure = private_key ? "EVP_PKEY_fromdata(ctx_import.ptr(), &key_ptr, EVP_PKEY_KEYPAIR, params) failed"
            : "EVP_PKEY_fromdata(ctx_import.ptr(), &key_ptr, EVP_PKEY_PUBLIC_KEY, params) failed";
cleanup:
    BN_free(d); OSSL_PARAM_free(params); OSSL_PARAM_BLD_free(builder); EVP_PKEY_CTX_free(ctx);
    return failure;
}

static const char* vox_ec_sign(const char* curve, const unsigned char* d, size_t d_size,
    const unsigned char* hash, size_t hash_size, unsigned char* output, size_t scalar_size)
{
    if (!vox_crypto_prepare()) return "OpenSSL WebCrypto backend is unavailable";
    EVP_PKEY* key = NULL;
    const char* failure = vox_ec_import(curve, d, d_size, 1, &key);
    EVP_PKEY_CTX* ctx = NULL;
    unsigned char* encoded = NULL;
    ECDSA_SIG* signature = NULL;
    size_t size = 0;
    if (failure) goto cleanup;
    ctx = EVP_PKEY_CTX_new_from_pkey(NULL, key, NULL);
    if (!ctx) { failure = "EVP_PKEY_CTX_new_from_pkey(nullptr, key.ptr(), nullptr) failed"; goto cleanup; }
    if (EVP_PKEY_sign_init(ctx) != 1) { failure = "EVP_PKEY_sign_init(ctx.ptr()) failed"; goto cleanup; }
    if (EVP_PKEY_sign(ctx, NULL, &size, hash, hash_size) != 1) { failure = "EVP_PKEY_sign(ctx.ptr(), nullptr, &sig_len, hash.data(), hash.size()) failed"; goto cleanup; }
    encoded = OPENSSL_malloc(size);
    if (!encoded) { failure = "Failed to allocate signature"; goto cleanup; }
    if (EVP_PKEY_sign(ctx, encoded, &size, hash, hash_size) != 1) { failure = "EVP_PKEY_sign(ctx.ptr(), sig.data(), &sig_len, hash.data(), hash.size()) failed"; goto cleanup; }
    const unsigned char* cursor = encoded;
    signature = d2i_ECDSA_SIG(NULL, &cursor, size);
    if (!signature) { failure = "d2i_ECDSA_SIG(nullptr, &sig_data, sig.size()) failed"; goto cleanup; }
    if (BN_bn2binpad(ECDSA_SIG_get0_r(signature), output, scalar_size) != (int)scalar_size
        || BN_bn2binpad(ECDSA_SIG_get0_s(signature), output + scalar_size, scalar_size) != (int)scalar_size)
        failure = "Scalar is too large for the given size";
cleanup:
    ECDSA_SIG_free(signature); OPENSSL_free(encoded); EVP_PKEY_CTX_free(ctx); EVP_PKEY_free(key);
    return failure;
}

static const char* vox_ec_verify(const char* curve, const unsigned char* public_bytes, size_t public_size,
    const unsigned char* hash, size_t hash_size, const unsigned char* bytes, size_t half_size, int* result)
{
    if (!vox_crypto_prepare()) return "OpenSSL WebCrypto backend is unavailable";
    static const unsigned char zero = 0;
    if (!bytes) bytes = &zero;
    EVP_PKEY* key = NULL;
    const char* failure = vox_ec_import(curve, public_bytes, public_size, 0, &key);
    EVP_PKEY_CTX* ctx = NULL;
    ECDSA_SIG* signature = NULL;
    BIGNUM* r = NULL;
    BIGNUM* s = NULL;
    unsigned char* encoded = NULL;
    if (failure) goto cleanup;
    ctx = EVP_PKEY_CTX_new_from_pkey(NULL, key, NULL);
    if (!ctx) { failure = "EVP_PKEY_CTX_new_from_pkey(nullptr, key.ptr(), nullptr) failed"; goto cleanup; }
    if (EVP_PKEY_verify_init(ctx) != 1) { failure = "EVP_PKEY_verify_init(ctx.ptr()) failed"; goto cleanup; }
    signature = ECDSA_SIG_new();
    if (!signature) { failure = "ECDSA_SIG_new() failed"; goto cleanup; }
    r = BN_bin2bn(bytes, half_size, NULL);
    s = BN_bin2bn(bytes + half_size, half_size, NULL);
    if (!r || !s) { failure = "BN_bin2bn(bytes.data(), bytes.size(), nullptr) failed"; goto cleanup; }
    if (ECDSA_SIG_set0(signature, r, s) != 1) { failure = "ECDSA_SIG_set0(sig_obj, BN_dup(r.ptr()), BN_dup(s.ptr())) failed"; goto cleanup; }
    r = NULL; s = NULL;
    int size = i2d_ECDSA_SIG(signature, &encoded);
    if (size <= 0) { failure = "ret failed"; goto cleanup; }
    int verified = EVP_PKEY_verify(ctx, encoded, size, hash, hash_size);
    if (verified == 1 || verified == 0) *result = verified;
    else failure = "ret failed";
cleanup:
    OPENSSL_free(encoded); BN_free(s); BN_free(r); ECDSA_SIG_free(signature);
    EVP_PKEY_CTX_free(ctx); EVP_PKEY_free(key);
    return failure;
}

/* compute_coordinate: multiply the supplied public point by the private scalar. */
static const char* vox_ec_coordinate(const char* curve, const unsigned char* d_bytes, size_t d_size,
    const unsigned char* x_bytes, size_t x_size, const unsigned char* y_bytes, size_t y_size,
    unsigned char* x_out, unsigned char* y_out, size_t size)
{
    if (!vox_crypto_prepare()) return "OpenSSL WebCrypto backend is unavailable";
    const char* failure = NULL;
    EC_GROUP* group = EC_GROUP_new_by_curve_name(EC_curve_nist2nid(curve));
    EC_POINT* q = group ? EC_POINT_new(group) : NULL;
    EC_POINT* r = group ? EC_POINT_new(group) : NULL;
    BIGNUM* d = BN_bin2bn(d_bytes, d_size, NULL);
    BIGNUM* x = BN_bin2bn(x_bytes, x_size, NULL);
    BIGNUM* y = BN_bin2bn(y_bytes, y_size, NULL);
    if (!group || !q || !r || !d || !x || !y) { failure = "Failed to create EC coordinate"; goto cleanup; }
    if (EC_POINT_set_affine_coordinates(group, q, x, y, NULL) != 1) { failure = "EC_POINT_set_affine_coordinates(group, q, qx.ptr(), qy.ptr(), nullptr) failed"; goto cleanup; }
    if (EC_POINT_mul(group, r, NULL, q, d, NULL) != 1) { failure = "EC_POINT_mul(group, r, nullptr, q, scalar_int.ptr(), nullptr) failed"; goto cleanup; }
    if (EC_POINT_get_affine_coordinates(group, r, x, y, NULL) != 1) { failure = "EC_POINT_get_affine_coordinates(group, r, rx.ptr(), ry.ptr(), nullptr) failed"; goto cleanup; }
    if (BN_bn2binpad(x, x_out, size) != (int)size || BN_bn2binpad(y, y_out, size) != (int)size)
        failure = "Scalar is too large for the given size";
cleanup:
    BN_free(y); BN_free(x); BN_free(d); EC_POINT_free(r); EC_POINT_free(q); EC_GROUP_free(group);
    return failure;
}
#endif
