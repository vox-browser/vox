// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Stable tagged serialization for CryptoKey algorithms and internal handles,
// translated from CryptoKey.cpp and CryptoKeySerializationTags.h.
module webcrypto

pub enum CryptoKeyHandleTag as u8 {
	byte_buffer       = 0
	rsa_public_key    = 1
	rsa_private_key   = 2
	ec_public_key     = 3
	ec_private_key    = 4
	mldsa_public_key  = 5
	mldsa_private_key = 6
	mlkem_public_key  = 7
	mlkem_private_key = 8
	okp_public_key    = 9
	okp_private_key   = 10
}

pub struct ByteBufferKeyHandle {
pub mut:
	bytes []u8
}

pub struct RsaPublicKeyHandle {
pub mut:
	modulus         []u8
	public_exponent []u8
}

pub struct RsaPrivateKeyHandle {
pub mut:
	modulus          []u8
	private_exponent []u8
	public_exponent  []u8
	prime1           []u8
	prime2           []u8
	exponent1        []u8
	exponent2        []u8
	coefficient      []u8
}

pub struct EcPublicKeyHandle {
pub mut:
	x []u8
	y []u8
}

pub struct EcPrivateKeyHandle {
pub mut:
	d          []u8
	parameters ?[]int
	public_key ?EcPublicKeyHandle
}

pub struct MldsaPublicKeyHandle {
pub mut:
	public_key []u8
}

pub struct MldsaPrivateKeyHandle {
pub mut:
	seed        []u8
	public_key  []u8
	private_key []u8
}

pub struct MlkemPublicKeyHandle {
pub mut:
	public_key []u8
}

pub struct MlkemPrivateKeyHandle {
pub mut:
	seed        []u8
	public_key  []u8
	private_key []u8
}

pub struct OkpPublicKeyHandle {
pub mut:
	bytes []u8
}

pub struct OkpPrivateKeyHandle {
pub mut:
	bytes []u8
}

pub type CryptoKeyInternalHandle = ByteBufferKeyHandle
	| EcPrivateKeyHandle
	| EcPublicKeyHandle
	| MldsaPrivateKeyHandle
	| MldsaPublicKeyHandle
	| MlkemPrivateKeyHandle
	| MlkemPublicKeyHandle
	| OkpPrivateKeyHandle
	| OkpPublicKeyHandle
	| RsaPrivateKeyHandle
	| RsaPublicKeyHandle

struct CryptoKeySerializationWriter {
mut:
	bytes []u8
}

fn (mut writer CryptoKeySerializationWriter) write_u8(value u8) {
	writer.bytes << value
}

fn (mut writer CryptoKeySerializationWriter) write_u16(value u16) {
	writer.bytes << u8(value >> 8)
	writer.bytes << u8(value)
}

fn (mut writer CryptoKeySerializationWriter) write_u32(value u32) {
	writer.bytes << u8(value >> 24)
	writer.bytes << u8(value >> 16)
	writer.bytes << u8(value >> 8)
	writer.bytes << u8(value)
}

fn (mut writer CryptoKeySerializationWriter) write_bytes(value []u8) {
	writer.write_u32(u32(value.len))
	writer.bytes << value
}

fn (mut writer CryptoKeySerializationWriter) write_big_integer(value []u8) {
	writer.write_bytes(unsigned_big_integer_bytes(value))
}

fn (mut writer CryptoKeySerializationWriter) write_string(value string) {
	writer.write_bytes(value.bytes())
}

struct CryptoKeySerializationReader {
	bytes []u8
mut:
	offset int
}

fn (mut reader CryptoKeySerializationReader) read_u8() !u8 {
	if reader.offset >= reader.bytes.len {
		return error('DataCloneError: Truncated CryptoKey serialization')
	}
	value := reader.bytes[reader.offset]
	reader.offset++
	return value
}

fn (mut reader CryptoKeySerializationReader) read_u16() !u16 {
	return (u16(reader.read_u8()!) << 8) | u16(reader.read_u8()!)
}

fn (mut reader CryptoKeySerializationReader) read_u32() !u32 {
	return (u32(reader.read_u8()!) << 24) | (u32(reader.read_u8()!) << 16) | (u32(reader.read_u8()!) << 8) | u32(reader.read_u8()!)
}

