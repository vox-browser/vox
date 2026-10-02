// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the shared algorithms and parameter conversion entry points
// in CryptoAlgorithms.cpp, CryptoKey.cpp, KeyAlgorithms.cpp, and
// SubtleCrypto.cpp. JavaScript values are represented by json2.Any at the
// binding boundary; cryptographic operations use typed V records below it.
module webcrypto

import crypto.rand
import x.json2

pub struct HashAlgorithmIdentifier {
pub:
	name_ string
}

pub fn (identifier HashAlgorithmIdentifier) name() !string {
	return identifier.name_
}

pub fn hash_algorithm_identifier_from_value(value json2.Any) !HashAlgorithmIdentifier {
	mut name := ''
	if value is string {
		name = value
	} else if value is map[string]json2.Any {
		object := value as map[string]json2.Any
		name_value := object['name'] or { return error('TypeError: Algorithm has no name') }
		if name_value !is string {
			return error('TypeError: Algorithm name is not a string')
		}
		name = name_value as string
	} else {
		return error('TypeError: Algorithm identifier must be a string or object')
	}
	return HashAlgorithmIdentifier{
		name_: normalize_an_algorithm(name, 'digest')!
	}
}

fn algorithm_object(value json2.Any) !map[string]json2.Any {
	if value !is map[string]json2.Any {
		return error('TypeError: Algorithm parameters must be an object')
	}
	return value as map[string]json2.Any
}

fn optional_algorithm_string(object map[string]json2.Any, key string) ?string {
	value := object[key] or { return none }
	if value is string {
		return value
	}
	return none
}

fn required_algorithm_string(object map[string]json2.Any, key string) !string {
	return optional_algorithm_string(object, key) or {
		error('TypeError: ${key} must be a string')
	}
}

fn optional_algorithm_u32(object map[string]json2.Any, key string) ?u32 {
	value := object[key] or { return none }
	if value is i64 {
		if value >= 0 && value <= i64(0xffff_ffff) {
			return u32(value)
		}
	}
	if value is f64 {
		if value >= 0 && value <= f64(0xffff_ffff) && value == math_floor(value) {
			return u32(value)
		}
	}
	return none
}

fn required_algorithm_u32(object map[string]json2.Any, key string) !u32 {
	return optional_algorithm_u32(object, key) or {
		error('TypeError: ${key} must be an unsigned integer')
	}
}

fn math_floor(value f64) f64 {
	return f64(i64(value))
}

fn optional_algorithm_bytes(object map[string]json2.Any, key string) ?[]u8 {
	value := object[key] or { return none }
	if value is string {
		return value.bytes()
	}
	if value is []json2.Any {
		mut bytes := []u8{cap: value.len}
		for item in value {
			if item is i64 && item >= 0 && item <= 255 {
				bytes << u8(item)
			} else if item is f64 && item >= 0 && item <= 255 && item == math_floor(item) {
				bytes << u8(item)
			} else {
				return none
			}
		}
		return bytes
	}
	return none
}

fn required_algorithm_bytes(object map[string]json2.Any, key string) ![]u8 {
	return optional_algorithm_bytes(object, key) or {
		error('TypeError: ${key} must be a buffer source')
	}
}

pub fn AlgorithmParams.from_value(value json2.Any) !AlgorithmParams {
	_ = value
	return AlgorithmParams{}
}

pub fn AesCbcParams.from_value(value json2.Any) !AesCbcParams {
	object := algorithm_object(value)!
	return AesCbcParams{
		name: ''
		iv: required_algorithm_bytes(object, 'iv')!
	}
}

pub fn AesCtrParams.from_value(value json2.Any) !AesCtrParams {
	object := algorithm_object(value)!
	length := required_algorithm_u32(object, 'length')!
	if length > 255 {
		return error('TypeError: length is outside the octet range')
	}
	return AesCtrParams{
		name: ''
		counter: required_algorithm_bytes(object, 'counter')!
		length: u8(length)
	}
}

