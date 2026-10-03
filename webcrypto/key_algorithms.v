// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Crypto/KeyAlgorithms.{h,cpp}.
module webcrypto

import libjs

pub struct KeyAlgorithm {
pub mut:
	name        string
	name_utf16_ ?libjs.Utf16String
	realm_id    u64
}

pub fn KeyAlgorithm.create() &KeyAlgorithm {
	return &KeyAlgorithm{}
}

pub fn (mut algorithm KeyAlgorithm) set_name(name string) {
	algorithm.name = name
	algorithm.name_utf16_ = none
}

pub fn (algorithm &KeyAlgorithm) name() string {
	return algorithm.name
}

pub struct RsaKeyAlgorithm {
pub mut:
	name            string
	name_utf16_     ?libjs.Utf16String
	modulus_length  u32
	public_exponent []u8
}

pub fn RsaKeyAlgorithm.create() &RsaKeyAlgorithm {
	return &RsaKeyAlgorithm{}
}

pub fn (mut algorithm RsaKeyAlgorithm) set_name(name string) {
	algorithm.name = name
	algorithm.name_utf16_ = none
}

pub fn (mut algorithm RsaKeyAlgorithm) set_modulus_length(modulus_length u32) {
	algorithm.modulus_length = modulus_length
}

fn unsigned_big_integer_bytes(bytes []u8) []u8 {
	mut first_nonzero := 0
	for first_nonzero < bytes.len && bytes[first_nonzero] == 0 {
		first_nonzero++
	}
	// WebCrypto's BigInteger uses the shortest unsigned big-endian octet
	// sequence, except that zero is represented by one zero-valued octet.
	if first_nonzero == bytes.len {
		return [u8(0)]
	}
	return bytes[first_nonzero..].clone()
}

// BigInteger is exposed to WebIDL as an unsigned, big-endian Uint8Array.
pub fn (mut algorithm RsaKeyAlgorithm) set_public_exponent(exponent []u8) {
	algorithm.public_exponent = unsigned_big_integer_bytes(exponent)
}

pub fn (algorithm &RsaKeyAlgorithm) name() string {
	return algorithm.name
}

pub fn (algorithm &RsaKeyAlgorithm) modulus_length() u32 {
	return algorithm.modulus_length
}

pub fn (algorithm &RsaKeyAlgorithm) public_exponent() []u8 {
	return algorithm.public_exponent.clone()
}

pub struct RsaHashedKeyAlgorithm {
pub mut:
	name            string
	name_utf16_     ?libjs.Utf16String
	modulus_length  u32
	public_exponent []u8
	hash            string
	hash_utf16_     ?libjs.Utf16String
}

pub fn RsaHashedKeyAlgorithm.create() &RsaHashedKeyAlgorithm {
	return &RsaHashedKeyAlgorithm{}
}

pub fn (mut algorithm RsaHashedKeyAlgorithm) set_name(name string) {
	algorithm.name = name
	algorithm.name_utf16_ = none
}

pub fn (mut algorithm RsaHashedKeyAlgorithm) set_modulus_length(modulus_length u32) {
	algorithm.modulus_length = modulus_length
}

pub fn (mut algorithm RsaHashedKeyAlgorithm) set_public_exponent(exponent []u8) {
	algorithm.public_exponent = unsigned_big_integer_bytes(exponent)
}

pub fn (mut algorithm RsaHashedKeyAlgorithm) set_hash(hash string) {
	algorithm.hash = hash
	algorithm.hash_utf16_ = none
}

pub fn (algorithm &RsaHashedKeyAlgorithm) hash_algorithm() KeyAlgorithm {
	return KeyAlgorithm{
		name:        algorithm.hash
		name_utf16_: algorithm.hash_utf16_
	}
}

pub fn (algorithm &RsaHashedKeyAlgorithm) name() string {
	return algorithm.name
}

pub fn (algorithm &RsaHashedKeyAlgorithm) modulus_length() u32 {
	return algorithm.modulus_length
}

pub fn (algorithm &RsaHashedKeyAlgorithm) public_exponent() []u8 {
	return algorithm.public_exponent.clone()
}

pub fn (algorithm &RsaHashedKeyAlgorithm) hash() string {
	return algorithm.hash
}

pub struct EcKeyAlgorithm {
pub mut:
	name               string
	name_utf16_        ?libjs.Utf16String
	named_curve        string
	named_curve_utf16_ ?libjs.Utf16String
}

