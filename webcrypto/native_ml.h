/* SPDX-License-Identifier: BSD-2-Clause */
#ifndef VOX_NATIVE_ML_H
#define VOX_NATIVE_ML_H
#include <openssl/core_names.h>
#include <openssl/evp.h>
#include <openssl/param_build.h>
#include "openssl_dispatch_darwin.h"

/* Source: LibCrypto/PK/MLKEM.cpp, MLDSA.cpp and OpenSSL.cpp. */
#if OPENSSL_VERSION_NUMBER >= 0x30500000L
static const char* vox_ml_read_param(EVP_PKEY* key, const char* name, unsigned char* out, size_t* capacity)
{
    if (!vox_crypto_prepare()) return "OpenSSL WebCrypto backend is unavailable";
    size_t size = 0;
    if (EVP_PKEY_get_octet_string_param(key, name, NULL, 0, &size) != 1)
        return "EVP_PKEY_get_octet_string_param(key.ptr(), key_name, nullptr, 0, &key_size) failed";
    if (size > *capacity) return "Native key parameter exceeds its output capacity";
    if (EVP_PKEY_get_octet_string_param(key, name, out, *capacity, &size) != 1)
        return "EVP_PKEY_get_octet_string_param(key.ptr(), key_name, buf.data(), key_size, &key_size) failed";
    *capacity = size;
    return NULL;
}

static const char* vox_ml_generate(const char* name, const char* seed_name,
    unsigned char* seed, size_t seed_size, unsigned char* public_bytes, size_t* public_size,
    unsigned char* private_bytes, size_t* private_size, unsigned char* seed_out, size_t* seed_out_size)
{
    if (!vox_crypto_prepare()) return "OpenSSL WebCrypto backend is unavailable";
    const char* error = NULL;
    EVP_PKEY_CTX* ctx = EVP_PKEY_CTX_new_from_name(NULL, name, NULL);
    EVP_PKEY* key = NULL;
    OSSL_PARAM params[2] = { OSSL_PARAM_END, OSSL_PARAM_END };
    if (!ctx) { error = "ptr failed"; goto cleanup; }
    if (EVP_PKEY_keygen_init(ctx) != 1) { error = "EVP_PKEY_keygen_init(ctx.ptr()) failed"; goto cleanup; }
    if (seed_size) params[0] = (OSSL_PARAM)OSSL_PARAM_octet_string(seed_name, seed, seed_size);
    if (EVP_PKEY_CTX_set_params(ctx, params) != 1) { error = "EVP_PKEY_CTX_set_params(ctx.ptr(), params) failed"; goto cleanup; }
    if (EVP_PKEY_generate(ctx, &key) != 1) { error = "EVP_PKEY_generate(ctx.ptr(), &key_ptr) failed"; goto cleanup; }
    error = vox_ml_read_param(key, OSSL_PKEY_PARAM_PUB_KEY, public_bytes, public_size);
    if (!error) error = vox_ml_read_param(key, OSSL_PKEY_PARAM_PRIV_KEY, private_bytes, private_size);
    if (!error) error = vox_ml_read_param(key, seed_name, seed_out, seed_out_size);
cleanup:
    EVP_PKEY_free(key);
    EVP_PKEY_CTX_free(ctx);
    return error;
}

