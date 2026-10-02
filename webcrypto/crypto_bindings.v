// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Crypto/CryptoBindings.{h,cpp} and the WebCrypto IDL enums.
@[has_globals]
module webcrypto

import encoding.base64
import encoding.utf8
import webidl
import x.json2

pub enum KeyType {
	public_key
	private_key
	secret
}

pub enum KeyUsage {
	encrypt
	decrypt
	sign
	verify
	derive_key
	derive_bits
	wrap_key
	unwrap_key
	encapsulate_key
	encapsulate_bits
	decapsulate_key
	decapsulate_bits
}

pub enum KeyFormat {
	raw_public
	raw_private
	raw_seed
	raw_secret
	raw
	spki
	pkcs8
	jwk
}

pub struct RsaOtherPrimesInfo {
pub:
	r ?string
	d ?string
	t ?string
}

pub struct JsonWebKey {
pub mut:
	kty     ?string
	use     ?string
	key_ops ?[]string
	alg     ?string
	ext     ?bool
	crv     ?string
	x       ?string
	y       ?string
	d       ?string
	n       ?string
	e       ?string
	p       ?string
	q       ?string
	dp      ?string
	dq      ?string
	qi      ?string
	oth     ?[]RsaOtherPrimesInfo
	k       ?string
	pub_    ?string
	priv    ?string
}

fn json_web_key_string_property(object map[string]json2.Any, name string) ?string {
	value := object[name] or { return none }
	if value is string {
		return value
	}
	return none
}

fn json_web_key_boolean_property(object map[string]json2.Any, name string) ?bool {
	value := object[name] or { return none }
	if value is bool {
		return value
	}
	return none
}

fn parse_json_web_key_string_array(value json2.Any, name string) ![]string {
	if value !is []json2.Any {
		return []string{}
	}
	values := value as []json2.Any
	mut result := []string{cap: values.len}
	for item in values {
		if item !is string {
			return error('TypeError: ${name} must contain only strings')
		}
		result << item as string
	}
	return result
}

fn parse_rsa_other_primes_info(value json2.Any) !RsaOtherPrimesInfo {
	if value !is map[string]json2.Any {
		return error('TypeError: oth must contain only objects')
	}
	object := value as map[string]json2.Any
	return RsaOtherPrimesInfo{
		r: json_web_key_string_property(object, 'r')
		d: json_web_key_string_property(object, 'd')
		t: json_web_key_string_property(object, 't')
	}
}

fn parse_json_web_key_other_primes(value json2.Any) ![]RsaOtherPrimesInfo {
	if value !is []json2.Any {
		return []RsaOtherPrimesInfo{}
	}
	values := value as []json2.Any
	mut result := []RsaOtherPrimesInfo{cap: values.len}
	for item in values {
		result << parse_rsa_other_primes_info(item)!
	}
	return result
}

// CryptoBindings.cpp's JSON-to-WebIDL-dictionary conversion. Properties with
// the wrong scalar type are treated as absent, matching JsonObject::get_*;
// sequence elements are converted strictly.
pub fn JsonWebKey.parse(data []u8) !JsonWebKey {
	key := decode_json_web_key_dictionary(data)!
	if key.kty == none { return error('DataError: kty field is not defined') }
	return key
}

// AlgorithmMethods importKey receives a JsonWebKey dictionary, including absent
// optional members. JSON here transports that already-converted typed DTO;
// CryptoBindings::parse_json_web_key is the separate unwrap JSON algorithm.
fn decode_json_web_key_dictionary(data []u8) !JsonWebKey {
	if data.len > 0 && !utf8.validate(data.data, data.len) {
		return error('SyntaxError: JSON is not valid UTF-8')
	}
	value := json2.decode[json2.Any](data.bytestr()) or {
		return error('SyntaxError: Malformed JSON')
	}
	if value !is map[string]json2.Any {
		return error('SyntaxError: JSON value is not an object')
	}
	object := value as map[string]json2.Any
	mut key := JsonWebKey{
		kty:  json_web_key_string_property(object, 'kty')
		use:  json_web_key_string_property(object, 'use')
		alg:  json_web_key_string_property(object, 'alg')
		ext:  json_web_key_boolean_property(object, 'ext')
		crv:  json_web_key_string_property(object, 'crv')
		x:    json_web_key_string_property(object, 'x')
		y:    json_web_key_string_property(object, 'y')
		d:    json_web_key_string_property(object, 'd')
		n:    json_web_key_string_property(object, 'n')
		e:    json_web_key_string_property(object, 'e')
		p:    json_web_key_string_property(object, 'p')
		q:    json_web_key_string_property(object, 'q')
		dp:   json_web_key_string_property(object, 'dp')
		dq:   json_web_key_string_property(object, 'dq')
		qi:   json_web_key_string_property(object, 'qi')
		k:    json_web_key_string_property(object, 'k')
		pub_: json_web_key_string_property(object, 'pub')
		priv: json_web_key_string_property(object, 'priv')
	}
	if operations := object['key_ops'] {
		if operations is []json2.Any {
			key.key_ops = parse_json_web_key_string_array(operations, 'key_ops')!
		}
	}
	if other_primes := object['oth'] {
		if other_primes is []json2.Any {
			key.oth = parse_json_web_key_other_primes(other_primes)!
		}
	}
	return key
}