pub fn EcKeyAlgorithm.create() &EcKeyAlgorithm {
	return &EcKeyAlgorithm{}
}

pub fn (mut algorithm EcKeyAlgorithm) set_name(name string) {
	algorithm.name = name
	algorithm.name_utf16_ = none
}

pub fn (mut algorithm EcKeyAlgorithm) set_named_curve(named_curve string) {
	algorithm.named_curve = named_curve
	algorithm.named_curve_utf16_ = none
}

pub fn (algorithm &EcKeyAlgorithm) name() string {
	return algorithm.name
}

pub fn (algorithm &EcKeyAlgorithm) named_curve() string {
	return algorithm.named_curve
}

pub struct AesKeyAlgorithm {
pub mut:
	name        string
	name_utf16_ ?libjs.Utf16String
	length      u16
}

pub fn AesKeyAlgorithm.create() &AesKeyAlgorithm {
	return &AesKeyAlgorithm{}
}

pub fn (mut algorithm AesKeyAlgorithm) set_name(name string) {
	algorithm.name = name
	algorithm.name_utf16_ = none
}

pub fn (mut algorithm AesKeyAlgorithm) set_length(length u16) {
	algorithm.length = length
}

pub fn (algorithm &AesKeyAlgorithm) name() string {
	return algorithm.name
}

pub fn (algorithm &AesKeyAlgorithm) length() u16 {
	return algorithm.length
}

pub struct HmacKeyAlgorithm {
pub mut:
	name        string = 'HMAC'
	name_utf16_ ?libjs.Utf16String
	hash        string
	hash_utf16_ ?libjs.Utf16String
	length      u32
}

pub fn HmacKeyAlgorithm.create() &HmacKeyAlgorithm {
	return &HmacKeyAlgorithm{}
}

pub fn (mut algorithm HmacKeyAlgorithm) set_name(name string) {
	algorithm.name = name
	algorithm.name_utf16_ = none
}

pub fn (mut algorithm HmacKeyAlgorithm) set_hash(hash string) {
	algorithm.hash = hash
	algorithm.hash_utf16_ = none
}

pub fn (mut algorithm HmacKeyAlgorithm) set_length(length u32) {
	algorithm.length = length
}

pub fn (algorithm &HmacKeyAlgorithm) hash_algorithm() KeyAlgorithm {
	return KeyAlgorithm{
		name:        algorithm.hash
		name_utf16_: algorithm.hash_utf16_
	}
}

pub fn (algorithm &HmacKeyAlgorithm) name() string {
	return algorithm.name
}

pub fn (algorithm &HmacKeyAlgorithm) hash() string {
	return algorithm.hash
}

pub fn (algorithm &HmacKeyAlgorithm) length() u32 {
	return algorithm.length
}

pub struct KmacKeyAlgorithm {
pub mut:
	name        string
	name_utf16_ ?libjs.Utf16String
	length      u32
}

pub fn KmacKeyAlgorithm.create() &KmacKeyAlgorithm {
	return &KmacKeyAlgorithm{}
}

pub fn (mut algorithm KmacKeyAlgorithm) set_name(name string) {
	algorithm.name = name
	algorithm.name_utf16_ = none
}

pub fn (mut algorithm KmacKeyAlgorithm) set_length(length u32) {
	algorithm.length = length
}

pub fn (algorithm &KmacKeyAlgorithm) name() string {
	return algorithm.name
}

pub fn (algorithm &KmacKeyAlgorithm) length() u32 {
	return algorithm.length
}

// CryptoKey now stores plain algorithm-data records instead of binding
// objects. Keep the established V names as aliases while exposing the exact
// record surface introduced by CryptoKey.h.
pub type KeyAlgorithmData = KeyAlgorithm

pub type RsaKeyAlgorithmData = RsaKeyAlgorithm

pub type RsaHashedKeyAlgorithmData = RsaHashedKeyAlgorithm

pub type EcKeyAlgorithmData = EcKeyAlgorithm

pub type AesKeyAlgorithmData = AesKeyAlgorithm

pub type HmacKeyAlgorithmData = HmacKeyAlgorithm

pub type KmacKeyAlgorithmData = KmacKeyAlgorithm

pub fn (algorithm &KeyAlgorithmData) name() string {
	return algorithm.name
}

pub fn (algorithm &RsaKeyAlgorithmData) name() string {
	return algorithm.name
}

pub fn (algorithm &RsaKeyAlgorithmData) modulus_length() u32 {
	return algorithm.modulus_length
}