fn (mut reader CryptoKeySerializationReader) read_bytes() ![]u8 {
	length := int(reader.read_u32()!)
	if length < 0 || reader.offset + length > reader.bytes.len {
		return error('DataCloneError: Truncated CryptoKey byte sequence')
	}
	value := reader.bytes[reader.offset..reader.offset + length].clone()
	reader.offset += length
	return value
}

fn (mut reader CryptoKeySerializationReader) read_string() !string {
	return reader.read_bytes()!.bytestr()
}

fn decode_handle_tag(mut reader CryptoKeySerializationReader) !CryptoKeyHandleTag {
	tag := reader.read_u8()!
	if tag > u8(CryptoKeyHandleTag.okp_private_key) {
		return error('DataCloneError: Invalid CryptoKey handle tag')
	}
	return unsafe { CryptoKeyHandleTag(tag) }
}

fn serialize_ec_public_key(mut writer CryptoKeySerializationWriter, key EcPublicKeyHandle) {
	writer.write_bytes(key.x)
	writer.write_bytes(key.y)
}

pub fn serialize_handle(handle CryptoKeyInternalHandle) []u8 {
	mut writer := CryptoKeySerializationWriter{}
	match handle {
		ByteBufferKeyHandle {
			writer.write_u8(u8(CryptoKeyHandleTag.byte_buffer))
			writer.write_bytes(handle.bytes)
		}
		RsaPublicKeyHandle {
			writer.write_u8(u8(CryptoKeyHandleTag.rsa_public_key))
			writer.write_big_integer(handle.modulus)
			writer.write_big_integer(handle.public_exponent)
		}
		RsaPrivateKeyHandle {
			writer.write_u8(u8(CryptoKeyHandleTag.rsa_private_key))
			writer.write_big_integer(handle.modulus)
			writer.write_big_integer(handle.private_exponent)
			writer.write_big_integer(handle.public_exponent)
			writer.write_big_integer(handle.prime1)
			writer.write_big_integer(handle.prime2)
			writer.write_big_integer(handle.exponent1)
			writer.write_big_integer(handle.exponent2)
			writer.write_big_integer(handle.coefficient)
		}
		EcPublicKeyHandle {
			writer.write_u8(u8(CryptoKeyHandleTag.ec_public_key))
			serialize_ec_public_key(mut writer, handle)
		}
		EcPrivateKeyHandle {
			writer.write_u8(u8(CryptoKeyHandleTag.ec_private_key))
			writer.write_bytes(handle.d)
			if parameters := handle.parameters {
				writer.write_u8(1)
				writer.write_u32(u32(parameters.len))
				for parameter in parameters {
					writer.write_u32(u32(parameter))
				}
			} else {
				writer.write_u8(0)
			}
			if public_key := handle.public_key {
				writer.write_u8(1)
				serialize_ec_public_key(mut writer, public_key)
			} else {
				writer.write_u8(0)
			}
		}
		MldsaPublicKeyHandle {
			writer.write_u8(u8(CryptoKeyHandleTag.mldsa_public_key))
			writer.write_bytes(handle.public_key)
		}
		MldsaPrivateKeyHandle {
			writer.write_u8(u8(CryptoKeyHandleTag.mldsa_private_key))
			writer.write_bytes(handle.seed)
			writer.write_bytes(handle.public_key)
			writer.write_bytes(handle.private_key)
		}
		MlkemPublicKeyHandle {
			writer.write_u8(u8(CryptoKeyHandleTag.mlkem_public_key))
			writer.write_bytes(handle.public_key)
		}
		MlkemPrivateKeyHandle {
			writer.write_u8(u8(CryptoKeyHandleTag.mlkem_private_key))
			writer.write_bytes(handle.seed)
			writer.write_bytes(handle.public_key)
			writer.write_bytes(handle.private_key)
		}
		OkpPublicKeyHandle {
			writer.write_u8(u8(CryptoKeyHandleTag.okp_public_key))
			writer.write_bytes(handle.bytes)
		}
		OkpPrivateKeyHandle {
			writer.write_u8(u8(CryptoKeyHandleTag.okp_private_key))
			writer.write_bytes(handle.bytes)
		}
	}
	return writer.bytes
}

