// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// WICG modern algorithms, hybrid KEM operations; IETF concrete-hybrid-kems-04
// and hybrid-kems-12 CG construction. Native curve and ML-KEM primitives use
// the existing OpenSSL backend. The private handle is the 32-byte seed.
module webcrypto

import crypto.rand
import crypto.sha3
import encoding.hex

fn is_hybrid_kem(name string) bool {
 return name in ['MLKEM768-P256','MLKEM768-X25519','MLKEM1024-P384']
}

struct HybridKemConfig {
 pq string
 curve string
 scalar_seed int
 public_size int
 ciphertext_size int
 label []u8
}

fn hybrid_kem_config(name string) !HybridKemConfig {
 return match name {
  'MLKEM768-P256' { HybridKemConfig{pq:'ML-KEM-768',curve:'P-256',scalar_seed:128,public_size:1249,ciphertext_size:1153,label:name.bytes()} }
  'MLKEM768-X25519' { HybridKemConfig{pq:'ML-KEM-768',curve:'X25519',scalar_seed:32,public_size:1216,ciphertext_size:1120,label:[u8(0x5c),0x2e,0x2f,0x2f,0x5e,0x5c]} }
  'MLKEM1024-P384' { HybridKemConfig{pq:'ML-KEM-1024',curve:'P-384',scalar_seed:48,public_size:1665,ciphertext_size:1665,label:name.bytes()} }
  else { return error('NotSupportedError: Unknown hybrid KEM') }
 }
}

fn hybrid_kem_scalar(config HybridKemConfig, seed []u8) ![]u8 {
 if config.curve == 'X25519' { return seed.clone() }
 order := hex.decode(if config.curve == 'P-256' { 'ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551' }
  else { 'ffffffffffffffffffffffffffffffffffffffffffffffffc7634d81f4372ddf581a0db248b0a77aecec196accc52973' })!
 for start := 0; start + order.len <= seed.len; start += order.len {
  candidate := seed[start..start + order.len]
  if candidate.all(it == 0) { continue }
  for i in 0 .. order.len {
   if candidate[i] < order[i] { return candidate.clone() }
   if candidate[i] > order[i] { break }
  }
 }
 return error('OperationError: Hybrid scalar rejection sampling failed')
}

fn hybrid_kem_public_point(config HybridKemConfig, scalar []u8) ![]u8 {
 if config.curve == 'X25519' { return native_edwards_public('X25519',scalar) }
 return ec_point_to_uncompressed(native_ec_public(config.curve,scalar)!)
}

fn hybrid_kem_exchange(config HybridKemConfig, scalar []u8, public_bytes []u8) ![]u8 {
 if config.curve == 'X25519' { return native_edwards_coordinate('X25519',scalar,public_bytes) }
 if public_bytes.len != 2 * ec_scalar_size(config.curve) + 1 || public_bytes[0] != 4 { return error('OperationError: Invalid hybrid curve point') }
 point := parse_ec_public(public_bytes)!
 return native_ec_coordinate(config.curve,scalar,point)!.x
}

fn hybrid_kem_expand(name string, seed []u8) !([]u8, MlkemPrivateKeyHandle, []u8) {
 if seed.len != 32 { return error('DataError: Invalid hybrid seed length') }
 config := hybrid_kem_config(name)!
 mut shake := sha3.new_shake256()
 shake.write(seed)
 expanded := shake.read(64 + config.scalar_seed)
 pq := native_mlkem_generate(config.pq,expanded[..64])!
 scalar := hybrid_kem_scalar(config,expanded[64..])!
 mut public_bytes := pq.public_key.clone()
 public_bytes << hybrid_kem_public_point(config,scalar)!
 return public_bytes,pq,scalar
}

fn hybrid_kem_public(name string, seed []u8) ![]u8 {
 public_bytes,_,_ := hybrid_kem_expand(name,seed)!
 return public_bytes
}

fn hybrid_kem_combine(config HybridKemConfig, pq_secret []u8, curve_secret []u8, ephemeral []u8, public_curve []u8) []u8 {
 mut input := pq_secret.clone()
 input << curve_secret
 input << ephemeral
 input << public_curve
 input << config.label
 return sha3.sum256(input)
}

fn generate_hybrid_kem(name string, extractable bool, usages []KeyUsage) !GeneratedKey {
 for usage in usages {
  if usage !in [KeyUsage.encapsulate_bits,.encapsulate_key,.decapsulate_bits,.decapsulate_key] { return error('SyntaxError: Invalid hybrid key usage') }
 }
 seed := rand.bytes(32)!
 public_bytes := hybrid_kem_public(name,seed)!
 algorithm := KeyAlgorithm{name:name}
 return GeneratedKey{pair:CryptoKeyPair{
  public_key:CryptoKey.create(.public_key,true,algorithm,normalize_key_usages(usages.filter(it in [.encapsulate_bits,.encapsulate_key])),public_bytes)
  private_key:CryptoKey.create(.private_key,extractable,algorithm,normalize_key_usages(usages.filter(it in [.decapsulate_bits,.decapsulate_key])),seed)
 }}
}

