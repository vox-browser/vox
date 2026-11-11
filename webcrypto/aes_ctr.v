// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
// CryptoAlgorithms.cpp AesCtr::{encrypt,decrypt} operation bodies.
module webcrypto

fn aes_ctr_crypt(params AesCtrParams, key &CryptoKey, input []u8, decrypt bool) ![]u8 {
	if params.counter.len != 16 { return error('OperationError: Invalid counter length') }
	if params.length == 0 || params.length > 128 { return error('OperationError: Invalid length') }
	if input.len == 0 { return native_aes_ctr(decrypt, key.handle_, input, params.counter) }
	// WebCrypto permits wrapping the selected counter bits, but an operation
	// must not consume more than the counter space or it would repeat keystream.
	required_blocks := (u64(input.len) + 15) / 16
	if params.length < 64 && required_blocks > (u64(1) << params.length) {
		return error('OperationError: AES-CTR counter would repeat')
	}
	// EVP increments the whole block. Restart it when the low length bits wrap
	// so carries cannot change the nonce portion of the counter.
	mut counter := params.counter.clone()
	mut output := []u8{cap: input.len}
	mut offset := 0
	for offset < input.len {
		length := aes_ctr_bytes_before_wrap(counter, params.length, input.len - offset)
		output << native_aes_ctr(decrypt, key.handle_, input[offset..offset + length], counter)!
		offset += length
		whole_bytes := int(params.length) / 8
		for index in 16 - whole_bytes .. 16 { counter[index] = 0 }
		partial_bits := int(params.length) % 8
		if partial_bits != 0 { counter[15 - whole_bytes] &= u8(0xff << partial_bits) }
	}
	return output
}

// Compute 2^length - counter's low bits, saturating at the remaining block
// count. This avoids a 128-bit integer and overflow for full-width counters.
fn aes_ctr_bytes_before_wrap(counter []u8, length u8, remaining int) int {
	maximum_blocks := (u64(remaining) + 15) / 16
	mut blocks := u64(0)
	mut bit := int(length)
	for bit > 0 {
		if blocks >= maximum_blocks { return remaining }
		bit--
		counter_bit := (counter[15 - bit / 8] >> (bit % 8)) & 1
		blocks = (blocks << 1) | u64(counter_bit ^ 1)
	}
	blocks++
	return if blocks >= maximum_blocks { remaining } else { int(blocks * 16) }
}