fn deserialize_rsa_public_key(mut reader CryptoKeySerializationReader) !RsaPublicKeyHandle {
	return RsaPublicKeyHandle{
		modulus: reader.read_bytes()!
		public_exponent: reader.read_bytes()!
	}
}

fn deserialize_rsa_private_key(mut reader CryptoKeySerializationReader) !RsaPrivateKeyHandle {
	return RsaPrivateKeyHandle{
		modulus: reader.read_bytes()!
		private_exponent: reader.read_bytes()!
		public_exponent: reader.read_bytes()!
		prime1: reader.read_bytes()!
		prime2: reader.read_bytes()!
		exponent1: reader.read_bytes()!
		exponent2: reader.read_bytes()!
		coefficient: reader.read_bytes()!
	}
}

fn deserialize_ec_public_key(mut reader CryptoKeySerializationReader) !EcPublicKeyHandle {
	return EcPublicKeyHandle{
		x: reader.read_bytes()!
		y: reader.read_bytes()!
	}
}

fn deserialize_ec_private_key(mut reader CryptoKeySerializationReader) !EcPrivateKeyHandle {
	d := reader.read_bytes()!
	mut parameters := ?[]int(none)
	if reader.read_u8()! != 0 {
		length := int(reader.read_u32()!)
		mut values := []int{cap: length}
		for _ in 0 .. length {
			values << int(i32(reader.read_u32()!))
		}
		parameters = values.clone()
	}
	mut public_key := ?EcPublicKeyHandle(none)
	if reader.read_u8()! != 0 {
		public_key = deserialize_ec_public_key(mut reader)!
	}
	return EcPrivateKeyHandle{
		d: d
		parameters: parameters
		public_key: public_key
	}
}

fn deserialize_mldsa_public_key(mut reader CryptoKeySerializationReader) !MldsaPublicKeyHandle {
	return MldsaPublicKeyHandle{
		public_key: reader.read_bytes()!
	}
}

fn deserialize_mldsa_private_key(mut reader CryptoKeySerializationReader) !MldsaPrivateKeyHandle {
	return MldsaPrivateKeyHandle{
		seed: reader.read_bytes()!
		public_key: reader.read_bytes()!
		private_key: reader.read_bytes()!
	}
}

fn deserialize_mlkem_public_key(mut reader CryptoKeySerializationReader) !MlkemPublicKeyHandle {
	return MlkemPublicKeyHandle{
		public_key: reader.read_bytes()!
	}
}

fn deserialize_mlkem_private_key(mut reader CryptoKeySerializationReader) !MlkemPrivateKeyHandle {
	return MlkemPrivateKeyHandle{
		seed: reader.read_bytes()!
		public_key: reader.read_bytes()!
		private_key: reader.read_bytes()!
	}
}

fn deserialize_okp_public_key(mut reader CryptoKeySerializationReader) !OkpPublicKeyHandle {
	return OkpPublicKeyHandle{
		bytes: reader.read_bytes()!
	}
}

fn deserialize_okp_private_key(mut reader CryptoKeySerializationReader) !OkpPrivateKeyHandle {
	return OkpPrivateKeyHandle{
		bytes: reader.read_bytes()!
	}
}

pub fn deserialize_handle(bytes []u8) !CryptoKeyInternalHandle {
	mut reader := CryptoKeySerializationReader{
		bytes: bytes
	}
	tag := decode_handle_tag(mut reader)!
	handle := match tag {
		.byte_buffer { CryptoKeyInternalHandle(ByteBufferKeyHandle{ bytes: reader.read_bytes()! }) }
		.rsa_public_key { CryptoKeyInternalHandle(deserialize_rsa_public_key(mut reader)!) }
		.rsa_private_key { CryptoKeyInternalHandle(deserialize_rsa_private_key(mut reader)!) }
		.ec_public_key { CryptoKeyInternalHandle(deserialize_ec_public_key(mut reader)!) }
		.ec_private_key { CryptoKeyInternalHandle(deserialize_ec_private_key(mut reader)!) }
		.mldsa_public_key { CryptoKeyInternalHandle(deserialize_mldsa_public_key(mut reader)!) }
		.mldsa_private_key { CryptoKeyInternalHandle(deserialize_mldsa_private_key(mut reader)!) }
		.mlkem_public_key { CryptoKeyInternalHandle(deserialize_mlkem_public_key(mut reader)!) }
		.mlkem_private_key { CryptoKeyInternalHandle(deserialize_mlkem_private_key(mut reader)!) }
		.okp_public_key { CryptoKeyInternalHandle(deserialize_okp_public_key(mut reader)!) }
		.okp_private_key { CryptoKeyInternalHandle(deserialize_okp_private_key(mut reader)!) }
	}
	if reader.offset != reader.bytes.len {
		return error('DataCloneError: Trailing bytes in CryptoKey handle')
	}
	return handle
}

