// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

import encoding.hex
import webidl

fn test_aes_cbc_native_upstream_vectors_with_pkcs7_padding() {
	subtle := SubtleCrypto.create()
	plaintext := 'This is a test! This is another test!'.bytes()
	for vector in aes_cbc_source_vectors {
		key := subtle.import_key(.raw, hex.decode(vector.key_hex)!, 'AES-CBC', false, [
			.encrypt,
			.decrypt,
		], '')!
		params := AesCbcParams{ iv: []u8{len: 16} }
		ciphertext := subtle.encrypt(params, key, plaintext)!
		assert ciphertext.hex() == vector.ciphertext_hex
		assert subtle.decrypt(params, key, ciphertext)! == plaintext
		assert subtle.decrypt(params, key, subtle.encrypt(params, key, [])!)!.len == 0
		assert subtle.encrypt(params, key, []u8{len: 16})!.len == 32
	}
}

fn test_aes_cbc_source_validation_and_native_padding_failures() {
	key := CryptoKey.create(.secret, false, KeyAlgorithm{}, [], [])
	if _ := AesCbc.create().encrypt(AesCbcParams{}, key, []) {
		assert false
	} else {
		assert err.msg() == 'OperationError: IV to AES-CBC must be exactly 16 bytes'
	}
	if _ := AesCbc.create().decrypt(AesCbcParams{}, key, []) {
		assert false
	} else {
		assert err.msg() == 'OperationError: IV to AES-CBC must be exactly 16 bytes'
	}
	params := AesCbcParams{ iv: []u8{len: 16} }
	for size in [0, 15, 17] {
		if _ := AesCbc.create().decrypt(params, key, []u8{len: size}) {
			assert false
		} else {
			assert err.msg() == 'OperationError: Ciphertext length must be a multiple of 16 bytes'
		}
	}
	if _ := AesCbc.create().encrypt(params, key, []) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Failed to encrypt'
	}
	valid := SubtleCrypto.create().import_key(.raw, []u8{len: 16}, 'AES-CBC', false, [
		.encrypt,
		.decrypt,
	], '')!
	for last in [u8(0), 17] {
		mut payload := []u8{len: 16}
		payload[15] = last
		encrypted := native_aes_cbc(false, true, valid.handle(), payload, params.iv)!
		if _ := AesCbc.create().decrypt(params, valid, encrypted) {
			assert false
		} else {
			assert err.msg() == 'OperationError: Failed to decrypt'
		}
	}
	mut inconsistent := []u8{len: 16, init: 2}
	inconsistent[14] = 1
	encrypted := native_aes_cbc(false, true, valid.handle(), inconsistent, params.iv)!
	if _ := AesCbc.create().decrypt(params, valid, encrypted) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Failed to decrypt'
	}
}

@[heap]
struct AesCbcBindingHost {
mut:
	work   []fn ()
	settle []fn ()
}

fn test_aes_cbc_binding_copies_iv_plaintext_and_crypto_settlement() {
	mut host := &AesCbcBindingHost{}
	subtle := SubtleCrypto.create()
	binding := SubtleCryptoBinding.create(subtle, webidl.PromiseContext{}, fn [mut host] (task fn ()) {
		host.work << task
	}, fn [mut host] (task fn ()) { host.settle << task })
	key := subtle.import_key(.raw_secret, 'WellHelloFriends'.bytes(), 'AES-CBC', false, [
		.encrypt,
		.decrypt,
	], '')!
	mut iv := webidl.BufferSource.array_buffer([]u8{len: 16})
	mut plaintext := webidl.BufferSource.array_buffer('This is a test! This is another test!'.bytes())
	algorithm := webidl.object_value({
		'name': webidl.string_value('AES-CBC')
		'iv':   webidl.buffer_source_value(iv)
	})
	promise := binding.encrypt(algorithm, key, plaintext)
	iv.write([]u8{len: 16, init: 7}, 0)!
	plaintext.write([]u8{len: int(plaintext.byte_length())}, 0)!
	assert promise.state == .pending
	host.work[0]()
	assert promise.state == .pending
	host.settle[0]()
	assert webidl.get_buffer_source_copy(promise.result.buffer_value or { panic('bytes') }).hex() == aes_cbc_source_vectors[0].ciphertext_hex
}

struct AesCbcSourceVector {
	key_hex        string
	ciphertext_hex string
}

const aes_cbc_source_vectors = [
	AesCbcSourceVector{ key_hex: '57656c6c48656c6c6f467269656e6473', ciphertext_hex: 'b8067cf2a95663582d5ca14bc5e308cfb593fb67b6f7af453464709ec91a8bd37045f07965cab90388721cddab456b1c' },
	AesCbcSourceVector{ key_hex: '57656c6c2048656c6c6f20467269656e6473212077686621', ciphertext_hex: 'aed270c49caa8333d3d3ac116535f719487c7a8a9564e7c60adf1006dc90685109d73b481b8ad35009bafcde11e03fcb' },
	AesCbcSourceVector{ key_hex: '57656c6c48656c6c6f467269656e647357656c6c48656c6c6f467269656e6473', ciphertext_hex: '0a444d629e8bd81180482a325361e75962559ef4e6adeac50bf6bc6acb9c479fc221e61962c375caab2d18a154d141e6' },
	AesCbcSourceVector{ key_hex: '0a8c5b0d8a6843f7afc0e34e4b43aa28699b6fe724821c7186f62b87d68b8ff1', ciphertext_hex: '1871804c2807553c0533363f19385cbef8b80e0e6667639cbf73cd82f9cb9d8156c675148b7960b0dfaa2c2bd4d6a046' },
]
