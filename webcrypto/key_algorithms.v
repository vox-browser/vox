// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Crypto/KeyAlgorithms.{h,cpp}.
module webcrypto

pub struct KeyAlgorithm {
pub mut:
	name     string
	realm_id u64
}

pub fn KeyAlgorithm.create() &KeyAlgorithm {
	return &KeyAlgorithm{}
}

pub fn (mut algorithm KeyAlgorithm) set_name(name string) {
	algorithm.name = name
}

pub struct RsaKeyAlgorithm {
pub mut:
	name            string
	modulus_length  u32
	public_exponent []u8
}

pub fn RsaKeyAlgorithm.create() &RsaKeyAlgorithm {
	return &RsaKeyAlgorithm{}
}

pub fn (mut algorithm RsaKeyAlgorithm) set_name(name string) {
	algorithm.name = name
}

pub fn (mut algorithm RsaKeyAlgorithm) set_modulus_length(modulus_length u32) {
	algorithm.modulus_length = modulus_length
}

fn unsigned_big_integer_bytes(bytes []u8) []u8 {
	mut first_nonzero := 0
	for first_nonzero < bytes.len && bytes[first_nonzero] == 0 {
		first_nonzero++
	}
	return bytes[first_nonzero..].clone()
}

// BigInteger is exposed to WebIDL as an unsigned, big-endian Uint8Array.
pub fn (mut algorithm RsaKeyAlgorithm) set_public_exponent(exponent []u8) {
	algorithm.public_exponent = unsigned_big_integer_bytes(exponent)
}

pub struct RsaHashedKeyAlgorithm {
pub mut:
	name            string
	modulus_length  u32
	public_exponent []u8
	hash            string
}

pub fn RsaHashedKeyAlgorithm.create() &RsaHashedKeyAlgorithm {
	return &RsaHashedKeyAlgorithm{}
}

pub fn (mut algorithm RsaHashedKeyAlgorithm) set_name(name string) {
	algorithm.name = name
}

pub fn (mut algorithm RsaHashedKeyAlgorithm) set_modulus_length(modulus_length u32) {
	algorithm.modulus_length = modulus_length
}

pub fn (mut algorithm RsaHashedKeyAlgorithm) set_public_exponent(exponent []u8) {
	algorithm.public_exponent = unsigned_big_integer_bytes(exponent)
}

pub fn (mut algorithm RsaHashedKeyAlgorithm) set_hash(hash string) {
	algorithm.hash = hash
}

pub fn (algorithm &RsaHashedKeyAlgorithm) hash_algorithm() KeyAlgorithm {
	return KeyAlgorithm{
		name: algorithm.hash
	}
}

pub struct EcKeyAlgorithm {
pub mut:
	name        string
	named_curve string
}

pub fn EcKeyAlgorithm.create() &EcKeyAlgorithm {
	return &EcKeyAlgorithm{}
}

pub fn (mut algorithm EcKeyAlgorithm) set_name(name string) {
	algorithm.name = name
}

pub fn (mut algorithm EcKeyAlgorithm) set_named_curve(named_curve string) {
	algorithm.named_curve = named_curve
}

pub struct AesKeyAlgorithm {
pub mut:
	name   string
	length u16
}

pub fn AesKeyAlgorithm.create() &AesKeyAlgorithm {
	return &AesKeyAlgorithm{}
}

pub fn (mut algorithm AesKeyAlgorithm) set_name(name string) {
	algorithm.name = name
}

pub fn (mut algorithm AesKeyAlgorithm) set_length(length u16) {
	algorithm.length = length
}

pub struct HmacKeyAlgorithm {
pub mut:
	name   string = 'HMAC'
	hash   string
	length u32
}

pub fn HmacKeyAlgorithm.create() &HmacKeyAlgorithm {
	return &HmacKeyAlgorithm{}
}

pub fn (mut algorithm HmacKeyAlgorithm) set_name(name string) {
	algorithm.name = name
}

pub fn (mut algorithm HmacKeyAlgorithm) set_hash(hash string) {
	algorithm.hash = hash
}

pub fn (mut algorithm HmacKeyAlgorithm) set_length(length u32) {
	algorithm.length = length
}

pub fn (algorithm &HmacKeyAlgorithm) hash_algorithm() KeyAlgorithm {
	return KeyAlgorithm{
		name: algorithm.hash
	}
}

pub struct KmacKeyAlgorithm {
pub mut:
	name   string
	length u32
}

pub fn KmacKeyAlgorithm.create() &KmacKeyAlgorithm {
	return &KmacKeyAlgorithm{}
}

pub fn (mut algorithm KmacKeyAlgorithm) set_name(name string) {
	algorithm.name = name
}

pub fn (mut algorithm KmacKeyAlgorithm) set_length(length u32) {
	algorithm.length = length
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
				name:   algorithm.name
				length: algorithm.length
			})
		}
		EcKeyAlgorithm {
			CryptoKeyAlgorithm(EcKeyAlgorithm{
				name:        algorithm.name
				named_curve: algorithm.named_curve
			})
		}
		HmacKeyAlgorithm {
			CryptoKeyAlgorithm(HmacKeyAlgorithm{
				name:   algorithm.name
				hash:   algorithm.hash
				length: algorithm.length
			})
		}
		KeyAlgorithm {
			CryptoKeyAlgorithm(KeyAlgorithm{
				name: algorithm.name
			})
		}
		KmacKeyAlgorithm {
			CryptoKeyAlgorithm(KmacKeyAlgorithm{
				name:   algorithm.name
				length: algorithm.length
			})
		}
		RsaHashedKeyAlgorithm {
			CryptoKeyAlgorithm(RsaHashedKeyAlgorithm{
				name:            algorithm.name
				modulus_length:  algorithm.modulus_length
				public_exponent: algorithm.public_exponent.clone()
				hash:            algorithm.hash
			})
		}
		RsaKeyAlgorithm {
			CryptoKeyAlgorithm(RsaKeyAlgorithm{
				name:            algorithm.name
				modulus_length:  algorithm.modulus_length
				public_exponent: algorithm.public_exponent.clone()
			})
		}
	}
}
