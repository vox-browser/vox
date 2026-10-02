// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// CryptoAlgorithms.cpp CShake::digest and LibCrypto/Hash/SHAKE.cpp.
module webcrypto

import crypto.sha3

fn cshake_digest(params CShakeParams, data []u8) ![]u8 {
	// The referenced upstream SHAKE backend supports empty N and S only.
	if (params.function_name or { []u8{} }).len > 0
		|| (params.customization or { []u8{} }).len > 0 {
		return error('OperationError: Hash function failed: cSHAKE with non-empty N or S is not supported yet (OpenSSL EVP limitation)')
	}
	if params.output_length % 8 != 0 {
		return error('OperationError: Hash function failed: SHAKE output length must be a multiple of 8 bits')
	}
	mut shake := match params.name {
		'cSHAKE128' { sha3.new_shake128() }
		'cSHAKE256' { sha3.new_shake256() }
		else { return error('NotSupportedError: Unsupported cSHAKE algorithm') }
	}
	shake.write(data)
	return shake.read(int(params.output_length / 8))
}