static const char* vox_mlkem_encapsulate(const char* name, const unsigned char* public_bytes,
    size_t public_size, unsigned char* ciphertext, size_t* ciphertext_size,
    unsigned char* shared, size_t* shared_size)
{
    if (!vox_crypto_prepare()) return "OpenSSL WebCrypto backend is unavailable";
    const char* error = NULL;
    EVP_PKEY* key = EVP_PKEY_new_raw_public_key_ex(NULL, name, NULL, public_bytes, public_size);
    EVP_PKEY_CTX* ctx = key ? EVP_PKEY_CTX_new_from_pkey(NULL, key, NULL) : NULL;
    size_t cipher_capacity = *ciphertext_size, shared_capacity = *shared_size;
    if (!key || !ctx) { error = "ptr failed"; goto cleanup; }
    if (EVP_PKEY_encapsulate_init(ctx, NULL) != 1) { error = "EVP_PKEY_encapsulate_init(ctx.ptr(), nullptr) failed"; goto cleanup; }
    if (EVP_PKEY_encapsulate(ctx, NULL, ciphertext_size, NULL, shared_size) != 1) {
        error = "EVP_PKEY_encapsulate(ctx.ptr(), nullptr, &ciphertext_length, nullptr, &shared_key_size) failed"; goto cleanup;
    }
    if (*ciphertext_size > cipher_capacity || *shared_size > shared_capacity) { error = "Native encapsulation exceeds its output capacity"; goto cleanup; }
    if (EVP_PKEY_encapsulate(ctx, ciphertext, ciphertext_size, shared, shared_size) != 1)
        error = "EVP_PKEY_encapsulate(ctx.ptr(), ciphertext.data(), &ciphertext_length, shared_key.data(), &shared_key_size) failed";
cleanup:
    EVP_PKEY_CTX_free(ctx);
    EVP_PKEY_free(key);
    return error;
}

static const char* vox_mlkem_decapsulate(const char* name, const unsigned char* seed, size_t seed_size,
    const unsigned char* public_bytes, size_t public_size, const unsigned char* private_bytes, size_t private_size,
    const unsigned char* ciphertext, size_t ciphertext_size, unsigned char* shared, size_t* shared_size)
{
    if (!vox_crypto_prepare()) return "OpenSSL WebCrypto backend is unavailable";
    const char* error = NULL;
    EVP_PKEY_CTX* from = EVP_PKEY_CTX_new_from_name(NULL, name, NULL);
    EVP_PKEY_CTX* ctx = NULL;
    EVP_PKEY* key = NULL;
    OSSL_PARAM_BLD* builder = NULL;
    OSSL_PARAM* params = NULL;
    size_t capacity = *shared_size;
    if (!from) { error = "ptr failed"; goto cleanup; }
    if (EVP_PKEY_fromdata_init(from) != 1) { error = "EVP_PKEY_fromdata_init(ctx.ptr()) failed"; goto cleanup; }
    builder = OSSL_PARAM_BLD_new();
    if (!builder) { error = "OSSL_PARAM_BLD_new() failed"; goto cleanup; }
    if (OSSL_PARAM_BLD_push_octet_string(builder, OSSL_PKEY_PARAM_ML_KEM_SEED, seed, seed_size) != 1
        || OSSL_PARAM_BLD_push_octet_string(builder, OSSL_PKEY_PARAM_ENCODED_PUBLIC_KEY, public_bytes, public_size) != 1
        || OSSL_PARAM_BLD_push_octet_string(builder, OSSL_PKEY_PARAM_PRIV_KEY, private_bytes, private_size) != 1) {
        error = "OSSL_PARAM_BLD_push_octet_string failed"; goto cleanup;
    }
    params = OSSL_PARAM_BLD_to_param(builder);
    if (!params || EVP_PKEY_fromdata(from, &key, EVP_PKEY_KEYPAIR, params) != 1) { error = "EVP_PKEY_fromdata(ctx.ptr(), &key_ptr, EVP_PKEY_KEYPAIR, params) failed"; goto cleanup; }
    ctx = EVP_PKEY_CTX_new_from_pkey(NULL, key, NULL);
    if (!ctx) { error = "ptr failed"; goto cleanup; }
    if (EVP_PKEY_decapsulate_init(ctx, NULL) != 1) { error = "EVP_PKEY_decapsulate_init(ctx.ptr(), nullptr) failed"; goto cleanup; }
    if (EVP_PKEY_decapsulate(ctx, NULL, shared_size, ciphertext, ciphertext_size) != 1) {
        error = "EVP_PKEY_decapsulate(ctx.ptr(), nullptr, &shared_key_size, ciphertext.data(), ciphertext.size()) failed"; goto cleanup;
    }
    if (*shared_size > capacity) { error = "Native decapsulation exceeds its output capacity"; goto cleanup; }
    if (EVP_PKEY_decapsulate(ctx, shared, shared_size, ciphertext, ciphertext_size) != 1)
        error = "EVP_PKEY_decapsulate(ctx.ptr(), shared_key.data(), &shared_key_size, ciphertext.data(), ciphertext.size()) failed";
cleanup:
    EVP_PKEY_CTX_free(ctx);
    EVP_PKEY_free(key);
    OSSL_PARAM_free(params);
    OSSL_PARAM_BLD_free(builder);
    EVP_PKEY_CTX_free(from);
    return error;
}

