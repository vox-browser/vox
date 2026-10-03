// Copyright (c) 2023, stelar7 <dudedbz@gmail.com>
// Copyright (c) 2024, Andrew Kaster <akaster@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// Crypto/CryptoKey.cpp payloads use HTML's source IPC/storage encoders.
module html

import webcrypto

fn (mut serializer StructuredSerializer) write_u16(value u16) {
	if serializer.type_ == .storage {
		serializer.write_unsigned_leb128(u64(value))
		return
	}
	serializer.write_u8(u8(value))
	serializer.write_u8(u8(value >> 8))
}

fn (mut decoder StructuredDecoder) read_u16() !u16 {
	if decoder.type_ == .storage { return u16(decoder.read_unsigned_leb128(16)!) }
	low := decoder.read_u8()!
	high := decoder.read_u8()!
	return u16(low) | (u16(high) << 8)
}

fn (mut decoder StructuredDecoder) read_source_bool() !bool {
	value := decoder.read_u8()!
	if decoder.type_ == .storage && value > 1 {
		return error('DataCloneError: Invalid structured serialize bool')
	}
	// Valid source IPC records contain native bool 0/1. The C++ memcpy of an
	// invalid native bool representation has no portable semantic guarantee.
	return value != 0
}

fn (mut serializer StructuredSerializer) write_crypto_algorithm(algorithm webcrypto.CryptoKeyAlgorithm) ! {
	name := algorithm.name_utf16()
	match algorithm {
		webcrypto.KeyAlgorithm {
			serializer.write_u8(0)
			serializer.write_utf16_string(name)!
		}
		webcrypto.RsaKeyAlgorithm {
			serializer.write_u8(1)
			serializer.write_utf16_string(name)!
			serializer.write_u32(algorithm.modulus_length)
			serializer.write_bytes(algorithm.public_exponent)!
		}
		webcrypto.RsaHashedKeyAlgorithm {
			serializer.write_u8(2)
			serializer.write_utf16_string(name)!
			serializer.write_u32(algorithm.modulus_length)
			serializer.write_bytes(algorithm.public_exponent)!
			serializer.write_utf16_string(algorithm.hash_utf16())!
		}
		webcrypto.EcKeyAlgorithm {
			serializer.write_u8(3)
			serializer.write_utf16_string(name)!
			serializer.write_utf16_string(algorithm.named_curve_utf16())!
		}
		webcrypto.AesKeyAlgorithm {
			serializer.write_u8(4)
			serializer.write_utf16_string(name)!
			serializer.write_u16(algorithm.length)
		}
		webcrypto.HmacKeyAlgorithm {
			serializer.write_u8(5)
			serializer.write_utf16_string(name)!
			serializer.write_utf16_string(algorithm.hash_utf16())!
			serializer.write_u32(algorithm.length)
		}
		webcrypto.KmacKeyAlgorithm {
			serializer.write_u8(6)
			serializer.write_utf16_string(name)!
			serializer.write_u32(algorithm.length)
		}
	}
}

fn (mut decoder StructuredDecoder) read_crypto_algorithm() !webcrypto.CryptoKeyAlgorithm {
	tag := decoder.read_u8()!
	if tag > 6 { panic('Source VERIFY_NOT_REACHED: invalid CryptoKey algorithm tag') }
	name := decoder.read_utf16_string()!
	// Source's Utf16String is the record owner; the string fields serve the
	// established algorithm adapters without replacing these raw code units.
	match tag {
		0 { return webcrypto.KeyAlgorithm{ name: name.str(), name_utf16_: name } }
		1 {
			return webcrypto.RsaKeyAlgorithm{ name: name.str(), name_utf16_: name, modulus_length: decoder.read_u32()!, public_exponent: decoder.read_bytes()! }
		}
		2 {
			modulus_length := decoder.read_u32()!
			public_exponent := decoder.read_bytes()!
			hash := decoder.read_utf16_string()!
			return webcrypto.RsaHashedKeyAlgorithm{ name: name.str(), name_utf16_: name, modulus_length: modulus_length, public_exponent: public_exponent, hash: hash.str(), hash_utf16_: hash }
		}
		3 {
			curve := decoder.read_utf16_string()!
			return webcrypto.EcKeyAlgorithm{ name: name.str(), name_utf16_: name, named_curve: curve.str(), named_curve_utf16_: curve }
		}
		4 {
			return webcrypto.AesKeyAlgorithm{ name: name.str(), name_utf16_: name, length: decoder.read_u16()! }
		}
		5 {
			hash := decoder.read_utf16_string()!
			return webcrypto.HmacKeyAlgorithm{ name: name.str(), name_utf16_: name, hash: hash.str(), hash_utf16_: hash, length: decoder.read_u32()! }
		}
		6 {
			return webcrypto.KmacKeyAlgorithm{ name: name.str(), name_utf16_: name, length: decoder.read_u32()! }
		}
		else { panic('unreachable CryptoKey algorithm tag') }
	}
}

