// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

import encoding.hex
import webidl

fn test_aes_kw_native_upstream_key_and_plaintext_width_vectors() {
	subtle := SubtleCrypto.create()
	for vector in aes_kw_source_vectors {
		key := subtle.import_key(.raw_secret, hex.decode(vector.key_hex)!, 'AES-KW', false, [
			.wrap_key,
			.unwrap_key,
		], '')!
		plaintext := hex.decode(vector.input_hex)!
		ciphertext := aes_key_wrap(key, plaintext)!
		assert ciphertext.hex() == vector.output_hex
		assert aes_key_unwrap(key, ciphertext)! == plaintext
		mut corrupt := ciphertext.clone()
		corrupt[0] ^= 1
		if _ := aes_key_unwrap(key, corrupt) {
			assert false
		} else {
			assert err.msg() == 'OperationError: Key unwrap failed'
		}
	}
}

fn test_aes_kw_source_input_checks_precede_native_validation() {
	key := CryptoKey.create(.secret, false, KeyAlgorithm{}, [], [])
	for size in [1, 7, 9, 15, 17] {
		if _ := aes_key_wrap(key, []u8{len: size}) {
			assert false
		} else {
			assert err.msg() == 'OperationError: Invalid plaintext length'
		}
	}
	for size in [0, 1, 7] {
		if _ := aes_key_unwrap(key, []u8{len: size}) {
			assert false
		} else {
			assert err.msg() == 'OperationError: Invalid ciphertext length'
		}
	}
	if _ := aes_key_wrap(key, []u8{len: 16}) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Key wrap failed'
	}
	if _ := aes_key_unwrap(key, []u8{len: 24}) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Key unwrap failed'
	}
	valid := SubtleCrypto.create().import_key(.raw, []u8{len: 16}, 'AES-KW', false, [
		.wrap_key,
		.unwrap_key,
	], '')!
	assert aes_key_wrap(valid, [])!.len == 0
	if _ := aes_key_wrap(valid, []u8{len: 8}) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Key wrap failed'
	}
	for size in [8, 9, 16, 17, 23] {
		if _ := aes_key_unwrap(valid, []u8{len: size}) {
			assert false
		} else {
			assert err.msg() == 'OperationError: Key unwrap failed'
		}
	}
}

@[heap]
struct AesKwBindingHost {
mut:
	work   []fn ()
	settle []fn ()
}

fn test_aes_kw_async_wrap_unwrap_actual_provider_and_copied_ciphertext() {
	mut host := &AesKwBindingHost{}
	subtle := SubtleCrypto.create()
	binding := SubtleCryptoBinding.create(subtle, webidl.PromiseContext{}, fn [mut host] (task fn ()) {
		host.work << task
	}, fn [mut host] (task fn ()) {
		host.settle << task
	})
	vector := aes_kw_source_vectors[0]
	wrapping_key := subtle.import_key(.raw, hex.decode(vector.key_hex)!, 'AES-KW', false, [
		.wrap_key,
		.unwrap_key,
	], '')!
	content := subtle.import_key(.raw, hex.decode(vector.input_hex)!, 'AES-GCM', true, [
		.encrypt,
	], '')!
	wrapped := binding.wrap_key(.raw, content, wrapping_key, webidl.string_value('AES-KW'))
	assert wrapped.state == .pending
	host.work[0]()
	assert wrapped.state == .fulfilled
	assert host.settle.len == 0
	assert webidl.get_buffer_source_copy(wrapped.result.buffer_value or { panic('bytes') }).hex() == vector.output_hex
	mut input := webidl.BufferSource.array_buffer(hex.decode(vector.output_hex)!)
	unwrapped := binding.unwrap_key(.raw, input, wrapping_key, webidl.string_value('AES-KW'),
		webidl.string_value('AES-GCM'), true, [.encrypt])
	input.write([]u8{len: int(input.byte_length())}, 0)!
	assert unwrapped.state == .pending
	host.work[1]()
	assert host.settle.len == 0
	assert unwrapped.state == .fulfilled
	imported := crypto_key_from_value(unwrapped.result)!
	assert imported.handle() == content.handle()
}

struct AesKwSourceVector {
	key_hex    string
	input_hex  string
	output_hex string
}

// Exact upstream TestAES.cpp RFC3394 key-wrap fixtures.
const aes_kw_source_vectors = [
	AesKwSourceVector{
		key_hex:    '000102030405060708090a0b0c0d0e0f'
		input_hex:  '00112233445566778899aabbccddeeff'
		output_hex: '1fa68b0a8112b447aef34bd8fb5a7b829d3e862371d2cfe5'
	},
	AesKwSourceVector{
		key_hex:    '000102030405060708090a0b0c0d0e0f1011121314151617'
		input_hex:  '00112233445566778899aabbccddeeff'
		output_hex: '96778b25ae6ca435f92b5b97c050aed2468ab8a17ad84e5d'
	},
	AesKwSourceVector{
		key_hex:    '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f'
		input_hex:  '00112233445566778899aabbccddeeff'
		output_hex: '64e8c3f9ce0f5ba263e9777905818a2a93c8191e7d6e8ae7'
	},
	AesKwSourceVector{
		key_hex:    '000102030405060708090a0b0c0d0e0f1011121314151617'
		input_hex:  '00112233445566778899aabbccddeeff0001020304050607'
		output_hex: '031d33264e15d33268f24ec260743edce1c6c7ddee725a936ba814915c6762d2'
	},
	AesKwSourceVector{
		key_hex:    '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f'
		input_hex:  '00112233445566778899aabbccddeeff0001020304050607'
		output_hex: 'a8f9bc1612c68b3ff6e6f4fbe30e71e4769c8b80a32cb8958cd5d17d6b254da1'
	},
	AesKwSourceVector{
		key_hex:    '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f'
		input_hex:  '00112233445566778899aabbccddeeff000102030405060708090a0b0c0d0e0f'
		output_hex: '28c9f404c4b810f4cbccb35cfb87f8263f5786e2d80ed326cbc7f0e71a99f43bfb988b9b7a02dd21'
	},
]
