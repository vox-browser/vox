module html

import libjs
import webcrypto

fn crypto_codec_context() StructuredDeserializationContext {
	return StructuredDeserializationContext{
		is_exposed: fn (interface_name StructuredSerializableInterface) bool {
			return interface_name == .crypto_key
		}
	}
}

fn test_source_crypto_key_ipc_storage_full_payload_goldens_and_alias_memory() {
	name := libjs.utf16_string_from_code_units([u16(0xd800), 0])
	key := webcrypto.CryptoKey.create(.secret, false, webcrypto.KeyAlgorithm{ name: name.str(), name_utf16_: name }, [
		.encrypt,
		.encrypt,
		.derive_bits,
	], [u8(17), 34])
	object := StructuredObject.create_crypto_key(key)
	ipc := structured_serialize(structured_object_value(object))!
	assert ipc.data == [u8(24), 21, 0, 2, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 216, 0, 0, 3, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 5, 0, 2, 0, 0, 0, 17, 34]
	storage := structured_serialize_for_storage(structured_object_value(object))!
	assert storage.data == [u8(76), 66, 83, 67, 1, 0, 24, 19, 67, 114, 121, 112, 116, 111, 75,
		101, 121, 1, 13, 115, 101, 99, 114, 101, 116, 0, 0, 4, 0, 216, 0, 0, 3, 15, 101, 110, 99,
		114, 121, 112, 116, 15, 101, 110, 99, 114, 121, 112, 116, 21, 100, 101, 114, 105, 118,
		101, 66, 105, 116, 115, 0, 2, 17, 34]
	for record in [ipc, storage] {
		decoded := structured_object_from_value(structured_deserialize_with_context(record, crypto_codec_context())!)!.crypto_key_?
		assert voidptr(decoded) != voidptr(key)
		assert decoded.type_ == .secret && !decoded.extractable
		assert decoded.internal_algorithm().name_utf16().code_units() == name.code_units()
		assert decoded.internal_usages() == [.encrypt, .encrypt, .derive_bits]
		assert decoded.handle() == [u8(17), 34]
		if _ := structured_deserialize_with_context(record, StructuredDeserializationContext{}) {
			assert false
		}
		if _ := structured_deserialize_with_context(record, StructuredDeserializationContext{
			is_exposed: fn (_ StructuredSerializableInterface) bool {
				return false
			}
		}) {
			assert false
		}
		for length in 0 .. record.data.len {
			if _ := structured_deserialize_with_context(SerializationRecord{ data: record.data[..length], type_: record.type_ }, crypto_codec_context()) {
				assert false
			}
		}
	}
	mut root := StructuredObject.create(.array)
	value := structured_object_value(object)
	root.values = [&value, &value]
	for for_storage in [false, true] {
		record := if for_storage {
			structured_serialize_for_storage(structured_object_value(root))!
		} else {
			structured_serialize(structured_object_value(root))!
		}
		decoded := structured_object_from_value(structured_deserialize_with_context(record, crypto_codec_context())!)!
		assert decoded.values[0].object_data == decoded.values[1].object_data
	}
}

