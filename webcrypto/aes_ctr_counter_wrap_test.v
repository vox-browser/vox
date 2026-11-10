// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

// Ladybird 8ad19f25a83a8894f781c14a5fd13948fcbcaf71.
fn test_aes_ctr_low_counter_bits_wrap_without_carrying_into_the_nonce() {
	subtle := SubtleCrypto.create()
	key := subtle.import_key(.raw, []u8{len: 16}, 'AES-CTR', false, [.encrypt, .decrypt], '')!
	for length in [u8(1), 4, 8, 9, 128] {
		mut counter := []u8{len: 16, init: 0xab}
		mut wrapped := counter.clone()
		match length {
			1 { counter[15] = 0xab; wrapped[15] = 0xaa }
			4 { counter[15] = 0xaf; wrapped[15] = 0xa0 }
			8 { counter[15] = 0xff; wrapped[15] = 0 }
			9 { counter[15] = 0xff; wrapped[14] = 0xaa; wrapped[15] = 0 }
			else { counter = []u8{len: 16, init: 0xff}; wrapped = []u8{len: 16} }
		}
		params := AesCtrParams{ counter: counter, length: length }
		plaintext := []u8{len: 32, init: u8(index)}
		ciphertext := subtle.encrypt(params, key, plaintext)!
		assert ciphertext[..16] == subtle.encrypt(AesCtrParams{ counter: counter, length: 128 }, key, plaintext[..16])!
		assert ciphertext[16..] == subtle.encrypt(AesCtrParams{ counter: wrapped, length: 128 }, key, plaintext[16..])!
		assert subtle.decrypt(params, key, ciphertext)! == plaintext
		assert params.counter == counter
	}
}

fn test_aes_ctr_counter_wrap_preserves_partial_final_blocks_and_full_width_carry() {
	subtle := SubtleCrypto.create()
	key := subtle.import_key(.raw, []u8{len: 16}, 'AES-CTR', false, [.encrypt, .decrypt], '')!
	mut counter := []u8{len: 16, init: 0xab}
	counter[15] = 0xff
	mut wrapped := counter.clone()
	wrapped[15] = 0
	mut next := wrapped.clone()
	next[15] = 1
	plaintext := []u8{len: 40, init: u8(index)}
	params := AesCtrParams{ counter: counter, length: 8 }
	ciphertext := subtle.encrypt(params, key, plaintext)!
	assert ciphertext[16..32] == subtle.encrypt(AesCtrParams{ counter: wrapped, length: 128 }, key, plaintext[16..32])!
	assert ciphertext[32..] == subtle.encrypt(AesCtrParams{ counter: next, length: 128 }, key, plaintext[32..])!
	assert subtle.decrypt(params, key, ciphertext)! == plaintext
	mut carried := wrapped.clone()
	carried[14] = 0xac
	full := subtle.encrypt(AesCtrParams{ counter: counter, length: 128 }, key, plaintext)!
	assert full[16..32] == subtle.encrypt(AesCtrParams{ counter: carried, length: 128 }, key, plaintext[16..32])!
	assert ciphertext[16..32] != full[16..32]
}
