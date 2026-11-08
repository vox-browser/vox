module webcrypto

import webidl
import x.json2

fn test_upstream_parameter_normalization_and_binary_helpers() {
	params := AesCtrParams.from_value(json2.Any({
		'name':    json2.Any('AES-CTR')
		'counter': json2.Any('0123456789abcdef')
		'length':  json2.Any(i64(128))
	}))!
	// Upstream initializes the normalized name after parameter conversion.
	assert params.name == ''
	assert params.counter == '0123456789abcdef'.bytes()
	assert params.length == 128

	hkdf := HKDFParams.from_value(json2.Any({
		'hash': json2.Any('SHA-256')
		'salt': json2.Any('salt')
		'info': json2.Any('info')
	}))!
	hkdf_value := HkdfParams{...hkdf}
	assert hkdf_value.name == ''
	assert hkdf_value.hash == 'SHA-256'
	hash_from_object := hash_algorithm_identifier_from_value(json2.Any({
		'name': json2.Any('sha-384')
	}))!
	assert hash_from_object.name()! == 'SHA-384'
	assert AlgorithmParams.from_value(json2.Any(i64(42)))!.name == ''

	gcm := AesGcmParams.from_value(json2.Any({
		'iv': json2.Any('0123456789ab')
	}))!
	assert gcm.name == ''
	assert gcm.additional_data == none
	assert gcm.tag_length == none
	argon := Argon2Params.from_value(json2.Any({
		'nonce':       json2.Any('nonce-value')
		'parallelism': json2.Any(i64(1))
		'memory':      json2.Any(i64(1024))
		'passes':      json2.Any(i64(2))
		'secretValue': json2.Any('secret')
	}))!
	assert argon.name == ''
	assert argon.version == none
	assert argon.secret_value or { []u8{} } == 'secret'.bytes()
	assert argon.associated_data == none

	encoded := base64_url_uint_encode([u8(0), 0, 1, 2, 3])
	assert base64_url_uint_decode(encoded)! == [u8(1), 2, 3]
	assert base64_url_uint_encode([]) == 'AA'
	assert base64_url_uint_encode([u8(0), 0]) == 'AA'
	assert base64_url_uint_decode('AA')! == [u8(0)]
	structure := parse_an_asn1_structure([u8(0x30), 3, 1, 2, 3])!
	assert structure.tag == 0x30
	assert structure.contents == [u8(1), 2, 3]
	assert parse_a_subject_public_key_info([u8(0x30), 0])!.contents.len == 0
	public_key := parse_jwk_rsa_public_key(JsonWebKey{
		n: base64_url_uint_encode([u8(1), 2, 3])
		e: base64_url_uint_encode([u8(1), 0, 1])
	})!
	assert public_key.modulus == [u8(1), 2, 3]
	assert public_key.public_exponent == [u8(1), 0, 1]
	private_key := parse_jwk_rsa_private_key(JsonWebKey{
		n: base64_url_uint_encode([u8(1), 2, 3])
		e: base64_url_uint_encode([u8(1), 0, 1])
		d: base64_url_uint_encode([u8(4), 5, 6])
	})!
	assert private_key.modulus == [u8(1), 2, 3]
	assert private_key.public_exponent == [u8(1), 0, 1]
	assert private_key.private_exponent == [u8(4), 5, 6]
}

fn test_upstream_aes_algorithm_class_delegates_to_translated_primitive() {
	algorithm := AesCtr.create()
	key := algorithm.import_key(.raw, [u8(0), 1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
		11, 12, 13, 14, 15], false, [.encrypt, .decrypt])!
	params := AesCtrParams{
		counter: []u8{len: 16}
		length:  128
	}
	plaintext := 'upstream dispatch'.bytes()
	ciphertext := algorithm.encrypt(params, key, plaintext)!
	assert ciphertext != plaintext
	assert algorithm.decrypt(params, key, ciphertext)! == plaintext
	length := algorithm.get_key_length(AesKeyGenParams{length: 128})!
	actual_length := length.value or { panic('AES key length is missing') }
	assert actual_length == u32(128)
}

fn test_upstream_base_dispatch_nullable_lengths_and_backend_boundaries() {
	key := CryptoKey.create(.secret, false, KeyAlgorithm{name: 'test'}, [], [u8(1)])
	base := AlgorithmMethods.create()
	base.encrypt(AlgorithmParams{}, key, []) or {
		assert err.msg() == 'NotSupportedError: encrypt is not supported'
	}
	assert HKDF.create().get_key_length(AlgorithmParams{})!.value == none
	assert PBKDF2.create().get_key_length(AlgorithmParams{})!.value == none
	chacha_length := ChaCha20Poly1305.create().get_key_length(AlgorithmParams{})!.value or {
		panic('ChaCha20-Poly1305 key length is missing')
	}
	assert chacha_length == u32(256)
	AesOcb.create().encrypt(AeadParams{}, key, []) or {
		assert err.msg() == 'OperationError: Encryption failed: No AES-OCB cipher for this key size'
	}
}