pub fn (algorithm &RsaKeyAlgorithmData) public_exponent() []u8 {
	return algorithm.public_exponent.clone()
}

pub fn (algorithm &RsaHashedKeyAlgorithmData) name() string {
	return algorithm.name
}

pub fn (algorithm &RsaHashedKeyAlgorithmData) modulus_length() u32 {
	return algorithm.modulus_length
}

pub fn (algorithm &RsaHashedKeyAlgorithmData) public_exponent() []u8 {
	return algorithm.public_exponent.clone()
}

pub fn (algorithm &RsaHashedKeyAlgorithmData) hash() string {
	return algorithm.hash
}

pub fn (algorithm &EcKeyAlgorithmData) name() string {
	return algorithm.name
}

pub fn (algorithm &EcKeyAlgorithmData) named_curve() string {
	return algorithm.named_curve
}

pub fn (algorithm &AesKeyAlgorithmData) name() string {
	return algorithm.name
}

pub fn (algorithm &AesKeyAlgorithmData) length() u16 {
	return algorithm.length
}

pub fn (algorithm &HmacKeyAlgorithmData) name() string {
	return algorithm.name
}

pub fn (algorithm &HmacKeyAlgorithmData) hash() string {
	return algorithm.hash
}

pub fn (algorithm &HmacKeyAlgorithmData) length() u32 {
	return algorithm.length
}

pub fn (algorithm &KmacKeyAlgorithmData) name() string {
	return algorithm.name
}

pub fn (algorithm &KmacKeyAlgorithmData) length() u32 {
	return algorithm.length
}

pub type CryptoKeyAlgorithm = AesKeyAlgorithm
	| EcKeyAlgorithm
	| HmacKeyAlgorithm
	| KeyAlgorithm
	| KmacKeyAlgorithm
	| RsaHashedKeyAlgorithm
	| RsaKeyAlgorithm

pub fn (algorithm CryptoKeyAlgorithm) name() string {
	return match algorithm {
		AesKeyAlgorithm { algorithm.name }
		EcKeyAlgorithm { algorithm.name }
		HmacKeyAlgorithm { algorithm.name }
		KeyAlgorithm { algorithm.name }
		KmacKeyAlgorithm { algorithm.name }
		RsaHashedKeyAlgorithm { algorithm.name }
		RsaKeyAlgorithm { algorithm.name }
	}
}

pub fn clone_key_algorithm(algorithm CryptoKeyAlgorithm) CryptoKeyAlgorithm {
	return match algorithm {
		AesKeyAlgorithm {
			CryptoKeyAlgorithm(AesKeyAlgorithm{
				name:        algorithm.name
				name_utf16_: algorithm.name_utf16_
				length:      algorithm.length
			})
		}
		EcKeyAlgorithm {
			CryptoKeyAlgorithm(EcKeyAlgorithm{
				name:               algorithm.name
				name_utf16_:        algorithm.name_utf16_
				named_curve:        algorithm.named_curve
				named_curve_utf16_: algorithm.named_curve_utf16_
			})
		}
		HmacKeyAlgorithm {
			CryptoKeyAlgorithm(HmacKeyAlgorithm{
				name:        algorithm.name
				name_utf16_: algorithm.name_utf16_
				hash:        algorithm.hash
				hash_utf16_: algorithm.hash_utf16_
				length:      algorithm.length
			})
		}
		KeyAlgorithm {
			CryptoKeyAlgorithm(KeyAlgorithm{
				name:        algorithm.name
				name_utf16_: algorithm.name_utf16_
			})
		}
		KmacKeyAlgorithm {
			CryptoKeyAlgorithm(KmacKeyAlgorithm{
				name:        algorithm.name
				name_utf16_: algorithm.name_utf16_
				length:      algorithm.length
			})
		}
		RsaHashedKeyAlgorithm {
			CryptoKeyAlgorithm(RsaHashedKeyAlgorithm{
				name:            algorithm.name
				name_utf16_:     algorithm.name_utf16_
				modulus_length:  algorithm.modulus_length
				public_exponent: algorithm.public_exponent.clone()
				hash:            algorithm.hash
				hash_utf16_:     algorithm.hash_utf16_
			})
		}
		RsaKeyAlgorithm {
			CryptoKeyAlgorithm(RsaKeyAlgorithm{
				name:            algorithm.name
				name_utf16_:     algorithm.name_utf16_
				modulus_length:  algorithm.modulus_length
				public_exponent: algorithm.public_exponent.clone()
			})
		}
	}
}
