// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

import webidl

fn test_argon2_native_source_rfc9106_secret_and_associated_data_vectors() {
	key_argon2d := SubtleCrypto.create().import_key(.raw_secret, []u8{len: 32, init: 1}, 'Argon2d', false, [
		.derive_bits,
		.derive_key,
	], '')!
	params_argon2d := Argon2Params{ name: 'Argon2d', nonce: []u8{len: 16, init: 2}, parallelism: 4, memory: 32, passes: 3, secret_value: []u8{len: 8, init: 3}, associated_data: []u8{len: 12, init: 4} }
	assert SubtleCrypto.create().derive_bits(params_argon2d, key_argon2d, 256)!.hex() == '512b391b6f1162975371d30919734294f868e3be3984f3c1a13a4db9fabe4acb'
	assert SubtleCrypto.create().derive_key(params_argon2d, key_argon2d, 'AES-GCM', 256, false, [.encrypt])!.handle().hex() == '512b391b6f1162975371d30919734294f868e3be3984f3c1a13a4db9fabe4acb'
	key_argon2i := SubtleCrypto.create().import_key(.raw_secret, []u8{len: 32, init: 1}, 'Argon2i', false, [
		.derive_bits,
		.derive_key,
	], '')!
	params_argon2i := Argon2Params{ name: 'Argon2i', nonce: []u8{len: 16, init: 2}, parallelism: 4, memory: 32, passes: 3, secret_value: []u8{len: 8, init: 3}, associated_data: []u8{len: 12, init: 4} }
	assert SubtleCrypto.create().derive_bits(params_argon2i, key_argon2i, 256)!.hex() == 'c814d9d1dc7f37aa13f0d77f2494bda1c8de6b016dd388d29952a4c4672b6ce8'
	assert SubtleCrypto.create().derive_key(params_argon2i, key_argon2i, 'AES-GCM', 256, false, [.encrypt])!.handle().hex() == 'c814d9d1dc7f37aa13f0d77f2494bda1c8de6b016dd388d29952a4c4672b6ce8'
	key_argon2id := SubtleCrypto.create().import_key(.raw_secret, []u8{len: 32, init: 1}, 'Argon2id', false, [
		.derive_bits,
		.derive_key,
	], '')!
	params_argon2id := Argon2Params{ name: 'Argon2id', nonce: []u8{len: 16, init: 2}, parallelism: 4, memory: 32, passes: 3, secret_value: []u8{len: 8, init: 3}, associated_data: []u8{len: 12, init: 4} }
	assert SubtleCrypto.create().derive_bits(params_argon2id, key_argon2id, 256)!.hex() == '0d640df58d78766c08c037a34a8b53c9d01ef0452d75b65eb52520e96b01e659'
	assert SubtleCrypto.create().derive_key(params_argon2id, key_argon2id, 'AES-GCM', 256, false, [.encrypt])!.handle().hex() == '0d640df58d78766c08c037a34a8b53c9d01ef0452d75b65eb52520e96b01e659'
}