pub enum CryptoKeyAlgorithmTag as u8 {
	key_algorithm            = 0
	rsa_key_algorithm        = 1
	rsa_hashed_key_algorithm = 2
	ec_key_algorithm         = 3
	aes_key_algorithm        = 4
	hmac_key_algorithm       = 5
	kmac_key_algorithm       = 6
}

pub fn serialize_algorithm(algorithm CryptoKeyAlgorithm) []u8 {
	mut writer := CryptoKeySerializationWriter{}
	match algorithm {
		KeyAlgorithm {
			writer.write_u8(u8(CryptoKeyAlgorithmTag.key_algorithm))
			writer.write_string(algorithm.name)
		}
		RsaKeyAlgorithm {
			writer.write_u8(u8(CryptoKeyAlgorithmTag.rsa_key_algorithm))
			writer.write_string(algorithm.name)
			writer.write_u32(algorithm.modulus_length)
			writer.write_bytes(algorithm.public_exponent)
		}
		RsaHashedKeyAlgorithm {
			writer.write_u8(u8(CryptoKeyAlgorithmTag.rsa_hashed_key_algorithm))
			writer.write_string(algorithm.name)
			writer.write_u32(algorithm.modulus_length)
			writer.write_bytes(algorithm.public_exponent)
			writer.write_string(algorithm.hash)
		}
		EcKeyAlgorithm {
			writer.write_u8(u8(CryptoKeyAlgorithmTag.ec_key_algorithm))
			writer.write_string(algorithm.name)
			writer.write_string(algorithm.named_curve)
		}
		AesKeyAlgorithm {
			writer.write_u8(u8(CryptoKeyAlgorithmTag.aes_key_algorithm))
			writer.write_string(algorithm.name)
			writer.write_u16(algorithm.length)
		}
		HmacKeyAlgorithm {
			writer.write_u8(u8(CryptoKeyAlgorithmTag.hmac_key_algorithm))
			writer.write_string(algorithm.name)
			writer.write_string(algorithm.hash)
			writer.write_u32(algorithm.length)
		}
		KmacKeyAlgorithm {
			writer.write_u8(u8(CryptoKeyAlgorithmTag.kmac_key_algorithm))
			writer.write_string(algorithm.name)
			writer.write_u32(algorithm.length)
		}
	}
	return writer.bytes
}

pub fn deserialize_algorithm(bytes []u8) !CryptoKeyAlgorithm {
	mut reader := CryptoKeySerializationReader{
		bytes: bytes
	}
	tag_value := reader.read_u8()!
	if tag_value > u8(CryptoKeyAlgorithmTag.kmac_key_algorithm) {
		return error('DataCloneError: Invalid CryptoKey algorithm tag')
	}
	tag := unsafe { CryptoKeyAlgorithmTag(tag_value) }
	algorithm := match tag {
		.key_algorithm {
			CryptoKeyAlgorithm(KeyAlgorithm{ name: reader.read_string()! })
		}
		.rsa_key_algorithm {
			CryptoKeyAlgorithm(RsaKeyAlgorithm{
				name: reader.read_string()!
				modulus_length: reader.read_u32()!
				public_exponent: reader.read_bytes()!
			})
		}
		.rsa_hashed_key_algorithm {
			CryptoKeyAlgorithm(RsaHashedKeyAlgorithm{
				name: reader.read_string()!
				modulus_length: reader.read_u32()!
				public_exponent: reader.read_bytes()!
				hash: reader.read_string()!
			})
		}
		.ec_key_algorithm {
			CryptoKeyAlgorithm(EcKeyAlgorithm{
				name: reader.read_string()!
				named_curve: reader.read_string()!
			})
		}
		.aes_key_algorithm {
			CryptoKeyAlgorithm(AesKeyAlgorithm{
				name: reader.read_string()!
				length: reader.read_u16()!
			})
		}
		.hmac_key_algorithm {
			CryptoKeyAlgorithm(HmacKeyAlgorithm{
				name: reader.read_string()!
				hash: reader.read_string()!
				length: reader.read_u32()!
			})
		}
		.kmac_key_algorithm {
			CryptoKeyAlgorithm(KmacKeyAlgorithm{
				name: reader.read_string()!
				length: reader.read_u32()!
			})
		}
	}
	if reader.offset != reader.bytes.len {
		return error('DataCloneError: Trailing bytes in CryptoKey algorithm')
	}
	return algorithm
}