pub fn parse_json_web_key(data []u8) !JsonWebKey {
	return JsonWebKey.parse(data)
}

@[heap]
pub struct CryptoKeyBinding {
pub:
	realm string
	key   &CryptoKey
}

__global crypto_key_bindings_ = map[u64]&CryptoKeyBinding{}
__global crypto_key_binding_ids_ = map[string]u64{}

fn crypto_key_binding_key(realm string, key &CryptoKey) string {
	return '${realm}:${u64(voidptr(key))}'
}

pub fn crypto_key(realm string, key &CryptoKey) webidl.Value {
	cache_key := crypto_key_binding_key(realm, key)
	if binding_id := crypto_key_binding_ids_[cache_key] {
		return webidl.platform_object_value_with_id(binding_id)
	}
	binding := &CryptoKeyBinding{
		realm: realm
		key: key
	}
	binding_id := u64(voidptr(binding))
	crypto_key_bindings_[binding_id] = binding
	crypto_key_binding_ids_[cache_key] = binding_id
	return webidl.platform_object_value_with_id(binding_id)
}

pub fn crypto_key_from_value(value webidl.Value) !&CryptoKey {
	if value.kind != .platform_object || value.opaque_id == 0 {
		return error('TypeError: Value is not an object of type CryptoKey')
	}
	binding := crypto_key_bindings_[value.opaque_id] or {
		return error('TypeError: Value is not an object of type CryptoKey')
	}
	return binding.key
}

pub fn resolve_crypto_key_promise(realm string, mut promise webidl.Promise, key &CryptoKey) {
	promise.resolve(crypto_key(realm, key))
}

pub fn encapsulated_bits(_ string, bits EncapsulatedBits) map[string]webidl.Value {
	mut object := map[string]webidl.Value{}
	if shared_key := bits.shared_key {
		object['sharedKey'] = webidl.buffer_source_value(webidl.BufferSource.array_buffer(shared_key))
	}
	if ciphertext := bits.ciphertext {
		object['ciphertext'] = webidl.buffer_source_value(webidl.BufferSource.array_buffer(ciphertext))
	}
	return object
}

pub fn encapsulated_key(realm string, key EncapsulatedKey) map[string]webidl.Value {
	mut object := map[string]webidl.Value{}
	if shared_key := key.shared_key {
		object['sharedKey'] = crypto_key(realm, shared_key)
	}
	if ciphertext := key.ciphertext {
		object['ciphertext'] = webidl.buffer_source_value(webidl.BufferSource.array_buffer(ciphertext))
	}
	return object
}

pub fn crypto_key_pair(realm string, pair &CryptoKeyPair) map[string]webidl.Value {
	return {
		'publicKey':  crypto_key(realm, pair.public_key)
		'privateKey': crypto_key(realm, pair.private_key)
	}
}

fn put_optional_json_web_key_string(mut object map[string]json2.Any, name string, value ?string) {
	if actual := value {
		object[name] = actual
	}
}

fn rsa_other_primes_info_to_object(info RsaOtherPrimesInfo) map[string]json2.Any {
	mut object := map[string]json2.Any{}
	put_optional_json_web_key_string(mut object, 'd', info.d)
	put_optional_json_web_key_string(mut object, 'r', info.r)
	put_optional_json_web_key_string(mut object, 't', info.t)
	return object
}

