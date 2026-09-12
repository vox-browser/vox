module webcrypto

import webidl

fn test_crypto_key_algorithm_objects_have_upstream_shape_and_realm_identity() {
	mut key := CryptoKey.create(.public_key, true, RsaHashedKeyAlgorithm{
		name: 'RSA-PSS'
		modulus_length: 2048
		public_exponent: [u8(1), 0, 1]
		hash: 'SHA-256'
	}, [.verify], []u8{})
	first := key.algorithm('realm-a')!
	again := key.algorithm('realm-a')!
	other_realm := key.algorithm('realm-b')!
	assert first.kind == .object
	assert first.opaque_id != 0
	assert first.opaque_id == again.opaque_id
	assert first.opaque_id != other_realm.opaque_id
	assert first.object_value['name'].string_value == 'RSA-PSS'
	assert first.object_value['modulusLength'].number_value == 2048
	exponent := first.object_value['publicExponent']
	assert exponent.kind == .buffer_source
	assert exponent.buffer_value?.kind == .uint8_array
	assert webidl.get_buffer_source_copy(exponent.buffer_value?) == [u8(1), 0, 1]
	assert first.object_value['hash'].object_value['name'].string_value == 'SHA-256'

	key.set_algorithm(EcKeyAlgorithm{
		name: 'ECDSA'
		named_curve: 'P-384'
	})
	updated := key.algorithm('realm-a')!
	assert updated.opaque_id != first.opaque_id
	assert updated.object_value['name'].string_value == 'ECDSA'
	assert updated.object_value['namedCurve'].string_value == 'P-384'
}

fn test_crypto_key_usages_objects_are_frozen_and_cached_by_realm() {
	mut key := CryptoKey.create(.secret, true, AesKeyAlgorithm{
		name: 'AES-GCM'
		length: 128
	}, [.decrypt, .encrypt, .decrypt], []u8{len: 16})
	first := key.usages('realm-a')
	again := key.usages('realm-a')
	other_realm := key.usages('realm-b')
	assert first.kind == .sequence
	assert first.frozen
	assert first.opaque_id == again.opaque_id
	assert first.opaque_id != other_realm.opaque_id
	assert first.sequence_value.map(it.string_value) == ['decrypt', 'encrypt', 'decrypt']

	count_before_destroy := crypto_key_caches().len
	key.destroy()
	assert crypto_key_caches().len == count_before_destroy - 1
}

fn test_crypto_key_algorithm_data_aliases_expose_internal_record_accessors() {
	rsa := RsaKeyAlgorithmData(RsaKeyAlgorithm{
		name: 'RSA-OAEP'
		modulus_length: 3072
		public_exponent: [u8(3)]
	})
	assert rsa.name() == 'RSA-OAEP'
	assert rsa.modulus_length() == 3072
	assert rsa.public_exponent() == [u8(3)]
	hmac := HmacKeyAlgorithmData(HmacKeyAlgorithm{
		name: 'HMAC'
		hash: 'SHA-512'
		length: 512
	})
	assert hmac.name() == 'HMAC'
	assert hmac.hash() == 'SHA-512'
	assert hmac.length() == 512
}

fn test_crypto_key_algorithm_objects_cover_every_internal_record_shape() {
	plain := create_algorithm_object('shape-realm', KeyAlgorithm{ name: 'Ed25519' })!
	assert plain.object_value.keys() == ['name']

	mut exponent_source := [u8(1), 0, 1]
	rsa := create_algorithm_object('shape-realm', RsaKeyAlgorithm{
		name: 'RSA-OAEP'
		modulus_length: 4096
		public_exponent: exponent_source
	})!
	exponent_source[0] = 9
	assert rsa.object_value['modulusLength'].number_value == 4096
	assert webidl.get_buffer_source_copy(rsa.object_value['publicExponent'].buffer_value?) == [
		u8(1),
		0,
		1,
	]

	aes := create_algorithm_object('shape-realm', AesKeyAlgorithm{
		name: 'AES-CTR'
		length: 256
	})!
	assert aes.object_value['length'].number_value == 256
	hmac := create_algorithm_object('shape-realm', HmacKeyAlgorithm{
		name: 'HMAC'
		hash: 'SHA-384'
		length: 384
	})!
	assert hmac.object_value['hash'].object_value['name'].string_value == 'SHA-384'
	assert hmac.object_value['length'].number_value == 384
	kmac := create_algorithm_object('shape-realm', KmacKeyAlgorithm{
		name: 'KMAC128'
		length: 128
	})!
	assert kmac.object_value['length'].number_value == 128
}

fn test_crypto_key_deserialization_discards_cached_binding_objects() {
	mut key := CryptoKey.create(.secret, true, AesKeyAlgorithm{
		name: 'AES-GCM'
		length: 128
	}, [.encrypt], [u8(1)])
	old_algorithm := key.algorithm('deserialize-realm')!
	old_usages := key.usages('deserialize-realm')
	replacement := CryptoKey.create(.secret, false, HmacKeyAlgorithm{
		name: 'HMAC'
		hash: 'SHA-256'
		length: 256
	}, [.sign], [u8(2)]).serialize()
	key.deserialization_steps(replacement)!
	assert key.algorithm('deserialize-realm')!.opaque_id != old_algorithm.opaque_id
	assert key.usages('deserialize-realm').opaque_id != old_usages.opaque_id
}
