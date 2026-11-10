// SPDX-License-Identifier: BSD-2-Clause
// CryptoAlgorithms.cpp Argon2 import/derive algorithm bodies.
module webcrypto

fn argon2_derive_bits(params Argon2Params, key &CryptoKey, length ?u32) ![]u8 {
	bits := length or { return error('OperationError: Length must be equal or greater than 32') }
	if bits < 32 || bits % 8 != 0 { return error('OperationError: Length must be equal or greater than 32 and a multiple of 8') }
	if version := params.version {
		if version != 19 { return error('OperationError: Invalid algorithm version') }
	}
	if params.parallelism == 0 || params.parallelism > 16777215 {
		return error('OperationError: Invalid parallelism')
	}
	if params.memory < 8 * params.parallelism {
		return error('OperationError: Memory is too low for the parallelism level')
	}
	if params.passes == 0 { return error('OperationError: Invalid passes') }
	return native_argon2(params, key.handle_, bits / 8)
}

fn import_argon2_key(name string, format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey {
	if format != .raw_secret { return error('NotSupportedError: Invalid key format') }
	for usage in usages {
		if usage !in [KeyUsage.derive_key, .derive_bits] {
			return error('SyntaxError: Invalid key usage')
		}
	}
	if extractable { return error('SyntaxError: Key cannot be extractable') }
	return CryptoKey.create(.secret, false, KeyAlgorithm{ name: name }, [], material)
}