pub fn AesGcmParams.from_value(value json2.Any) !AesGcmParams {
	object := algorithm_object(value)!
	mut tag_length := ?u8(none)
	if 'tagLength' in object {
		actual := required_algorithm_u32(object, 'tagLength')!
		if actual > 255 {
			return error('TypeError: tagLength is outside the octet range')
		}
		tag_length = u8(actual)
	}
	mut additional_data := ?[]u8(none)
	if 'additionalData' in object {
		additional_data = required_algorithm_bytes(object, 'additionalData')!
	}
	return AesGcmParams{
		name: ''
		iv: required_algorithm_bytes(object, 'iv')!
		additional_data: additional_data
		tag_length: tag_length
	}
}

pub fn HKDFParams.from_value(value json2.Any) !HKDFParams {
	object := algorithm_object(value)!
	hash := hash_algorithm_identifier_from_value(object['hash'] or {
		return error('TypeError: hash is required')
	})!
	return HKDFParams(HkdfParams{
		name: ''
		hash: hash.name()!
		salt: required_algorithm_bytes(object, 'salt')!
		info: required_algorithm_bytes(object, 'info')!
	})
}

pub fn PBKDF2Params.from_value(value json2.Any) !PBKDF2Params {
	object := algorithm_object(value)!
	hash := hash_algorithm_identifier_from_value(object['hash'] or {
		return error('TypeError: hash is required')
	})!
	return PBKDF2Params(Pbkdf2Params{
		name: ''
		hash: hash.name()!
		salt: required_algorithm_bytes(object, 'salt')!
		iterations: required_algorithm_u32(object, 'iterations')!
	})
}

pub fn AesKeyGenParams.from_value(value json2.Any) !AesKeyGenParams {
	object := algorithm_object(value)!
	length := required_algorithm_u32(object, 'length')!
	if length > 0xffff {
		return error('TypeError: length is outside the unsigned-short range')
	}
	return AesKeyGenParams{
		name: ''
		length: u16(length)
	}
}

pub fn AesDerivedKeyParams.from_value(value json2.Any) !AesDerivedKeyParams {
	object := algorithm_object(value)!
	length := required_algorithm_u32(object, 'length')!
	if length > 0xffff {
		return error('TypeError: length is outside the unsigned-short range')
	}
	return AesDerivedKeyParams{
		name: ''
		length: u16(length)
	}
}

pub fn RsaKeyGenParams.from_value(value json2.Any) !RsaKeyGenParams {
	object := algorithm_object(value)!
	return RsaKeyGenParams{
		name: ''
		modulus_length: required_algorithm_u32(object, 'modulusLength')!
		public_exponent: big_integer_from_api_big_integer(required_algorithm_bytes(object, 'publicExponent')!)
	}
}

pub fn RsaHashedKeyGenParams.from_value(value json2.Any) !RsaHashedKeyGenParams {
	object := algorithm_object(value)!
	hash := hash_algorithm_identifier_from_value(object['hash'] or {
		return error('TypeError: hash is required')
	})!
	return RsaHashedKeyGenParams{
		name: ''
		modulus_length: required_algorithm_u32(object, 'modulusLength')!
		public_exponent: big_integer_from_api_big_integer(required_algorithm_bytes(object, 'publicExponent')!)
		hash: hash.name()!
	}
}

pub fn RsaHashedImportParams.from_value(value json2.Any) !RsaHashedImportParams {
	object := algorithm_object(value)!
	hash := hash_algorithm_identifier_from_value(object['hash'] or {
		return error('TypeError: hash is required')
	})!
	return RsaHashedImportParams{
		name: ''
		hash: hash.name()!
	}
}

pub fn RsaOaepParams.from_value(value json2.Any) !RsaOaepParams {
	object := algorithm_object(value)!
	return RsaOaepParams{
		name: ''
		label: optional_algorithm_bytes(object, 'label') or { []u8{} }
	}
}

pub fn RsaPssParams.from_value(value json2.Any) !RsaPssParams {
	object := algorithm_object(value)!
	return RsaPssParams{
		name: ''
		salt_length: required_algorithm_u32(object, 'saltLength')!
	}
}

pub fn EcdsaParams.from_value(value json2.Any) !EcdsaParams {
	object := algorithm_object(value)!
	hash := hash_algorithm_identifier_from_value(object['hash'] or {
		return error('TypeError: hash is required')
	})!
	return EcdsaParams{
		name: ''
		hash: hash.name()!
	}
}

