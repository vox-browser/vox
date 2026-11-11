// Copyright (c) 2026, Ladybird contributors
// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the shared algorithms and parameter conversion entry points
// in CryptoAlgorithms.cpp, CryptoKey.cpp, KeyAlgorithms.cpp, and
// SubtleCrypto.cpp. JavaScript values are represented by json2.Any at the
// binding boundary; cryptographic operations use typed V records below it.
module webcrypto

import crypto.rand
import libjs
import webidl
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
		if 'name' !in object {
			return error('TypeError: Not an object of type Algorithm')
		}
		name = algorithm_js_string(object, 'name')!
	} else {
		// A hash dictionary member uses the AlgorithmIdentifier union's
		// DOMString conversion for primitive values, including null.
		name = algorithm_js_string({'hash': value}, 'hash')!
	}
	normalized := normalize_an_algorithm(name, 'digest')!
	if normalized in ['cSHAKE128', 'cSHAKE256'] {
		dictionary := if value is map[string]json2.Any {
			json2.Any(value)
		} else {
			json2.Any({'name': json2.Any(name)})
		}
		_ = CShakeParams.from_value(dictionary)!
	}
	return HashAlgorithmIdentifier{ name_: normalized }
}

fn algorithm_object(value json2.Any) !map[string]json2.Any {
	if value !is map[string]json2.Any {
		return error('TypeError: Algorithm parameters must be an object')
	}
	return value as map[string]json2.Any
}

// EC parameter dictionaries read namedCurve with JS ToString, including
// omitted/undefined values; the actual curve check occurs in the operation.
fn algorithm_js_string(object map[string]json2.Any, key string) !string {
	value := object[key] or { return 'undefined' }
	return match value {
		string { value }
		i8, i16, i32, int, i64, u8, u16, u32, u64, f32, f64 {
			webidl.to_string(webidl.number_value(f64(value)))!
		}
		bool { webidl.to_string(webidl.boolean_value(value))! }
		json2.Null { 'null' }
		else {
			return error('TypeError: ${key} cannot be converted to a string by this value boundary')
		}
	}
}

// CryptoAlgorithms.cpp at 2919bf87a5e uses EnforceRange integer conversion.
// Keep the primitive-number boundary shared with the native browser binding.
// The json2 host boundary cannot execute an arbitrary object's ToPrimitive.
fn algorithm_primitive_number(object map[string]json2.Any, key string) !f64 {
    value := object[key] or { json2.Any(json2.Null{}) }
    return match value {
        i8, i16, i32, int, i64, u8, u16, u32, u64, f32, f64 { f64(value) }
        bool { if value { f64(1) } else { f64(0) } }
        string { libjs.string_to_number(libjs.utf16_string(value)) }
        json2.Null { f64(0) }
        else { return error('TypeError: ${key} cannot be converted to a number by this value boundary') }
    }
}

fn algorithm_enforce_uint(object map[string]json2.Any, key string, width int) !u32 {
    if key !in object { return error('TypeError: Number must not be NaN or Infinity') }
    number := algorithm_primitive_number(object, key)!
    return u32(webidl.convert_to_int(webidl.number_value(number), width, false, .yes, .no)!)
}

fn required_algorithm_enforce_uint(object map[string]json2.Any, key string, width int) !u32 {
    if key !in object { return error('TypeError: Required property ${key} is missing or undefined') }
    return algorithm_enforce_uint(object, key, width)
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
		error('TypeError: Not an object of type BufferSource')
	}
}

fn required_api_big_integer_bytes(object map[string]json2.Any, key string) ![]u8 {
    return optional_algorithm_bytes(object, key) or { error('TypeError: Not an object of type Uint8Array') }
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
    counter := required_algorithm_bytes(object, 'counter')!
    length := algorithm_enforce_uint(object, 'length', 8)!
    return AesCtrParams{ name: '', counter: counter, length: u8(length) }
}

pub fn AesGcmParams.from_value(value json2.Any) !AesGcmParams {
    object := algorithm_object(value)!
    iv := required_algorithm_bytes(object, 'iv')!
    mut additional_data := ?[]u8(none)
    if 'additionalData' in object { additional_data = required_algorithm_bytes(object, 'additionalData')! }
    mut tag_length := ?u8(none)
    if 'tagLength' in object { tag_length = u8(algorithm_enforce_uint(object, 'tagLength', 8)!) }
    return AesGcmParams{ name: '', iv: iv, additional_data: additional_data, tag_length: tag_length }
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
    salt := required_algorithm_bytes(object, 'salt')!
    iterations := algorithm_enforce_uint(object, 'iterations', 32)!
    hash := hash_algorithm_identifier_from_value(object['hash'] or { return error('TypeError: hash is required') })!
    return PBKDF2Params(Pbkdf2Params{ name: '', salt: salt, iterations: iterations, hash: hash.name()! })
}

pub fn AesKeyGenParams.from_value(value json2.Any) !AesKeyGenParams {
    object := algorithm_object(value)!
    return AesKeyGenParams{ name: '', length: u16(algorithm_enforce_uint(object, 'length', 16)!) }
}

pub fn AesDerivedKeyParams.from_value(value json2.Any) !AesDerivedKeyParams {
    object := algorithm_object(value)!
    return AesDerivedKeyParams{ name: '', length: u16(algorithm_enforce_uint(object, 'length', 16)!) }
}

