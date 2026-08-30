module webcrypto

import x.json2

fn test_upstream_parameter_normalization_and_binary_helpers() {
	params := AesCtrParams.from_value(json2.Any({
		'name':    json2.Any('AES-CTR')
		'counter': json2.Any('0123456789abcdef')
		'length':  json2.Any(i64(128))
	}))!
	assert params.name == 'AES-CTR'
	assert params.counter == '0123456789abcdef'.bytes()
	assert params.length == 128

	hkdf := HKDFParams.from_value(json2.Any({
		'hash': json2.Any('SHA-256')
		'salt': json2.Any('salt')
		'info': json2.Any('info')
	}))!
	hkdf_value := HkdfParams(hkdf)
	assert hkdf_value.name == 'HKDF'
	assert hkdf_value.hash == 'SHA-256'

	encoded := base64_url_uint_encode([u8(0), 0, 1, 2, 3])
	assert base64_url_uint_decode(encoded)! == [u8(1), 2, 3]
	structure := parse_an_asn1_structure([u8(0x30), 3, 1, 2, 3])!
	assert structure.tag == 0x30
	assert structure.contents == [u8(1), 2, 3]
	assert parse_a_subject_public_key_info([u8(0x30), 0])!.contents.len == 0
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
		assert err.msg().contains('AES-OCB encryption backend is unavailable')
	}
}

fn test_upstream_key_pair_and_registry_entry_points() {
	public_key := CryptoKey.create(.public_key, true, KeyAlgorithm{name: 'public'}, [], [])
	private_key := CryptoKey.create(.private_key, false, KeyAlgorithm{name: 'private'}, [], [])
	pair := CryptoKeyPair.create(public_key, private_key)
	assert pair.public_key() == public_key
	assert pair.private_key() == private_key
	assert usage_intersection([KeyUsage.sign, .verify], [.verify]) == [.verify]
	mut registry := supported_algorithms()
	define_an_algorithm(mut registry, 'digest', 'TEST-HASH')
	assert 'TEST-HASH' in registry['digest']
}