pub fn EcKeyGenParams.from_value(value json2.Any) !EcKeyGenParams {
	object := algorithm_object(value)!
	return EcKeyGenParams{
		name: ''
		named_curve: required_algorithm_string(object, 'namedCurve')!
	}
}

pub fn EcKeyImportParams.from_value(value json2.Any) !EcKeyImportParams {
	object := algorithm_object(value)!
	return EcKeyImportParams{
		name: ''
		named_curve: required_algorithm_string(object, 'namedCurve')!
	}
}

pub fn HmacImportParams.from_value(value json2.Any) !HmacImportParams {
	object := algorithm_object(value)!
	hash := hash_algorithm_identifier_from_value(object['hash'] or {
		return error('TypeError: hash is required')
	})!
	mut length := ?u32(none)
	if 'length' in object {
		length = required_algorithm_u32(object, 'length')!
	}
	return HmacImportParams{
		name: ''
		hash: hash.name()!
		length: length
	}
}

pub fn HmacKeyGenParams.from_value(value json2.Any) !HmacKeyGenParams {
	object := algorithm_object(value)!
	hash := hash_algorithm_identifier_from_value(object['hash'] or {
		return error('TypeError: hash is required')
	})!
	mut length := ?u32(none)
	if 'length' in object {
		length = required_algorithm_u32(object, 'length')!
	}
	return HmacKeyGenParams{
		name: ''
		hash: hash.name()!
		length: length
	}
}

pub fn EcdhKeyDeriveParams.from_value(value json2.Any, public_key &CryptoKey) !EcdhKeyDeriveParams {
	_ = algorithm_object(value)!
	return EcdhKeyDeriveParams{
		name: ''
		public_key: public_key
	}
}

pub fn Ed448Params.from_value(value json2.Any) !Ed448Params {
	object := algorithm_object(value)!
	return Ed448Params{
		name: ''
		context: optional_algorithm_bytes(object, 'context')
	}
}

pub fn Argon2Params.from_value(value json2.Any) !Argon2Params {
	object := algorithm_object(value)!
	mut version := ?u8(none)
	if 'version' in object {
		actual := required_algorithm_u32(object, 'version')!
		if actual > 255 {
			return error('TypeError: version is outside the octet range')
		}
		version = u8(actual)
	}
	mut secret_value := ?[]u8(none)
	if 'secretValue' in object {
		secret_value = required_algorithm_bytes(object, 'secretValue')!
	}
	mut associated_data := ?[]u8(none)
	if 'associatedData' in object {
		associated_data = required_algorithm_bytes(object, 'associatedData')!
	}
	return Argon2Params{
		name: ''
		nonce: required_algorithm_bytes(object, 'nonce')!
		parallelism: required_algorithm_u32(object, 'parallelism')!
		memory: required_algorithm_u32(object, 'memory')!
		passes: required_algorithm_u32(object, 'passes')!
		version: version
		secret_value: secret_value
		associated_data: associated_data
	}
}

pub fn CShakeParams.from_value(value json2.Any) !CShakeParams {
	object := algorithm_object(value)!
	return CShakeParams{
		name: ''
		output_length: required_algorithm_u32(object, 'outputLength')!
		function_name: optional_algorithm_bytes(object, 'functionName')
		customization: optional_algorithm_bytes(object, 'customization')
	}
}

pub fn KmacParams.from_value(value json2.Any) !KmacParams {
	object := algorithm_object(value)!
	return KmacParams{
		name: ''
		output_length: required_algorithm_u32(object, 'outputLength')!
		customization: optional_algorithm_bytes(object, 'customization')
	}
}

pub fn KmacKeyGenParams.from_value(value json2.Any) !KmacKeyGenParams {
	object := algorithm_object(value)!
	mut length := ?u32(none)
	if 'length' in object {
		length = required_algorithm_u32(object, 'length')!
	}
	return KmacKeyGenParams{
		name: ''
		length: length
	}
}

pub fn KmacImportParams.from_value(value json2.Any) !KmacImportParams {
	object := algorithm_object(value)!
	mut length := ?u32(none)
	if 'length' in object {
		length = required_algorithm_u32(object, 'length')!
	}
	return KmacImportParams{
		name: ''
		length: length
	}
}