fn test_source_crypto_key_seven_algorithm_payloads_are_exact_in_both_encoders() {
	name := libjs.utf16_string_from_code_units([u16(0xd800), 0])
	hash := libjs.utf16_string_from_code_units([u16(0xdc00)])
	algorithms := [
		webcrypto.CryptoKeyAlgorithm(webcrypto.KeyAlgorithm{ name: name.str(), name_utf16_: name }),
		webcrypto.CryptoKeyAlgorithm(webcrypto.RsaKeyAlgorithm{
			name:            name.str()
			name_utf16_:     name
			modulus_length:  258
			public_exponent: [
				u8(0),
				3,
			]
		}),
		webcrypto.CryptoKeyAlgorithm(webcrypto.RsaHashedKeyAlgorithm{
			name:            name.str()
			name_utf16_:     name
			modulus_length:  258
			public_exponent: [
				u8(0),
				3,
			]
			hash:            hash.str()
			hash_utf16_:     hash
		}),
		webcrypto.CryptoKeyAlgorithm(webcrypto.EcKeyAlgorithm{ name: name.str(), name_utf16_: name, named_curve: hash.str(), named_curve_utf16_: hash }),
		webcrypto.CryptoKeyAlgorithm(webcrypto.AesKeyAlgorithm{ name: name.str(), name_utf16_: name, length: 258 }),
		webcrypto.CryptoKeyAlgorithm(webcrypto.HmacKeyAlgorithm{ name: name.str(), name_utf16_: name, hash: hash.str(), hash_utf16_: hash, length: 258 }),
		webcrypto.CryptoKeyAlgorithm(webcrypto.KmacKeyAlgorithm{ name: name.str(), name_utf16_: name, length: 258 }),
	]
	ipc_tails := [
		[]u8{},
		[u8(2), 1, 0, 0, 2, 0, 0, 0, 0, 3],
		[u8(2), 1, 0, 0, 2, 0, 0, 0, 0, 3, 0, 1, 0, 0, 0, 0, 220],
		[u8(0), 1, 0, 0, 0, 0, 220],
		[u8(2), 1],
		[u8(0), 1, 0, 0, 0, 0, 220, 2, 1, 0, 0],
		[u8(2), 1, 0, 0],
	]
	storage_tails := [
		[]u8{},
		[u8(130), 2, 2, 0, 3],
		[u8(130), 2, 2, 0, 3, 2, 0, 220],
		[u8(2), 0, 220],
		[u8(130), 2],
		[u8(2), 0, 220, 130, 2],
		[u8(130), 2],
	]
	for type_ in [SerializationType.ipc, .storage] {
		for index, algorithm in algorithms {
			mut writer := StructuredSerializer{ type_: type_ }
			writer.write_crypto_algorithm(algorithm)!
			mut expected := [u8(index)]
			if type_ == .ipc {
				expected << [u8(0), 2, 0, 0, 0, 0, 216, 0, 0]
				expected << ipc_tails[index]
			} else {
				expected << [u8(4), 0, 216, 0, 0]
				expected << storage_tails[index]
			}
			assert writer.data == expected
			mut decoder := StructuredDecoder{ data: expected, type_: type_ }
			decoded := decoder.read_crypto_algorithm()!
			assert decoded.name_utf16().code_units() == name.code_units()
			assert decoder.offset == expected.len
			mut reencoded := StructuredSerializer{ type_: type_ }
			reencoded.write_crypto_algorithm(decoded)!
			assert reencoded.data == expected
		}
	}
}