/* LibCrypto/PK/MLDSA.cpp private/public_key_to_openssl_pkey. */
static EVP_PKEY* vox_mldsa_key(const char* name, int private_key,
    const unsigned char* seed, size_t seed_size, const unsigned char* pub, size_t pub_size,
    const unsigned char* priv, size_t priv_size)
{
    if (!vox_crypto_prepare()) return NULL;
    EVP_PKEY_CTX* ctx = EVP_PKEY_CTX_new_from_name(NULL, name, NULL);
    EVP_PKEY* key = NULL;
    OSSL_PARAM_BLD* builder = NULL;
    OSSL_PARAM* params = NULL;
    if (!ctx || EVP_PKEY_fromdata_init(ctx) != 1) goto cleanup;
    builder = OSSL_PARAM_BLD_new();
    if (!builder) goto cleanup;
    if (private_key && OSSL_PARAM_BLD_push_octet_string(builder, OSSL_PKEY_PARAM_ML_DSA_SEED, seed, seed_size) != 1) goto cleanup;
    if (OSSL_PARAM_BLD_push_octet_string(builder, OSSL_PKEY_PARAM_PUB_KEY, pub, pub_size) != 1) goto cleanup;
    if (private_key && OSSL_PARAM_BLD_push_octet_string(builder, OSSL_PKEY_PARAM_PRIV_KEY, priv, priv_size) != 1) goto cleanup;
    params = OSSL_PARAM_BLD_to_param(builder);
    if (!params || EVP_PKEY_fromdata(ctx, &key, EVP_PKEY_KEYPAIR, params) != 1) {
        EVP_PKEY_free(key);
        key = NULL;
    }
cleanup:
    OSSL_PARAM_free(params);
    OSSL_PARAM_BLD_free(builder);
    EVP_PKEY_CTX_free(ctx);
    return key;
}

static int vox_mldsa_sign(const char* name, const unsigned char* seed, size_t seed_size,
    const unsigned char* pub, size_t pub_size, const unsigned char* priv, size_t priv_size,
    unsigned char* context, size_t context_size, const unsigned char* message, size_t message_size,
    unsigned char* signature, size_t* signature_size)
{
    if (!vox_crypto_prepare()) return 0;
    int success = 0;
    EVP_PKEY* key = vox_mldsa_key(name, 1, seed, seed_size, pub, pub_size, priv, priv_size);
    EVP_PKEY_CTX* ctx = key ? EVP_PKEY_CTX_new_from_pkey(NULL, key, NULL) : NULL;
    EVP_SIGNATURE* algorithm = EVP_SIGNATURE_fetch(NULL, name, NULL);
    OSSL_PARAM params[2] = { OSSL_PARAM_END, OSSL_PARAM_END };
    size_t capacity = *signature_size;
    if (context_size) params[0] = (OSSL_PARAM)OSSL_PARAM_octet_string(OSSL_SIGNATURE_PARAM_CONTEXT_STRING, context, context_size);
    if (!ctx || !algorithm) goto cleanup;
    if (EVP_PKEY_sign_message_init(ctx, algorithm, params) != 1) goto cleanup;
    if (EVP_PKEY_sign(ctx, NULL, signature_size, message, message_size) != 1) goto cleanup;
    if (*signature_size > capacity) goto cleanup;
    success = EVP_PKEY_sign(ctx, signature, signature_size, message, message_size) == 1;
cleanup:
    EVP_SIGNATURE_free(algorithm);
    EVP_PKEY_CTX_free(ctx);
    EVP_PKEY_free(key);
    return success;
}