pub fn AeadParams.from_value(value json2.Any) !AeadParams {
	object := algorithm_object(value)!
	mut tag_length := ?u8(none)
	if 'tagLength' in object {
		actual := required_algorithm_u32(object, 'tagLength')!
		if actual > 255 {
			return error('TypeError: tagLength is outside the octet range')
		}
		tag_length = u8(actual)
	}
	mut additional_data := ?[]u8(none)
	if 'additionalData' in object {
		additional_data = required_algorithm_bytes(object, 'additionalData')!
	}
	return AeadParams{
		name: ''
		iv: required_algorithm_bytes(object, 'iv')!
		additional_data: additional_data
		tag_length: tag_length
	}
}

pub fn usage_intersection(first []KeyUsage, second []KeyUsage) []KeyUsage {
	mut result := []KeyUsage{}
	for usage in first {
		if usage in second {
			result << usage
		}
	}
	result.sort_with_compare(fn (a &KeyUsage, b &KeyUsage) int {
		return int(*a) - int(*b)
	})
	return result
}

pub fn big_integer_from_api_big_integer(bytes []u8) []u8 {
	return unsigned_big_integer_bytes(bytes)
}

pub fn export_public_exponent(exponent []u8) []u8 {
	return unsigned_big_integer_bytes(exponent)
}

pub fn key_usage_to_string(usage KeyUsage) string {
	return match usage {
		.encrypt { 'encrypt' }
		.decrypt { 'decrypt' }
		.sign { 'sign' }
		.verify { 'verify' }
		.derive_key { 'deriveKey' }
		.derive_bits { 'deriveBits' }
		.wrap_key { 'wrapKey' }
		.unwrap_key { 'unwrapKey' }
		.encapsulate_key { 'encapsulateKey' }
		.encapsulate_bits { 'encapsulateBits' }
		.decapsulate_key { 'decapsulateKey' }
		.decapsulate_bits { 'decapsulateBits' }
	}
}

pub fn key_format_to_string(format KeyFormat) string {
	return match format {
		.raw_public { 'raw-public' }
		.raw_private { 'raw-private' }
		.raw_seed { 'raw-seed' }
		.raw_secret { 'raw-secret' }
		.raw { 'raw' }
		.spki { 'spki' }
		.pkcs8 { 'pkcs8' }
		.jwk { 'jwk' }
	}
}

pub fn base64_url_bytes_encode(bytes []u8) string {
	return base64url_encode(bytes)
}

pub fn base64_url_uint_encode(bytes []u8) string {
	return base64url_encode(unsigned_big_integer_bytes(bytes))
}

pub enum KmacKind {
	kmac128
	kmac256
}

pub fn kmac_kind_from_algorithm_name(algorithm_name string) ?KmacKind {
	return match algorithm_name {
		'KMAC128' { KmacKind.kmac128 }
		'KMAC256' { KmacKind.kmac256 }
		else { none }
	}
}

pub fn base64_url_bytes_decode(value string) ![]u8 {
	return base64url_decode(value)
}

pub fn base64_url_uint_decode(value string) ![]u8 {
	return unsigned_big_integer_bytes(base64url_decode(value)!)
}

pub struct Asn1Structure {
pub:
	tag      u8
	contents []u8
}

pub fn parse_an_asn1_structure(data []u8) !Asn1Structure {
	if data.len < 2 {
		return error('DataError: Invalid ASN.1 structure')
	}
	mut offset := 2
	mut length := u32(data[1])
	if data[1] & 0x80 != 0 {
		length_octets := int(data[1] & 0x7f)
		if length_octets == 0 || length_octets > 4 || data.len < 2 + length_octets {
			return error('DataError: Invalid ASN.1 length')
		}
		length = 0
		for octet in data[2..2 + length_octets] {
			length = (length << 8) | u32(octet)
		}
		offset += length_octets
	}
	if offset + int(length) != data.len {
		return error('DataError: Invalid ASN.1 structure length')
	}
	return Asn1Structure{ tag: data[0], contents: data[offset..].clone() }
}

pub fn parse_a_subject_public_key_info(data []u8) !Asn1Structure {
	structure := parse_an_asn1_structure(data)!
	if structure.tag != 0x30 {
		return error('DataError: SPKI is not an ASN.1 sequence')
	}
	return structure
}

