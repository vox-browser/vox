// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// CryptoKey.h::InternalAlgorithmData keeps Utf16String slots. Compatibility
// string fields remain available to the earlier algorithm adapters.
module webcrypto

import libjs

fn crypto_algorithm_utf16(text string, original ?libjs.Utf16String) libjs.Utf16String {
	if value := original {
		if value.str() == text { return value }
	}
	return libjs.utf16_string(text)
}

pub fn (algorithm CryptoKeyAlgorithm) name_utf16() libjs.Utf16String {
	return match algorithm {
		AesKeyAlgorithm { crypto_algorithm_utf16(algorithm.name, algorithm.name_utf16_) }
		EcKeyAlgorithm { crypto_algorithm_utf16(algorithm.name, algorithm.name_utf16_) }
		HmacKeyAlgorithm { crypto_algorithm_utf16(algorithm.name, algorithm.name_utf16_) }
		KeyAlgorithm { crypto_algorithm_utf16(algorithm.name, algorithm.name_utf16_) }
		KmacKeyAlgorithm { crypto_algorithm_utf16(algorithm.name, algorithm.name_utf16_) }
		RsaHashedKeyAlgorithm { crypto_algorithm_utf16(algorithm.name, algorithm.name_utf16_) }
		RsaKeyAlgorithm { crypto_algorithm_utf16(algorithm.name, algorithm.name_utf16_) }
	}
}

pub fn (algorithm &EcKeyAlgorithm) named_curve_utf16() libjs.Utf16String {
	return crypto_algorithm_utf16(algorithm.named_curve, algorithm.named_curve_utf16_)
}

pub fn (algorithm &HmacKeyAlgorithm) hash_utf16() libjs.Utf16String {
	return crypto_algorithm_utf16(algorithm.hash, algorithm.hash_utf16_)
}

pub fn (algorithm &RsaHashedKeyAlgorithm) hash_utf16() libjs.Utf16String {
	return crypto_algorithm_utf16(algorithm.hash, algorithm.hash_utf16_)
}
