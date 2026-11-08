// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// SubtleCrypto.cpp determine_support_from_operation_steps. No key generation,
// encryption or derivation is performed by a capability query.
module webcrypto

import webidl

pub fn supports_operation(operation string) bool {
 return operation in ['encrypt','decrypt','sign','verify','digest','generateKey','deriveKey','deriveBits','importKey','exportKey','wrapKey','unwrapKey','encapsulateKey','encapsulateBits','decapsulateKey','decapsulateBits','getPublicKey']
}

pub fn supported_key_length(algorithm webidl.Value) !KeyLengthResult {
 normalized := normalize_binding_algorithm(algorithm, 'get key length')!
 return normalized_key_length(normalized)
}

pub fn supports_parameters(operation string, algorithm webidl.Value, length ?u32) bool {
 normalized := normalize_binding_algorithm(algorithm, operation) or { return false }
 return validate_support_parameters(operation, normalized, length)
}

fn support_sha_bits(name string) ?u32 {
 return match name { 'SHA-1' { u32(160) } 'SHA-256' { u32(256) } 'SHA-384' { u32(384) } 'SHA-512' { u32(512) } else { none } }
}

fn validate_support_parameters(operation string, algorithm NormalizedCryptoAlgorithm, length ?u32) bool {
 p := algorithm.params
 if operation == 'get key length' {
  normalized_key_length(algorithm) or { return false }
  return true
 }
 if operation in ['encrypt','decrypt'] {
  return match p {
   AesCbcParams { p.iv.len == 16 }
   AesCtrParams { p.counter.len == 16 && p.length > 0 && p.length <= 128 }
   AesGcmParams { p.iv.len > 0 && (p.tag_length or { u8(128) }) in [u8(32),64,96,104,112,120,128] }
   AeadParams {
    if algorithm.name == 'AES-OCB' { p.iv.len > 0 && p.iv.len <= 15 && (p.tag_length or { u8(128) }) in [u8(64),96,128] }
    else { p.iv.len == 12 && (p.tag_length or { u8(128) }) == 128 }
   }
   else { true }
  }
 }
 if operation in ['sign','verify'] {
  return match p {
   EcdsaParams { support_sha_bits(p.hash) != none }
   Ed448Params { if algorithm.name.starts_with('ML-DSA-') { (p.context or { []u8{} }).len <= 255 } else { true } }
   KmacParams { p.output_length % 8 == 0 }
   else { true }
  }
 }
 if operation == 'digest' && p is CShakeParams {
  return p.output_length % 8 == 0 && (p.function_name or { []u8{} }).len == 0 && (p.customization or { []u8{} }).len == 0
 }
 if operation == 'generateKey' {
  return match p {
   AesKeyGenParams { p.length in [u16(128),192,256] }
   EcKeyGenParams { ec_scalar_size(p.named_curve) > 0 }
   HmacKeyGenParams { if bits := p.length { bits != 0 } else { _ := hash_block_size(p.hash) or { return false }; true } }
   KmacKeyGenParams { bits := p.length or { u32(8) }; bits > 0 && bits % 8 == 0 }
   RsaHashedKeyGenParams {
    exponent := unsigned_big_integer_bytes(p.public_exponent)
    if p.modulus_length < 4 || exponent.len == 0 || (exponent.len == 1 && exponent[0] < 3) || exponent.last() % 2 == 0 { return false }
    mut exponent_bits := u64(exponent.len - 1) * 8
    mut first := exponent[0]
    for first > 0 { exponent_bits++; first >>= 1 }
    if exponent_bits < p.modulus_length { return true }
    if exponent_bits > p.modulus_length { return false }
    // Only the all-ones exponent equals the forbidden 2^modulusLength - 1.
    leading := u8(255 >> u8(8 - ((p.modulus_length - 1) % 8 + 1)))
    !(exponent[0] == leading && exponent[1..].all(it == 255))
   }
   else { true }
  }
 }
 if operation == 'importKey' {
  return match p {
   EcKeyImportParams { ec_scalar_size(p.named_curve) > 0 }
   HmacImportParams { (p.length or { u32(1) }) > 0 }
   KmacImportParams { bits := p.length or { u32(8) }; bits > 0 && bits % 8 == 0 }
   else { true }
  }
 }
 if operation == 'deriveBits' {
  return match p {
   HkdfParams { bits := length or { return false }; hash_bits := support_sha_bits(p.hash) or { return false }; bits % 8 == 0 && bits <= 255 * hash_bits }
   Pbkdf2Params { bits := length or { return false }; bits % 8 == 0 && p.iterations > 0 && support_sha_bits(p.hash) != none }
   EcdhKeyDeriveParams {
    if p.public_key.type_ != .public_key || p.public_key.algorithm_name() != algorithm.name { return false }
    maximum := if algorithm.name == 'ECDH' {
     if p.public_key.algorithm !is EcKeyAlgorithm { return false }
     curve := (p.public_key.algorithm as EcKeyAlgorithm).named_curve
     u32(ec_scalar_size(curve) * 8)
    } else { u32(if algorithm.name == 'X448' { 448 } else { 256 }) }
    (length or { u32(0) }) <= maximum
   }
   Argon2Params {
    bits := length or { return false }
    bits >= 32 && bits % 8 == 0 && (p.version or { u8(19) }) == 19 && p.parallelism > 0 && p.parallelism < 1 << 24 && u64(p.memory) >= 8 * u64(p.parallelism) && p.passes > 0 && p.nonce.len >= 8
   }
   else { true }
  }
 }
 return true
}

pub fn supports_shared_key_import(algorithm webidl.Value, bits u32) bool {
 normalized := normalize_binding_algorithm(algorithm, 'importKey') or { return false }
 if !validate_support_parameters('importKey', normalized, none) { return false }
 // The upstream operation tries importing a zero-filled shared secret. Its
 // byte length is fixed by the KEM, so this does not run a KEM or generate a key.
 normalized_import(normalized, .raw_secret, []u8{len: int((bits + 7) / 8)}, false, []) or { return false }
 return true
}