pub fn parse_a_private_key_info(data []u8) !Asn1Structure {
	structure := parse_an_asn1_structure(data)!
	if structure.tag != 0x30 {
		return error('DataError: PKCS#8 is not an ASN.1 sequence')
	}
	return structure
}

pub struct RsaPublicKeyData {
pub:
	modulus         []u8
	public_exponent []u8
}

pub struct RsaPrivateKeyData {
pub:
	modulus          []u8
	private_exponent []u8
	public_exponent  []u8
	first_prime      ?[]u8
	second_prime     ?[]u8
	first_exponent   ?[]u8
	second_exponent  ?[]u8
	coefficient      ?[]u8
}

pub fn parse_jwk_rsa_private_key(jwk JsonWebKey) !RsaPrivateKeyData {
	modulus := base64_url_uint_decode(jwk.n or {
		return error('DataError: RSA JWK has no n member')
	})!
	private_exponent := base64_url_uint_decode(jwk.d or {
		return error('DataError: RSA JWK has no d member')
	})!
	public_exponent := base64_url_uint_decode(jwk.e or {
		return error('DataError: RSA JWK has no e member')
	})!
	if p := jwk.p {
		return RsaPrivateKeyData{
			modulus: modulus
			private_exponent: private_exponent
			public_exponent: public_exponent
			first_prime: base64_url_uint_decode(p)!
			second_prime: base64_url_uint_decode(jwk.q or {
				return error('DataError: RSA JWK has p but no q member')
			})!
			first_exponent: base64_url_uint_decode(jwk.dp or {
				return error('DataError: RSA JWK has p but no dp member')
			})!
			second_exponent: base64_url_uint_decode(jwk.dq or {
				return error('DataError: RSA JWK has p but no dq member')
			})!
			coefficient: base64_url_uint_decode(jwk.qi or {
				return error('DataError: RSA JWK has p but no qi member')
			})!
		}
	}
	return RsaPrivateKeyData{
		modulus: modulus
		private_exponent: private_exponent
		public_exponent: public_exponent
	}
}

pub fn parse_jwk_rsa_public_key(jwk JsonWebKey) !RsaPublicKeyData {
	return RsaPublicKeyData{
		modulus: base64_url_uint_decode(jwk.n or {
			return error('DataError: RSA JWK has no n member')
		})!
		public_exponent: base64_url_uint_decode(jwk.e or {
			return error('DataError: RSA JWK has no e member')
		})!
	}
}

pub fn parse_jwk_symmetric_key(jwk JsonWebKey) ![]u8 {
	return base64url_decode(jwk.k or { return error("DataError: JWK has no 'k' field") })
}

pub fn generate_random_key(length_bits u16) ![]u8 {
	return rand.bytes(int(length_bits / 8))
}

pub fn get_optional_buffer_source(object map[string]json2.Any, key string) ?[]u8 {
	return optional_algorithm_bytes(object, key)
}

pub fn hmac_calculate_message_digest(hash_name string, key []u8, message []u8) ![]u8 {
	return hmac_bytes(hash_name, key, message)
}

pub fn hmac_hash_block_size(hash_name string) !u32 {
	return u32(hash_block_size(hash_name)!)
}

pub fn kmac_calculate_mac(name string, key []u8, message []u8, output_length u32, customization []u8) ![]u8 {
	kmac_default_length(name)!
	if output_length == 0 || output_length % 8 != 0 {
		return error('OperationError: KMAC operation failed')
	}
	return native_kmac(name, key, message, customization, int(output_length / 8))
}

pub fn normalize_key_usages(usages []KeyUsage) []KeyUsage {
	return normalize_key_usages_for_operation(usages)
}

pub fn supported_algorithms_internal() map[string][]string {
	mut result := map[string][]string{}
	for operation in ['encrypt', 'decrypt', 'sign', 'verify', 'digest', 'deriveBits', 'wrapKey',
		'unwrapKey', 'generateKey', 'importKey', 'exportKey', 'get key length', 'encapsulate',
		'decapsulate'] {
		result[operation] = supported_algorithms_for_operation(operation)
	}
	return result
}

pub fn supported_algorithms() map[string][]string {
	return supported_algorithms_internal()
}

pub fn define_an_algorithm(mut registry map[string][]string, operation string,
	algorithm string) {
	mut algorithms := registry[operation] or { []string{} }
	if algorithm !in algorithms { algorithms << algorithm }
	registry[operation] = algorithms
}