pub fn RsaKeyGenParams.from_value(value json2.Any) !RsaKeyGenParams {
    object := algorithm_object(value)!
    modulus_length := algorithm_enforce_uint(object, 'modulusLength', 32)!
    public_exponent := big_integer_from_api_big_integer(required_api_big_integer_bytes(object, 'publicExponent')!)
    return RsaKeyGenParams{ name: '', modulus_length: modulus_length, public_exponent: public_exponent }
}

pub fn RsaHashedKeyGenParams.from_value(value json2.Any) !RsaHashedKeyGenParams {
    object := algorithm_object(value)!
    modulus_length := algorithm_enforce_uint(object, 'modulusLength', 32)!
    public_exponent := big_integer_from_api_big_integer(required_api_big_integer_bytes(object, 'publicExponent')!)
    hash := hash_algorithm_identifier_from_value(object['hash'] or { return error('TypeError: hash is required') })!
    return RsaHashedKeyGenParams{ name: '', modulus_length: modulus_length, public_exponent: public_exponent, hash: hash.name()! }
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
    mut label := []u8{}
    if label_value := object['label'] {
        if label_value !is json2.Null { label = required_algorithm_bytes(object, 'label')! }
    }
    return RsaOaepParams{ name: '', label: label }
}

pub fn RsaPssParams.from_value(value json2.Any) !RsaPssParams {
	object := algorithm_object(value)!
	return RsaPssParams{
		name: ''
		salt_length: algorithm_enforce_uint(object, 'saltLength', 32)!
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
		named_curve: algorithm_js_string(object, 'namedCurve')!
	}
}

pub fn EcKeyImportParams.from_value(value json2.Any) !EcKeyImportParams {
	object := algorithm_object(value)!
	return EcKeyImportParams{
		name: ''
		named_curve: algorithm_js_string(object, 'namedCurve')!
	}
}

pub fn HmacImportParams.from_value(value json2.Any) !HmacImportParams {
	object := algorithm_object(value)!
	hash := hash_algorithm_identifier_from_value(object['hash'] or {
		return error('TypeError: hash is required')
	})!
	mut length := ?u32(none)
	if 'length' in object {
		length = algorithm_enforce_uint(object, 'length', 32)!
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
		length = algorithm_enforce_uint(object, 'length', 32)!
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
    mut context := ?[]u8(none)
    if 'context' in object { context = required_algorithm_bytes(object, 'context')! }
    return Ed448Params{ name: '', context: context }
}

pub fn Argon2Params.from_value(value json2.Any) !Argon2Params {
    object := algorithm_object(value)!
    if 'nonce' !in object { return error('TypeError: Required property nonce is missing or undefined') }
    nonce := required_algorithm_bytes(object, 'nonce')!
    parallelism := required_algorithm_enforce_uint(object, 'parallelism', 32)!
    memory := required_algorithm_enforce_uint(object, 'memory', 32)!
    passes := required_algorithm_enforce_uint(object, 'passes', 32)!
    mut version := ?u8(none)
    if 'version' in object { version = u8(algorithm_enforce_uint(object, 'version', 8)!) }
    mut secret_value := ?[]u8(none)
    if 'secretValue' in object { secret_value = required_algorithm_bytes(object, 'secretValue')! }
    mut associated_data := ?[]u8(none)
    if 'associatedData' in object { associated_data = required_algorithm_bytes(object, 'associatedData')! }
    return Argon2Params{ name: '', nonce: nonce, parallelism: parallelism, memory: memory, passes: passes, version: version, secret_value: secret_value, associated_data: associated_data }
}

pub fn CShakeParams.from_value(value json2.Any) !CShakeParams {
    object := algorithm_object(value)!
    output_length := required_algorithm_enforce_uint(object, 'outputLength', 32)!
    mut function_name := ?[]u8(none)
    if 'functionName' in object { function_name = required_algorithm_bytes(object, 'functionName')! }
    mut customization := ?[]u8(none)
    if 'customization' in object { customization = required_algorithm_bytes(object, 'customization')! }
    return CShakeParams{ name: '', output_length: output_length, function_name: function_name, customization: customization }
}

pub fn KmacParams.from_value(value json2.Any) !KmacParams {
    object := algorithm_object(value)!
    output_length := required_algorithm_enforce_uint(object, 'outputLength', 32)!
    mut customization := ?[]u8(none)
    if 'customization' in object { customization = required_algorithm_bytes(object, 'customization')! }
    return KmacParams{ name: '', output_length: output_length, customization: customization }
}

pub fn KmacKeyGenParams.from_value(value json2.Any) !KmacKeyGenParams {
	object := algorithm_object(value)!
	mut length := ?u32(none)
	if 'length' in object {
		length = algorithm_enforce_uint(object, 'length', 32)!
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
		length = algorithm_enforce_uint(object, 'length', 32)!
	}
	return KmacImportParams{
		name: ''
		length: length
	}
}

pub fn AeadParams.from_value(value json2.Any) !AeadParams {
    object := algorithm_object(value)!
    iv := required_algorithm_bytes(object, 'iv')!
    mut additional_data := ?[]u8(none)
    if 'additionalData' in object { additional_data = required_algorithm_bytes(object, 'additionalData')! }
    mut tag_length := ?u8(none)
    if 'tagLength' in object { tag_length = u8(algorithm_enforce_uint(object, 'tagLength', 8)!) }
    return AeadParams{ name: '', iv: iv, additional_data: additional_data, tag_length: tag_length }
}

pub fn usage_intersection(first []KeyUsage, second []KeyUsage) []KeyUsage {
	mut result := []KeyUsage{}
	for usage in first {
		if usage in second && usage !in result {
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