fn test_source_crypto_key_eleven_handle_tags_and_optional_ec_records_goldens() {
	handles := [
		webcrypto.CryptoKeyInternalHandle(webcrypto.ByteBufferKeyHandle{ bytes: [u8(9)] }),
		webcrypto.CryptoKeyInternalHandle(webcrypto.RsaPublicKeyHandle{
			modulus:         [
				u8(0),
				9,
			]
			public_exponent: [u8(0)]
		}),
		webcrypto.CryptoKeyInternalHandle(webcrypto.RsaPrivateKeyHandle{ modulus: [u8(9)], private_exponent: [], public_exponent: [], prime1: [], prime2: [], exponent1: [], exponent2: [], coefficient: [] }),
		webcrypto.CryptoKeyInternalHandle(webcrypto.EcPublicKeyHandle{
			x: [
				u8(0),
				9,
			]
			y: [u8(3)]
		}),
		webcrypto.CryptoKeyInternalHandle(webcrypto.EcPrivateKeyHandle{
			d:          [
				u8(0),
				9,
			]
			parameters: [
				-1,
				128,
			]
			public_key: webcrypto.EcPublicKeyHandle{ x: [u8(1)], y: [] }
		}),
		webcrypto.CryptoKeyInternalHandle(webcrypto.MldsaPublicKeyHandle{ public_key: [u8(9)] }),
		webcrypto.CryptoKeyInternalHandle(webcrypto.MldsaPrivateKeyHandle{ seed: [u8(1)], public_key: [u8(2)], private_key: [u8(3)] }),
		webcrypto.CryptoKeyInternalHandle(webcrypto.MlkemPublicKeyHandle{ public_key: [u8(9)] }),
		webcrypto.CryptoKeyInternalHandle(webcrypto.MlkemPrivateKeyHandle{ seed: [u8(1)], public_key: [u8(2)], private_key: [u8(3)] }),
		webcrypto.CryptoKeyInternalHandle(webcrypto.OkpPublicKeyHandle{ bytes: [u8(9)] }),
		webcrypto.CryptoKeyInternalHandle(webcrypto.OkpPrivateKeyHandle{ bytes: [u8(9)] }),
	]
	ipc_tails := [
		[u8(1), 0, 0, 0, 9],
		[u8(1), 0, 0, 0, 9, 0, 0, 0, 0],
		[u8(1), 0, 0, 0, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			0, 0, 0, 0, 0],
		[u8(2), 0, 0, 0, 0, 9, 2, 0, 0, 0, 0, 3],
		[u8(2), 0, 0, 0, 0, 9, 1, 2, 0, 0, 0, 0, 0, 0, 0, 255, 255, 255, 255, 128, 0, 0, 0, 1,
			1, 0, 0, 0, 1, 1, 0, 0, 0, 0],
		[u8(1), 0, 0, 0, 9],
		[u8(1), 0, 0, 0, 1, 1, 0, 0, 0, 2, 1, 0, 0, 0, 3],
		[u8(1), 0, 0, 0, 9],
		[u8(1), 0, 0, 0, 1, 1, 0, 0, 0, 2, 1, 0, 0, 0, 3],
		[u8(1), 0, 0, 0, 9],
		[u8(1), 0, 0, 0, 9],
	]
	storage_tails := [
		[u8(1), 9],
		[u8(1), 9, 0],
		[u8(1), 9, 0, 0, 0, 0, 0, 0, 0],
		[u8(2), 0, 9, 2, 0, 3],
		[u8(2), 0, 9, 1, 2, 127, 128, 1, 1, 1, 1, 1, 0],
		[u8(1), 9],
		[u8(1), 1, 1, 2, 1, 3],
		[u8(1), 9],
		[u8(1), 1, 1, 2, 1, 3],
		[u8(1), 9],
		[u8(1), 9],
	]
	for type_ in [SerializationType.ipc, .storage] {
		for index, handle in handles {
			mut writer := StructuredSerializer{ type_: type_ }
			writer.write_crypto_handle(handle)!
			mut expected := [u8(index)]
			expected << if type_ == .ipc { ipc_tails[index] } else { storage_tails[index] }
			assert writer.data == expected
			mut decoder := StructuredDecoder{ data: expected, type_: type_ }
			decoded := decoder.read_crypto_handle()!
			assert decoder.offset == expected.len
			mut reencoded := StructuredSerializer{ type_: type_ }
			reencoded.write_crypto_handle(decoded)!
			assert reencoded.data == expected
		}
		for parameters in [?[]int(none), ?[]int([]int{})] {
			mut writer := StructuredSerializer{ type_: type_ }
			writer.write_crypto_handle(webcrypto.EcPrivateKeyHandle{ parameters: parameters })!
			mut decoder := StructuredDecoder{ data: writer.data, type_: type_ }
			decoded := decoder.read_crypto_handle()!
			assert decoded is webcrypto.EcPrivateKeyHandle
			if decoded is webcrypto.EcPrivateKeyHandle {
				assert (decoded.parameters == none) == (parameters == none)
				assert decoded.public_key == none
			}
		}
	}
}

fn test_source_crypto_key_validation_preserves_raw_type_but_rejects_usage_and_storage_identifiers() {
	for type_ in [SerializationType.ipc, .storage] {
		mut invalid_handle := StructuredDecoder{ data: [u8(11)], type_: type_ }
		if _ := invalid_handle.read_crypto_handle() {
			assert false
		} else {
			assert err.msg().contains('handle tag')
		}
	}
	key := webcrypto.CryptoKey.create(.public_key, true, webcrypto.KeyAlgorithm{}, [.encrypt], [])
	mut writer := StructuredSerializer{ type_: .ipc }
	writer.write_crypto_key_payload(key)!
	// Source's IPC int-to-KeyType cast deliberately has no storage enum check.
	mut raw := writer.data.clone()
	raw[0] = 99
	mut decoder := StructuredDecoder{ data: raw, type_: .ipc }
	mut target := webcrypto.CryptoKey.create_empty()
	decoder.read_crypto_key_payload(mut target)!
	assert int(target.type_) == 99
	// The usages vector's Bindings::KeyUsage decoder does validate its ordinal.
	raw = writer.data.clone()
	raw[raw.len - 6] = 12
	mut bad_usage := StructuredDecoder{ data: raw, type_: .ipc }
	if _ := bad_usage.read_crypto_key_payload(mut target) {
		assert false
	}
	mut storage := StructuredSerializer{ type_: .storage }
	storage.write_crypto_key_payload(key)!
	mut invalid := storage.data.clone()
	invalid[1] = `X`
	mut bad_type := StructuredDecoder{ data: invalid, type_: .storage }
	if _ := bad_type.read_crypto_key_payload(mut target) {
		assert false
	}
	invalid = storage.data.clone()
	invalid[7] = 2
	mut bad_bool := StructuredDecoder{ data: invalid, type_: .storage }
	if _ := bad_bool.read_crypto_key_payload(mut target) {
		assert false
	}
}