fn hybrid_kem_encapsulate(name string, key &CryptoKey) !EncapsulatedBits {
 if key.type_ != .public_key { return error('InvalidAccessError: Key is not public') }
 config := hybrid_kem_config(name)!
 public_bytes := key.handle()
 if public_bytes.len != config.public_size { return error('OperationError: Invalid hybrid public key length') }
 pq_public_size,_,_ := mlkem_sizes(config.pq)!
 pq := native_mlkem_encapsulate(config.pq,public_bytes[..pq_public_size])!
 scalar := hybrid_kem_scalar(config,rand.bytes(config.scalar_seed)!)!
 ephemeral := hybrid_kem_public_point(config,scalar)!
 agreement := hybrid_kem_exchange(config,scalar,public_bytes[pq_public_size..])!
 mut ciphertext := (pq.ciphertext or { return error('OperationError: Missing ML-KEM ciphertext') }).clone()
 ciphertext << ephemeral
 return EncapsulatedBits{shared_key:hybrid_kem_combine(config,pq.shared_key or { return error('OperationError: Missing ML-KEM secret') },agreement,ephemeral,public_bytes[pq_public_size..]),ciphertext:ciphertext}
}

fn hybrid_kem_decapsulate(name string, key &CryptoKey, ciphertext []u8) ![]u8 {
 if key.type_ != .private_key { return error('InvalidAccessError: Key is not private') }
 config := hybrid_kem_config(name)!
 if ciphertext.len != config.ciphertext_size { return error('OperationError: Invalid hybrid ciphertext length') }
 public_bytes,pq,scalar := hybrid_kem_expand(name,key.handle())!
 pq_public_size,_,pq_cipher_size := mlkem_sizes(config.pq)!
 pq_secret := native_mlkem_decapsulate(config.pq,pq,ciphertext[..pq_cipher_size])!
 ephemeral := ciphertext[pq_cipher_size..]
 curve_secret := hybrid_kem_exchange(config,scalar,ephemeral)!
 return hybrid_kem_combine(config,pq_secret,curve_secret,ephemeral,public_bytes[pq_public_size..])
}

fn import_hybrid_kem(name string, format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey {
 config := hybrid_kem_config(name)!
 if format == .jwk { return import_hybrid_kem_jwk(name,decode_json_web_key_dictionary(material)!,extractable,usages) }
 private_key := format == .raw_seed
 if format !in [.raw_public,.raw_seed] { return error('NotSupportedError: Unsupported hybrid key format') }
 allowed := if private_key { [KeyUsage.decapsulate_bits,.decapsulate_key] } else { [KeyUsage.encapsulate_bits,.encapsulate_key] }
 for usage in usages { if usage !in allowed { return error('SyntaxError: Invalid hybrid key usage') } }
 if material.len != (if private_key { 32 } else { config.public_size }) { return error('DataError: Invalid hybrid key length') }
 return CryptoKey.create(if private_key { .private_key } else { .public_key },extractable,KeyAlgorithm{name:name},normalize_key_usages(usages),material)
}

fn export_hybrid_kem(format KeyFormat, key &CryptoKey) ![]u8 {
 if format == .jwk { return export_hybrid_kem_jwk(key)!.to_json().bytes() }
 if (format == .raw_public && key.type_ == .public_key) || (format == .raw_seed && key.type_ == .private_key) { return key.handle() }
 return error('NotSupportedError: Unsupported hybrid key format')
}

fn import_hybrid_kem_jwk(name string, jwk JsonWebKey, extractable bool, usages []KeyUsage) !&CryptoKey {
 if (jwk.kty or { '' }) != 'AKP' { return error('DataError: Invalid hybrid JWK type') }
 if alg := jwk.alg { if alg != name { return error('DataError: Invalid hybrid JWK algorithm') } }
 if usages.len > 0 { if use_ := jwk.use { if use_ != 'enc' { return error('DataError: Invalid hybrid JWK use') } } }
 validate_jwk_key_ops(jwk,usages)!
 if ext := jwk.ext { if !ext && extractable { return error('DataError: Invalid hybrid JWK extractability') } }
 public_bytes := base64url_decode(jwk.pub_ or { return error('DataError: Missing hybrid public key') })!
 if seed_text := jwk.priv {
  seed := base64url_decode(seed_text)!
  key := import_hybrid_kem(name,.raw_seed,seed,extractable,usages)!
  if hybrid_kem_public(name,seed)! != public_bytes { return error('DataError: Hybrid public and private keys do not match') }
  return key
 }
 return import_hybrid_kem(name,.raw_public,public_bytes,extractable,usages)
}

fn export_hybrid_kem_jwk(key &CryptoKey) !JsonWebKey {
 private_key := key.type_ == .private_key
 public_bytes := if private_key { hybrid_kem_public(key.algorithm_name(),key.handle())! } else { key.handle() }
 return JsonWebKey{kty:'AKP',alg:key.algorithm_name(),pub_:base64url_encode(public_bytes),priv:if private_key { ?string(base64url_encode(key.handle())) } else { none },key_ops:key.usages.map(key_usage_string(it)),ext:key.extractable}
}