fn test_upstream_key_pair_and_registry_entry_points() {
	public_key := CryptoKey.create(.public_key, true, KeyAlgorithm{name: 'public'}, [], [])
	private_key := CryptoKey.create(.private_key, false, KeyAlgorithm{name: 'private'}, [], [])
	pair := CryptoKeyPair.create(public_key, private_key)
	assert pair.public_key() == public_key
	assert pair.private_key() == private_key
	assert usage_intersection([KeyUsage.verify, .sign, .verify], [.verify, .sign]) == [
		KeyUsage.sign,
		.verify,
	]
	mut registry := supported_algorithms()
	define_an_algorithm(mut registry, 'digest', 'TEST-HASH')
	assert 'TEST-HASH' in registry['digest']
	assert EncapsulatedBits{}.to_object().len == 0
	bits_object := EncapsulatedBits{
		shared_key: [u8(1), 2]
	}.to_object()
	assert 'sharedKey' in bits_object
	assert 'ciphertext' !in bits_object
}

fn test_crypto_algorithm_binding_helpers_preserve_webcrypto_spellings() {
	assert export_public_exponent([u8(0), 0, 1, 0, 1]) == [u8(1), 0, 1]
	assert export_public_exponent([]) == [u8(0)]
	assert base64_url_bytes_encode([u8(0), 0, 1]) == 'AAAB'
	assert base64_url_bytes_encode([]) == ''

	usages := [KeyUsage.encrypt, .decrypt, .sign, .verify, .derive_key, .derive_bits, .wrap_key,
		.unwrap_key, .encapsulate_key, .encapsulate_bits, .decapsulate_key, .decapsulate_bits]
	usage_names := ['encrypt', 'decrypt', 'sign', 'verify', 'deriveKey', 'deriveBits', 'wrapKey',
		'unwrapKey', 'encapsulateKey', 'encapsulateBits', 'decapsulateKey', 'decapsulateBits']
	for index, usage in usages {
		assert key_usage_to_string(usage) == usage_names[index]
	}
	formats := [KeyFormat.raw_public, .raw_private, .raw_seed, .raw_secret, .raw, .spki, .pkcs8,
		.jwk]
	format_names := ['raw-public', 'raw-private', 'raw-seed', 'raw-secret', 'raw', 'spki', 'pkcs8',
		'jwk']
	for index, format in formats {
		assert key_format_to_string(format) == format_names[index]
	}

	assert kmac_kind_from_algorithm_name('KMAC128')? == .kmac128
	assert kmac_kind_from_algorithm_name('KMAC256')? == .kmac256
	assert kmac_kind_from_algorithm_name('kmac128') == none
}

fn test_subtle_crypto_export_and_dictionary_binding_helpers() {
	raw := ExportKeyResult([u8(1), 2, 3])
	raw_value := export_key_result_to_js_value('subtle-binding-realm', raw)!
	assert raw_value.kind == .buffer_source
	assert webidl.get_buffer_source_copy(raw_value.buffer_value?) == [u8(1), 2, 3]
	assert export_key_result_to_bytes(raw)! == [u8(1), 2, 3]

	jwk := JsonWebKey{
		kty: 'oct'
		k: 'AQID'
		ext: true
		key_ops: ['encrypt']
	}
	jwk_result := ExportKeyResult(jwk)
	jwk_value := export_key_result_to_js_value('subtle-binding-realm', jwk_result)!
	assert jwk_value.kind == .object
	assert jwk_value.object_value['kty'].string_value == 'oct'
	assert jwk_value.object_value['ext'].boolean_value
	assert jwk_value.object_value['key_ops'].sequence_value[0].string_value == 'encrypt'
	assert export_key_result_to_bytes(jwk_result)!.bytestr().contains('"kty":"oct"')

	dictionary := create_algorithm_dictionary('SHA-256')
	assert dictionary.kind == .object
	assert dictionary.object_value['name'].string_value == 'SHA-256'
	for format in [KeyFormat.raw, .raw_public, .raw_private, .raw_seed, .raw_secret, .pkcs8, .spki] {
		assert key_format_expects_buffer_source(format)
	}
	assert !key_format_expects_buffer_source(.jwk)
}