// SubtleCrypto.idl GenerateToValue conversion: the pinned IDL parser sorts
// dictionary members lexicographically before creating their data properties.
pub fn (key JsonWebKey) to_object() map[string]json2.Any {
	mut object := map[string]json2.Any{}
	put_optional_json_web_key_string(mut object, 'alg', key.alg)
	put_optional_json_web_key_string(mut object, 'crv', key.crv)
	put_optional_json_web_key_string(mut object, 'd', key.d)
	put_optional_json_web_key_string(mut object, 'dp', key.dp)
	put_optional_json_web_key_string(mut object, 'dq', key.dq)
	put_optional_json_web_key_string(mut object, 'e', key.e)
	if extractable := key.ext {
		object['ext'] = extractable
	}
	put_optional_json_web_key_string(mut object, 'k', key.k)
	if operations := key.key_ops {
		mut values := []json2.Any{cap: operations.len}
		for operation in operations { values << operation }
		object['key_ops'] = values
	}
	put_optional_json_web_key_string(mut object, 'kty', key.kty)
	put_optional_json_web_key_string(mut object, 'n', key.n)
	if other_primes := key.oth {
		mut values := []json2.Any{cap: other_primes.len}
		for info in other_primes { values << rsa_other_primes_info_to_object(info) }
		object['oth'] = values
	}
	put_optional_json_web_key_string(mut object, 'p', key.p)
	put_optional_json_web_key_string(mut object, 'priv', key.priv)
	put_optional_json_web_key_string(mut object, 'pub', key.pub_)
	put_optional_json_web_key_string(mut object, 'q', key.q)
	put_optional_json_web_key_string(mut object, 'qi', key.qi)
	put_optional_json_web_key_string(mut object, 'use', key.use)
	put_optional_json_web_key_string(mut object, 'x', key.x)
	put_optional_json_web_key_string(mut object, 'y', key.y)
	return object
}

pub fn (key JsonWebKey) to_json() string {
	return json2.encode(key.to_object())
}

pub fn base64url_encode(bytes []u8) string {
	return base64.url_encode(bytes).trim_right('=')
}

pub fn base64url_decode(value string) ![]u8 {
	for character in value.bytes() {
		is_base64url_character := (character >= `A` && character <= `Z`)
			|| (character >= `a` && character <= `z`)
			|| (character >= `0` && character <= `9`) || character == `-`
			|| character == `_`
		if !is_base64url_character {
			return error('DataError: Invalid base64url data')
		}
	}
	if value.len % 4 == 1 {
		return error('DataError: Invalid base64url data')
	}
	return base64.url_decode(value)
}

pub fn key_type_string(type_ KeyType) string {
	return match type_ {
		.public_key { 'public' }
		.private_key { 'private' }
		.secret { 'secret' }
	}
}

pub fn parse_key_type(value string) !KeyType {
	return match value {
		'public' { .public_key }
		'private' { .private_key }
		'secret' { .secret }
		else { error('TypeError: Unknown key type: ${value}') }
	}
}

pub fn key_format_string(format KeyFormat) string {
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

pub fn parse_key_format(value string) !KeyFormat {
	return match value {
		'raw-public' { .raw_public }
		'raw-private' { .raw_private }
		'raw-seed' { .raw_seed }
		'raw-secret' { .raw_secret }
		'raw' { .raw }
		'spki' { .spki }
		'pkcs8' { .pkcs8 }
		'jwk' { .jwk }
		else { error('TypeError: Unknown key format: ${value}') }
	}
}

pub fn key_usage_string(usage KeyUsage) string {
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

pub fn parse_key_usage(value string) !KeyUsage {
	return match value {
		'encrypt' { .encrypt }
		'decrypt' { .decrypt }
		'sign' { .sign }
		'verify' { .verify }
		'deriveKey' { .derive_key }
		'deriveBits' { .derive_bits }
		'wrapKey' { .wrap_key }
		'unwrapKey' { .unwrap_key }
		'encapsulateKey' { .encapsulate_key }
		'encapsulateBits' { .encapsulate_bits }
		'decapsulateKey' { .decapsulate_key }
		'decapsulateBits' { .decapsulate_bits }
		else { error('TypeError: Unknown key usage: ${value}') }
	}
}