// Crypto/UnsignedBigInteger::byte_length/export_data uses the shortest
// big-endian unsigned octets. LibTomMath mp_ubin_size(0) is zero, unlike the
// earlier WebCrypto BigInteger binding adapter's one-byte zero.
fn crypto_unsigned_integer_octets(bytes []u8) []u8 {
	mut first := 0
	for first < bytes.len && bytes[first] == 0 { first++ }
	return bytes[first..].clone()
}

fn (mut serializer StructuredSerializer) write_crypto_unsigned_integer(bytes []u8) ! {
	serializer.write_bytes(crypto_unsigned_integer_octets(bytes))!
}

fn (mut decoder StructuredDecoder) read_crypto_unsigned_integer() ![]u8 {
	return crypto_unsigned_integer_octets(decoder.read_bytes()!)
}

fn (mut serializer StructuredSerializer) write_crypto_ec_public(key webcrypto.EcPublicKeyHandle) ! {
	// Source ECPublicKey imports numeric x/y and retains scalar_size from x.
	// Its x_bytes/y_bytes both export padded to that retained width.
	serializer.write_bytes(key.x)!
	y := crypto_unsigned_integer_octets(key.y)
	if y.len > key.x.len {
		panic('Source MUST: EC coordinate exceeds retained scalar width')
	}
	mut y_bytes := []u8{len: key.x.len - y.len}
	y_bytes << y
	serializer.write_bytes(y_bytes)!
}

fn (mut decoder StructuredDecoder) read_crypto_ec_public() !webcrypto.EcPublicKeyHandle {
	return webcrypto.EcPublicKeyHandle{ x: decoder.read_bytes()!, y: decoder.read_bytes()! }
}

fn (mut serializer StructuredSerializer) write_crypto_handle(handle webcrypto.CryptoKeyInternalHandle) ! {
	match handle {
		webcrypto.ByteBufferKeyHandle {
			serializer.write_u8(0)
			serializer.write_bytes(handle.bytes)!
		}
		webcrypto.RsaPublicKeyHandle {
			serializer.write_u8(1)
			serializer.write_crypto_unsigned_integer(handle.modulus)!
			serializer.write_crypto_unsigned_integer(handle.public_exponent)!
		}
		webcrypto.RsaPrivateKeyHandle {
			serializer.write_u8(2)
			serializer.write_crypto_unsigned_integer(handle.modulus)!
			serializer.write_crypto_unsigned_integer(handle.private_exponent)!
			serializer.write_crypto_unsigned_integer(handle.public_exponent)!
			serializer.write_crypto_unsigned_integer(handle.prime1)!
			serializer.write_crypto_unsigned_integer(handle.prime2)!
			serializer.write_crypto_unsigned_integer(handle.exponent1)!
			serializer.write_crypto_unsigned_integer(handle.exponent2)!
			serializer.write_crypto_unsigned_integer(handle.coefficient)!
		}
		webcrypto.EcPublicKeyHandle {
			serializer.write_u8(3)
			serializer.write_crypto_ec_public(handle)!
		}
		webcrypto.EcPrivateKeyHandle {
			serializer.write_u8(4)
			serializer.write_bytes(handle.d)!
			serializer.write_u8(if handle.parameters != none { u8(1) } else { u8(0) })
			if parameters := handle.parameters {
				serializer.write_u64(u64(parameters.len))
				for parameter in parameters { serializer.write_i32(i32(parameter)) }
			}
			serializer.write_u8(if handle.public_key != none { u8(1) } else { u8(0) })
			if public_key := handle.public_key { serializer.write_crypto_ec_public(public_key)! }
		}
		webcrypto.MldsaPublicKeyHandle {
			serializer.write_u8(5)
			serializer.write_bytes(handle.public_key)!
		}
		webcrypto.MldsaPrivateKeyHandle {
			serializer.write_u8(6)
			serializer.write_bytes(handle.seed)!
			serializer.write_bytes(handle.public_key)!
			serializer.write_bytes(handle.private_key)!
		}
		webcrypto.MlkemPublicKeyHandle {
			serializer.write_u8(7)
			serializer.write_bytes(handle.public_key)!
		}
		webcrypto.MlkemPrivateKeyHandle {
			serializer.write_u8(8)
			serializer.write_bytes(handle.seed)!
			serializer.write_bytes(handle.public_key)!
			serializer.write_bytes(handle.private_key)!
		}
		webcrypto.OkpPublicKeyHandle {
			serializer.write_u8(9)
			serializer.write_bytes(handle.bytes)!
		}
		webcrypto.OkpPrivateKeyHandle {
			serializer.write_u8(10)
			serializer.write_bytes(handle.bytes)!
		}
	}
}

