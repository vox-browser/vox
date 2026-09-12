module webcrypto

import webidl

fn test_parse_json_web_key_binding_entry_point() {
	key := parse_json_web_key('{"kty":"oct","k":"AQI","key_ops":["encrypt"]}'.bytes())!
	assert key.kty? == 'oct'
	assert key.k? == 'AQI'
	assert key.key_ops? == ['encrypt']
	if _ := parse_json_web_key('[]'.bytes()) {
		assert false
	} else {
		assert err.msg().starts_with('SyntaxError:')
	}
}

fn test_crypto_key_bindings_keep_realm_identity_and_unwrap_keys() {
	key := CryptoKey.create(.secret, true, KeyAlgorithm{ name: 'AES-GCM' }, [.encrypt], []u8{len: 16})
	first := crypto_key('crypto-realm-a', key)
	again := crypto_key('crypto-realm-a', key)
	other_realm := crypto_key('crypto-realm-b', key)
	assert first.opaque_id == again.opaque_id
	assert first.opaque_id != other_realm.opaque_id
	assert voidptr(crypto_key_from_value(first)!) == voidptr(key)
	if _ := crypto_key_from_value(webidl.platform_object_value()) {
		assert false
	} else {
		assert err.msg().contains('CryptoKey')
	}
}

fn test_crypto_binding_result_objects_and_promise_resolution() {
	public_key := CryptoKey.create(.public_key, true, KeyAlgorithm{ name: 'ML-KEM-768' }, [
		.encapsulate_key,
	], [u8(1)])
	private_key := CryptoKey.create(.private_key, false, KeyAlgorithm{ name: 'ML-KEM-768' }, [
		.decapsulate_key,
	], [u8(2)])
	pair := CryptoKeyPair.create(public_key, private_key)
	pair_object := crypto_key_pair('crypto-pair-realm', pair)
	assert voidptr(crypto_key_from_value(pair_object['publicKey'])!) == voidptr(public_key)
	assert voidptr(crypto_key_from_value(pair_object['privateKey'])!) == voidptr(private_key)

	bits_object := encapsulated_bits('crypto-result-realm', EncapsulatedBits{
		shared_key: [u8(3), 4]
		ciphertext: [u8(5), 6]
	})
	assert webidl.get_buffer_source_copy(bits_object['sharedKey'].buffer_value?) == [
		u8(3),
		4,
	]
	assert webidl.get_buffer_source_copy(bits_object['ciphertext'].buffer_value?) == [
		u8(5),
		6,
	]
	key_object := encapsulated_key('crypto-result-realm', EncapsulatedKey{
		shared_key: public_key
		ciphertext: [u8(7), 8]
	})
	assert voidptr(crypto_key_from_value(key_object['sharedKey'])!) == voidptr(public_key)
	assert webidl.get_buffer_source_copy(key_object['ciphertext'].buffer_value?) == [
		u8(7),
		8,
	]

	mut promise := webidl.create_promise()
	resolve_crypto_key_promise('crypto-promise-realm', mut promise, public_key)
	assert promise.is_fulfilled()
	assert voidptr(crypto_key_from_value(promise.result)!) == voidptr(public_key)
}