pub fn raw_bytes_for_internal_handle(handle CryptoKeyInternalHandle) []u8 {
	return match handle {
		ByteBufferKeyHandle { handle.bytes.clone() }
		RsaPublicKeyHandle { handle.modulus.clone() }
		RsaPrivateKeyHandle { handle.private_exponent.clone() }
		EcPublicKeyHandle { handle.x.clone() }
		EcPrivateKeyHandle { handle.d.clone() }
		MldsaPublicKeyHandle { handle.public_key.clone() }
		MldsaPrivateKeyHandle { handle.private_key.clone() }
		MlkemPublicKeyHandle { handle.public_key.clone() }
		MlkemPrivateKeyHandle { handle.private_key.clone() }
		OkpPublicKeyHandle { handle.bytes.clone() }
		OkpPrivateKeyHandle { handle.bytes.clone() }
	}
}

fn clone_internal_handle(handle CryptoKeyInternalHandle) CryptoKeyInternalHandle {
	return deserialize_handle(serialize_handle(handle)) or {
		panic('failed to clone a valid CryptoKey internal handle: ${err}')
	}
}

fn secure_zero_bytes(mut bytes []u8) {
	for mut byte in bytes {
		byte = 0
	}
}

fn secure_zero_internal_handle(mut handle CryptoKeyInternalHandle) {
	match mut handle {
		ByteBufferKeyHandle {
			secure_zero_bytes(mut handle.bytes)
		}
		RsaPublicKeyHandle {
			secure_zero_bytes(mut handle.modulus)
			secure_zero_bytes(mut handle.public_exponent)
		}
		RsaPrivateKeyHandle {
			secure_zero_bytes(mut handle.modulus)
			secure_zero_bytes(mut handle.private_exponent)
			secure_zero_bytes(mut handle.public_exponent)
			secure_zero_bytes(mut handle.prime1)
			secure_zero_bytes(mut handle.prime2)
			secure_zero_bytes(mut handle.exponent1)
			secure_zero_bytes(mut handle.exponent2)
			secure_zero_bytes(mut handle.coefficient)
		}
		EcPublicKeyHandle {
			secure_zero_bytes(mut handle.x)
			secure_zero_bytes(mut handle.y)
		}
		EcPrivateKeyHandle {
			secure_zero_bytes(mut handle.d)
			if mut parameters := handle.parameters {
				for mut parameter in parameters {
					parameter = 0
				}
			}
			if mut public_key := handle.public_key {
				secure_zero_bytes(mut public_key.x)
				secure_zero_bytes(mut public_key.y)
			}
		}
		MldsaPublicKeyHandle {
			secure_zero_bytes(mut handle.public_key)
		}
		MldsaPrivateKeyHandle {
			secure_zero_bytes(mut handle.seed)
			secure_zero_bytes(mut handle.public_key)
			secure_zero_bytes(mut handle.private_key)
		}
		MlkemPublicKeyHandle {
			secure_zero_bytes(mut handle.public_key)
		}
		MlkemPrivateKeyHandle {
			secure_zero_bytes(mut handle.seed)
			secure_zero_bytes(mut handle.public_key)
			secure_zero_bytes(mut handle.private_key)
		}
		OkpPublicKeyHandle {
			secure_zero_bytes(mut handle.bytes)
		}
		OkpPrivateKeyHandle {
			secure_zero_bytes(mut handle.bytes)
		}
	}
}