pub fn impl_from[T](value T) T {
	return value
}

pub fn (pair &CryptoKeyPair) public_key() &CryptoKey {
	return pair.public_key
}

pub fn (pair &CryptoKeyPair) private_key() &CryptoKey {
	return pair.private_key
}

pub fn (algorithm KeyAlgorithm) realm() u64 {
	return algorithm.realm_id
}

pub fn (bits EncapsulatedBits) to_object() map[string]json2.Any {
	mut object := map[string]json2.Any{}
	if shared_key := bits.shared_key {
		object['sharedKey'] = json2.Any(shared_key.clone())
	}
	if ciphertext := bits.ciphertext {
		object['ciphertext'] = json2.Any(ciphertext.clone())
	}
	return object
}

pub fn (key EncapsulatedKey) to_object() map[string]json2.Any {
	mut object := map[string]json2.Any{}
	if shared_key := key.shared_key {
		object['sharedKey'] = json2.Any(shared_key.algorithm_name())
	}
	if ciphertext := key.ciphertext {
		object['ciphertext'] = json2.Any(ciphertext.clone())
	}
	return object
}

// The C++ virtual base returns NotSupportedError for every operation.
pub struct AlgorithmMethods {}

pub struct KeyLengthResult {
pub:
	value ?u32
}

pub fn AlgorithmMethods.create() AlgorithmMethods {
	return AlgorithmMethods{}
}

pub fn (_ AlgorithmMethods) encrypt(_ AlgorithmParams, _ &CryptoKey, _ []u8) ![]u8 {
	return error('NotSupportedError: encrypt is not supported')
}

pub fn (_ AlgorithmMethods) decrypt(_ AlgorithmParams, _ &CryptoKey, _ []u8) ![]u8 {
	return error('NotSupportedError: decrypt is not supported')
}

pub fn (_ AlgorithmMethods) sign(_ AlgorithmParams, _ &CryptoKey, _ []u8) ![]u8 {
	return error('NotSupportedError: sign is not supported')
}

pub fn (_ AlgorithmMethods) verify(_ AlgorithmParams, _ &CryptoKey, _ []u8, _ []u8) !bool {
	return error('NotSupportedError: verify is not supported')
}

pub fn (_ AlgorithmMethods) digest(_ AlgorithmParams, _ []u8) ![]u8 {
	return error('NotSupportedError: digest is not supported')
}

pub fn (_ AlgorithmMethods) derive_bits(_ AlgorithmParams, _ &CryptoKey, _ ?u32) ![]u8 {
	return error('NotSupportedError: deriveBits is not supported')
}

pub fn (_ AlgorithmMethods) import_key(_ AlgorithmParams, _ KeyFormat, _ []u8, _ bool, _ []KeyUsage) !&CryptoKey {
	return error('NotSupportedError: importKey is not supported')
}

pub fn (_ AlgorithmMethods) generate_key(_ AlgorithmParams, _ bool, _ []KeyUsage) !GeneratedKey {
	return error('NotSupportedError: generateKey is not supported')
}

pub fn (_ AlgorithmMethods) export_key(_ KeyFormat, _ &CryptoKey) ![]u8 {
	return error('NotSupportedError: exportKey is not supported')
}

pub fn (_ AlgorithmMethods) get_key_length(_ AlgorithmParams) !KeyLengthResult {
	return error('NotSupportedError: getKeyLength is not supported')
}

pub fn (_ AlgorithmMethods) wrap_key(_ AlgorithmParams, _ &CryptoKey, _ []u8) ![]u8 {
	return error('NotSupportedError: wrapKey is not supported')
}

pub fn (_ AlgorithmMethods) unwrap_key(_ AlgorithmParams, _ &CryptoKey, _ []u8) ![]u8 {
	return error('NotSupportedError: unwrapKey is not supported')
}

pub fn (_ AlgorithmMethods) encapsulate(_ AlgorithmParams, _ &CryptoKey) !EncapsulatedBits {
	return error('NotSupportedError: encapsulate is not supported')
}

pub fn (_ AlgorithmMethods) decapsulate(_ AlgorithmParams, _ &CryptoKey, _ []u8) ![]u8 {
	return error('NotSupportedError: decapsulate is not supported')
}