fn (mut decoder StructuredDecoder) read_crypto_handle() !webcrypto.CryptoKeyInternalHandle {
	tag := decoder.read_u8()!
	match tag {
		0 { return webcrypto.ByteBufferKeyHandle{ bytes: decoder.read_bytes()! } }
		1 {
			return webcrypto.RsaPublicKeyHandle{ modulus: decoder.read_crypto_unsigned_integer()!, public_exponent: decoder.read_crypto_unsigned_integer()! }
		}
		2 {
			return webcrypto.RsaPrivateKeyHandle{ modulus: decoder.read_crypto_unsigned_integer()!, private_exponent: decoder.read_crypto_unsigned_integer()!, public_exponent: decoder.read_crypto_unsigned_integer()!, prime1: decoder.read_crypto_unsigned_integer()!, prime2: decoder.read_crypto_unsigned_integer()!, exponent1: decoder.read_crypto_unsigned_integer()!, exponent2: decoder.read_crypto_unsigned_integer()!, coefficient: decoder.read_crypto_unsigned_integer()! }
		}
		3 { return decoder.read_crypto_ec_public()! }
		4 {
			d := decoder.read_bytes()!
			mut parameters := ?[]int(none)
			if decoder.read_source_bool()! {
				count := decoder.read_collection_count(1)!
				mut values := []int{cap: count}
				for _ in 0 .. count { values << int(decoder.read_i32()!) }
				parameters = values.clone()
			}
			mut public_key := ?webcrypto.EcPublicKeyHandle(none)
			if decoder.read_source_bool()! { public_key = decoder.read_crypto_ec_public()! }
			return webcrypto.EcPrivateKeyHandle{ d: d, parameters: parameters, public_key: public_key }
		}
		5 { return webcrypto.MldsaPublicKeyHandle{ public_key: decoder.read_bytes()! } }
		6 {
			return webcrypto.MldsaPrivateKeyHandle{ seed: decoder.read_bytes()!, public_key: decoder.read_bytes()!, private_key: decoder.read_bytes()! }
		}
		7 { return webcrypto.MlkemPublicKeyHandle{ public_key: decoder.read_bytes()! } }
		8 {
			return webcrypto.MlkemPrivateKeyHandle{ seed: decoder.read_bytes()!, public_key: decoder.read_bytes()!, private_key: decoder.read_bytes()! }
		}
		9 { return webcrypto.OkpPublicKeyHandle{ bytes: decoder.read_bytes()! } }
		10 { return webcrypto.OkpPrivateKeyHandle{ bytes: decoder.read_bytes()! } }
		else { return error('DataCloneError: Invalid CryptoKey handle tag') }
	}
}

fn (mut serializer StructuredSerializer) write_crypto_key_payload(key &webcrypto.CryptoKey) ! {
	if key.json_web_key_handle() != none {
		return error('DataCloneError: compatibility JWK facade has no source InternalKeyData')
	}
	if serializer.type_ == .storage {
		serializer.write_string(webcrypto.key_type_string(key.bindings_type()))!
	} else {
		serializer.write_i32(i32(key.type_))
	}
	serializer.write_u8(if key.extractable { u8(1) } else { u8(0) })
	serializer.write_crypto_algorithm(key.internal_algorithm())!
	usages := key.internal_usages()
	serializer.write_u64(u64(usages.len))
	for usage in usages {
		if serializer.type_ == .storage {
			serializer.write_string(webcrypto.key_usage_string(usage))!
		} else {
			serializer.write_u8(u8(usage))
		}
	}
	serializer.write_crypto_handle(key.internal_handle())!
}

fn (mut decoder StructuredDecoder) read_crypto_key_payload(mut key webcrypto.CryptoKey) ! {
	if decoder.type_ == .storage {
		identifier := decoder.read_string()!
		key.set_type(webcrypto.parse_key_type(identifier) or { return error('DataCloneError: Unknown structured serialize key type') })
	} else {
		// Source CryptoKey.cpp decodes int then casts its source KeyType, rather
		// than using the validating Bindings::KeyType storage decoder.
		key.set_type(unsafe { webcrypto.KeyType(decoder.read_i32()!) })
	}
	key.set_extractable(decoder.read_source_bool()!)
	key.set_algorithm(decoder.read_crypto_algorithm()!)
	count := decoder.read_collection_count(1)!
	mut usages := []webcrypto.KeyUsage{cap: count}
	for _ in 0 .. count {
		if decoder.type_ == .storage {
			identifier := decoder.read_string()!
			usages << webcrypto.parse_key_usage(identifier) or { return error('DataCloneError: Unknown structured serialize key usage') }
		} else {
			value := decoder.read_u8()!
			if value > 11 { return error('DataCloneError: Invalid structured serialize key usage') }
			usages << unsafe { webcrypto.KeyUsage(value) }
		}
	}
	key.set_usages(usages)
	key.install_deserialized_internal_handle(decoder.read_crypto_handle()!)
}