static int vox_mldsa_verify(const char* name, const unsigned char* pub, size_t pub_size,
    unsigned char* context, size_t context_size, const unsigned char* signature, size_t signature_size,
    const unsigned char* message, size_t message_size)
{
    if (!vox_crypto_prepare()) return 0;
    int result = -1;
    EVP_PKEY* key = vox_mldsa_key(name, 0, NULL, 0, pub, pub_size, NULL, 0);
    EVP_PKEY_CTX* ctx = key ? EVP_PKEY_CTX_new(key, NULL) : NULL;
    EVP_SIGNATURE* algorithm = EVP_SIGNATURE_fetch(NULL, name, NULL);
    OSSL_PARAM params[2] = { OSSL_PARAM_END, OSSL_PARAM_END };
    if (context_size) params[0] = (OSSL_PARAM)OSSL_PARAM_octet_string(OSSL_SIGNATURE_PARAM_CONTEXT_STRING, context, context_size);
    if (!ctx || !algorithm) goto cleanup;
    if (EVP_PKEY_verify_message_init(ctx, algorithm, params) != 1) goto cleanup;
    result = EVP_PKEY_verify(ctx, signature, signature_size, message, message_size);
cleanup:
    EVP_SIGNATURE_free(algorithm);
    EVP_PKEY_CTX_free(ctx);
    EVP_PKEY_free(key);
    return result;
}
#else
static const char *vox_ml_generate(const char *name, const char *seed_name,
    unsigned char *seed, size_t seed_size, unsigned char *public_bytes, size_t *public_size,
    unsigned char *private_bytes, size_t *private_size, unsigned char *seed_out, size_t *seed_out_size) {
    if (!vox_crypto_prepare()) return "OpenSSL WebCrypto backend is unavailable";
    return "ML-KEM and ML-DSA require OpenSSL 3.5 or newer";
}
static const char *vox_mlkem_encapsulate(const char *name, const unsigned char *public_bytes,
    size_t public_size, unsigned char *ciphertext, size_t *ciphertext_size,
    unsigned char *shared, size_t *shared_size) {
    if (!vox_crypto_prepare()) return "OpenSSL WebCrypto backend is unavailable";
    return "ML-KEM requires OpenSSL 3.5 or newer";
}
static const char *vox_mlkem_decapsulate(const char *name, const unsigned char *seed, size_t seed_size,
    const unsigned char *public_bytes, size_t public_size, const unsigned char *private_bytes, size_t private_size,
    const unsigned char *ciphertext, size_t ciphertext_size, unsigned char *shared, size_t *shared_size) {
    if (!vox_crypto_prepare()) return "OpenSSL WebCrypto backend is unavailable";
    return "ML-KEM requires OpenSSL 3.5 or newer";
}
static int vox_mldsa_sign(const char *name, const unsigned char *seed, size_t seed_size,
    const unsigned char *pub, size_t pub_size, const unsigned char *priv, size_t priv_size,
    unsigned char *context, size_t context_size, const unsigned char *message, size_t message_size,
    unsigned char *signature, size_t *signature_size) {
    if (!vox_crypto_prepare()) return 0; return 0; }
static int vox_mldsa_verify(const char *name, const unsigned char *pub, size_t pub_size,
    unsigned char *context, size_t context_size, const unsigned char *signature, size_t signature_size,
    const unsigned char *message, size_t message_size) {
    if (!vox_crypto_prepare()) return 0; return -1; }
#endif
#endif