fn test_argon2_source_validation_order_and_non_byte_aligned_length() {
	key := CryptoKey.create(.secret, false, KeyAlgorithm{ name: 'Argon2id' }, [], 'password'.bytes())
	params := Argon2Params{ name: 'Argon2id', nonce: 'salt1234'.bytes(), parallelism: 1, memory: 8, passes: 1 }
	if _ := Argon2.create().derive_bits(Argon2Params{ ...params, version: u8(18), parallelism: 0 }, key, none) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Length must be equal or greater than 32'
	}
	if _ := Argon2.create().derive_bits(Argon2Params{ ...params, version: u8(18), parallelism: 0 }, key, 31) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Length must be equal or greater than 32 and a multiple of 8'
	}
	if _ := Argon2.create().derive_bits(Argon2Params{ ...params, version: u8(18), parallelism: 0 }, key, 32) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Invalid algorithm version'
	}
	for lanes in [u32(0), 16777216] {
		if _ := Argon2.create().derive_bits(Argon2Params{ ...params, parallelism: lanes, memory: 0, passes: 0 }, key, 32) {
			assert false
		} else {
			assert err.msg() == 'OperationError: Invalid parallelism'
		}
	}
	if _ := Argon2.create().derive_bits(Argon2Params{ ...params, memory: 7, passes: 0 }, key, 32) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Memory is too low for the parallelism level'
	}
	if _ := Argon2.create().derive_bits(Argon2Params{ ...params, passes: 0 }, key, 32) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Invalid passes'
	}
	assert Argon2.create().derive_bits(params, key, 32)!.len == 4
	for length in [u32(33), 39] {
		if _ := Argon2.create().derive_bits(params, key, length) {
			assert false
		} else {
			assert err.msg() == 'OperationError: Length must be equal or greater than 32 and a multiple of 8'
		}
	}
	assert Argon2.create().derive_bits(Argon2Params{ ...params, version: u8(19), parallelism: 256, memory: 2048 }, key, 32)!.len == 4
	if _ := Argon2.create().derive_bits(Argon2Params{ ...params, nonce: [] }, key, 32) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Hashing function failed: EVP_KDF_derive(ctx.ptr(), buf.data(), tag_length, params) failed'
	}
	if _ := Argon2.create().import_key(AlgorithmParams{ name: 'Argon2id' }, .raw, [], true, [.sign]) {
		assert false
	} else {
		assert err.msg() == 'NotSupportedError: Invalid key format'
	}
	if _ := Argon2.create().import_key(AlgorithmParams{ name: 'Argon2id' }, .raw_secret, [], true, [.sign]) {
		assert false
	} else {
		assert err.msg() == 'SyntaxError: Invalid key usage'
	}
	if _ := Argon2.create().import_key(AlgorithmParams{ name: 'Argon2id' }, .raw_secret, [], true, [.derive_bits]) {
		assert false
	} else {
		assert err.msg() == 'SyntaxError: Key cannot be extractable'
	}
	assert Argon2.create().import_key(AlgorithmParams{ name: 'Argon2id' }, .raw_secret, [], false, [])!.usages.len == 0
	if _ := SubtleCrypto.create().import_key(.raw_secret, [], 'Argon2id', false, [], '') {
		assert false
	} else {
		assert err.msg() == 'SyntaxError: usages must not be empty'
	}
}

@[heap]
struct Argon2BindingHost {
mut:
	work   []fn ()
	settle []fn ()
}

fn test_argon2_binding_copies_nonce_secret_ad_and_defers_validation() {
	mut host := &Argon2BindingHost{}
	subtle := SubtleCrypto.create()
	binding := SubtleCryptoBinding.create(subtle, webidl.PromiseContext{}, fn [mut host] (task fn ()) {
		host.work << task
	}, fn [mut host] (task fn ()) { host.settle << task })
	key := subtle.import_key(.raw_secret, []u8{len: 32, init: 1}, 'Argon2id', false, [.derive_bits], '')!
	mut nonce := webidl.BufferSource.array_buffer([]u8{len: 16, init: 2})
	mut secret := webidl.BufferSource.array_buffer([]u8{len: 8, init: 3})
	mut ad := webidl.BufferSource.array_buffer([]u8{len: 12, init: 4})
	algorithm := webidl.object_value({
		'name':           webidl.string_value('Argon2id')
		'nonce':          webidl.buffer_source_value(nonce)
		'secretValue':    webidl.buffer_source_value(secret)
		'associatedData': webidl.buffer_source_value(ad)
		'parallelism':    webidl.number_value(4)
		'memory':         webidl.number_value(32)
		'passes':         webidl.number_value(3)
	})
	promise := binding.derive_bits(algorithm, key, 256)
	nonce.write([u8(9)], 0)!
	secret.write([u8(9)], 0)!
	ad.write([u8(9)], 0)!
	assert promise.state == .pending
	host.work[0]()
	assert promise.state == .fulfilled && host.settle.len == 0
	bytes := promise.result.buffer_value or { panic('bytes') }
	assert webidl.get_buffer_source_copy(bytes).hex() == '0d640df58d78766c08c037a34a8b53c9d01ef0452d75b65eb52520e96b01e659'
	missing := binding.derive_bits(algorithm, key, none)
	assert missing.state == .pending
	host.work[1]()
	assert missing.state == .rejected && missing.result.object_value['message'].string_value == 'Length must be equal or greater than 32'
}
