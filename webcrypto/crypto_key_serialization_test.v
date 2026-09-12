module webcrypto

fn test_crypto_key_internal_handle_serialization_round_trips_every_stable_tag() {
	assert crypto_key_handle_tag_expectations.len == 11
	handles := [
		CryptoKeyInternalHandle(ByteBufferKeyHandle{ bytes: [u8(1), 2, 3] }),
		CryptoKeyInternalHandle(RsaPublicKeyHandle{
			modulus: [u8(0), 0x80, 1]
			public_exponent: [u8(1), 0, 1]
		}),
		CryptoKeyInternalHandle(RsaPrivateKeyHandle{
			modulus: [u8(0xaa), 0xbb]
			private_exponent: [u8(0xcc)]
			public_exponent: [u8(1), 0, 1]
			prime1: [u8(2)]
			prime2: [u8(3)]
			exponent1: [u8(4)]
			exponent2: [u8(5)]
			coefficient: [u8(6)]
		}),
		CryptoKeyInternalHandle(EcPublicKeyHandle{
			x: [u8(7), 8]
			y: [u8(9), 10]
		}),
		CryptoKeyInternalHandle(EcPrivateKeyHandle{
			d: [u8(11), 12]
			parameters: [17, -4]
			public_key: EcPublicKeyHandle{
				x: [u8(13)]
				y: [u8(14)]
			}
		}),
		CryptoKeyInternalHandle(MldsaPublicKeyHandle{ public_key: [u8(15), 16] }),
		CryptoKeyInternalHandle(MldsaPrivateKeyHandle{
			seed: [u8(17)]
			public_key: [u8(18)]
			private_key: [u8(19)]
		}),
		CryptoKeyInternalHandle(MlkemPublicKeyHandle{ public_key: [u8(20), 21] }),
		CryptoKeyInternalHandle(MlkemPrivateKeyHandle{
			seed: [u8(22)]
			public_key: [u8(23)]
			private_key: [u8(24)]
		}),
		CryptoKeyInternalHandle(OkpPublicKeyHandle{ bytes: [u8(25), 26] }),
		CryptoKeyInternalHandle(OkpPrivateKeyHandle{ bytes: [u8(27), 28] }),
	]
	for index, handle in handles {
		encoded := serialize_handle(handle)
		assert encoded[0] == u8(index)
		decoded := deserialize_handle(encoded)!
		assert serialize_handle(decoded) == encoded
	}
}

fn test_crypto_key_algorithm_serialization_round_trips_every_stable_tag() {
	assert crypto_key_algorithm_tag_expectations.len == 7
	assert crypto_key_algorithm_tag_expectations[1].expectation == .documented_reject
	algorithms := [
		CryptoKeyAlgorithm(KeyAlgorithm{ name: 'Ed25519' }),
		CryptoKeyAlgorithm(RsaKeyAlgorithm{
			name: 'RSA-OAEP'
			modulus_length: 2048
			public_exponent: [u8(1), 0, 1]
		}),
		CryptoKeyAlgorithm(RsaHashedKeyAlgorithm{
			name: 'RSA-PSS'
			modulus_length: 4096
			public_exponent: [u8(3)]
			hash: 'SHA-512'
		}),
		CryptoKeyAlgorithm(EcKeyAlgorithm{
			name: 'ECDSA'
			named_curve: 'P-384'
		}),
		CryptoKeyAlgorithm(AesKeyAlgorithm{
			name: 'AES-GCM'
			length: 256
		}),
		CryptoKeyAlgorithm(HmacKeyAlgorithm{
			name: 'HMAC'
			hash: 'SHA-384'
			length: 384
		}),
		CryptoKeyAlgorithm(KmacKeyAlgorithm{
			name: 'KMAC256'
			length: 512
		}),
	]
	for index, algorithm in algorithms {
		encoded := serialize_algorithm(algorithm)
		assert encoded[0] == u8(index)
		decoded := deserialize_algorithm(encoded)!
		assert serialize_algorithm(decoded) == encoded
	}
}

fn test_crypto_key_serialization_tag_tables_reject_unlisted_values() {
	for value in 0 .. 256 {
		handle_tag := unsafe { CryptoKeyHandleTag(u8(value)) }
		assert handle_tag_is_in_table(handle_tag) == (value < 11)
		algorithm_tag := unsafe { CryptoKeyAlgorithmTag(u8(value)) }
		assert key_algorithm_tag_is_in_table(algorithm_tag) == (value < 7)
	}
}

fn test_crypto_key_serialization_rejects_invalid_or_truncated_data() {
	deserialize_handle([u8(0xff)]) or {
		assert err.msg().contains('Invalid CryptoKey handle tag')
		return
	}
	assert false
}

fn test_crypto_key_serialization_rejects_trailing_handle_data() {
	mut encoded := serialize_handle(ByteBufferKeyHandle{ bytes: [u8(1)] })
	encoded << u8(2)
	deserialize_handle(encoded) or {
		assert err.msg().contains('Trailing bytes')
		return
	}
	assert false
}

fn test_crypto_key_serialization_rejects_truncated_algorithm_data() {
	deserialize_algorithm([u8(CryptoKeyAlgorithmTag.key_algorithm), 0, 0, 0]) or {
		assert err.msg().contains('Truncated')
		return
	}
	assert false
}

fn test_crypto_key_structured_serialization_preserves_typed_handle() {
	handle := CryptoKeyInternalHandle(OkpPrivateKeyHandle{ bytes: [u8(31), 32, 33] })
	key := CryptoKey.create_with_internal_handle(.private_key, false, KeyAlgorithm{
		name: 'Ed25519'
	}, [.sign], handle)
	serialized := key.serialize()
	restored := CryptoKey.deserialize(serialized)!
	assert restored.handle() == [u8(31), 32, 33]
	assert serialize_handle(restored.internal_handle()) == serialize_handle(handle)
	assert restored.clone_key().handle() == restored.handle()
}

fn test_crypto_key_destroy_securely_zeros_typed_handle_storage() {
	mut key := CryptoKey.create_with_internal_handle(.private_key, false, KeyAlgorithm{
		name: 'Ed25519'
	}, [.sign], OkpPrivateKeyHandle{ bytes: [u8(41), 42, 43] })
	aliased_handle := key.internal_handle()
	key.destroy()
	assert key.destroyed()
	assert key.handle().len == 0
	assert key.internal_handle() is ByteBufferKeyHandle
	if aliased_handle is OkpPrivateKeyHandle {
		assert aliased_handle.bytes == [u8(0), 0, 0]
	} else {
		assert false
	}
}
