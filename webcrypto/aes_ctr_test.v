// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

import encoding.hex
import webidl

fn test_aes_ctr_native_source_vectors_with_full_width_counter() {
	subtle := SubtleCrypto.create()
	for vector in aes_ctr_source_vectors {
		key := subtle.import_key(.raw, hex.decode(vector.key_hex)!, 'AES-CTR', false, [
			.encrypt,
			.decrypt,
		], '')!
		input := hex.decode(vector.input_hex)!
		for length in [u8(128)] {
			params := AesCtrParams{ counter: hex.decode(vector.iv_hex)!, length: length }
			output := subtle.encrypt(params, key, input)!
			assert output.hex() == vector.output_hex
			assert subtle.decrypt(params, key, output)! == input
		}
		assert subtle.encrypt(AesCtrParams{ counter: hex.decode(vector.iv_hex)!, length: 1 }, key, [])!.len == 0
	}
}

fn test_aes_ctr_source_counter_length_precedes_width_and_provider_failures() {
	key := CryptoKey.create(.secret, false, KeyAlgorithm{}, [], [])
	for decrypt in [false, true] {
		if _ := aes_ctr_crypt(AesCtrParams{}, key, [], decrypt) {
			assert false
		} else {
			assert err.msg() == 'OperationError: Invalid counter length'
		}
		for length in [u8(0), 129, 255] {
			if _ := aes_ctr_crypt(AesCtrParams{ counter: []u8{len: 16}, length: length }, key, [], decrypt) {
				assert false
			} else {
				assert err.msg() == 'OperationError: Invalid length'
			}
		}
		if _ := aes_ctr_crypt(AesCtrParams{ counter: []u8{len: 16}, length: 1 }, key, [], decrypt) {
			assert false
		} else {
			action := if decrypt { 'Decryption' } else { 'Encryption' }
			assert err.msg() == 'OperationError: ${action} failed'
		}
	}
}

@[heap]
struct AesCtrBindingHost {
mut:
	work   []fn ()
	settle []fn ()
}

fn test_aes_ctr_deferred_native_operation_copies_counter_and_length() {
	mut host := &AesCtrBindingHost{}
	subtle := SubtleCrypto.create()
	binding := SubtleCryptoBinding.create(subtle, webidl.PromiseContext{}, fn [mut host] (task fn ()) {
		host.work << task
	}, fn [mut host] (task fn ()) { host.settle << task })
	vector := aes_ctr_source_vectors.last()
	key := subtle.import_key(.raw_secret, hex.decode(vector.key_hex)!, 'AES-CTR', false, [.encrypt], '')!
	mut counter := webidl.BufferSource.array_buffer(hex.decode(vector.iv_hex)!)
	mut plaintext := webidl.BufferSource.array_buffer(hex.decode(vector.input_hex)!)
	mut members := {
		'name':    webidl.string_value('AES-CTR')
		'counter': webidl.buffer_source_value(counter)
		'length':  webidl.number_value(128)
	}
	promise := binding.encrypt(webidl.object_value(members), key, plaintext)
	counter.write([]u8{len: 16}, 0)!
	plaintext.write([]u8{len: int(plaintext.byte_length())}, 0)!
	members['length'] = webidl.number_value(0)
	host.work[0]()
	assert promise.state == .pending
	host.settle[0]()
	assert webidl.get_buffer_source_copy(promise.result.buffer_value or { panic('bytes') }).hex() == vector.output_hex
}

struct AesCtrSourceVector {
	key_hex    string
	iv_hex     string
	input_hex  string
	output_hex string
}

// Exact upstream LibCrypto AES CTR fixtures, including overflow and partial blocks.
const aes_ctr_source_vectors = [
	AesCtrSourceVector{ key_hex: 'ae6852f8121067cc4bf7a5765577f39e', iv_hex: '00000030000000000000000000000001', input_hex: '53696e676c6520626c6f636b206d7367', output_hex: 'e4095d4fb7a7b3792d6175a3261311b8' },
	AesCtrSourceVector{ key_hex: '7e24067817fae0d743d6ce1f32539163', iv_hex: '006cb6dbc0543b59da48d90b00000001', input_hex: '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f', output_hex: '5104a106168a72d9790d41ee8edad388eb2e1efc46da57c8fce630df9141be28' },
	AesCtrSourceVector{ key_hex: '7691be035e5020a8ac6e618529f9a0dc', iv_hex: '00e0017b27777f3f4a1786f000000001', input_hex: '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20212223', output_hex: 'c1cf48a89f2ffdd9cf4652e9efdb72d74540a42bde6d7836d59a5ceaaef3105325b2072f' },
	AesCtrSourceVector{ key_hex: '7c5cb2401b3dc33c19e7340819e0f69c678c3db8e6f6a91a', iv_hex: '0096b03b020c6eadc2cb500d00000001', input_hex: '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f', output_hex: '453243fc609b23327edfaafa7131cd9f8490701c5ad4a79cfc1fe0ff42f4fb00' },
	AesCtrSourceVector{ key_hex: '02bf391ee8ecb159b959617b0965279bf59b60a786d3e0fe', iv_hex: '0007bdfd5cbd60278dcc091200000001', input_hex: '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20212223', output_hex: '96893fc55e5c722f540b7dd1ddf7e758d288bc95c69165884536c811662f2188abee0935' },
	AesCtrSourceVector{ key_hex: '776beff2851db06f4c8a0542c8696f6c6a81af1eec96b4d37fc1d689e6c1c104', iv_hex: '00000060db5672c97aa8f0b200000001', input_hex: '53696e676c6520626c6f636b206d7367', output_hex: '145ad01dbf824ec7560863dc71e3e0c0' },
	AesCtrSourceVector{ key_hex: 'f6d66d6bd52d59bb0796365879eff886c66dd51a5b6a99744b50590c87a23884', iv_hex: '00faac24c1585ef15a43d87500000001', input_hex: '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f', output_hex: 'f05e231b3894612c49ee000b804eb2a9b8306b508f839d6a5530831d9344af1c' },
	AesCtrSourceVector{ key_hex: 'ff7a617ce69148e4f1726e2f43581de2aa62d9f805532edff1eed687fb54153d', iv_hex: '001cc5b751a51d70a1c1114800000001', input_hex: '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20212223', output_hex: 'eb6c52821d0bbbf7ce7594462aca4faab407df866569fd07f48cc0b583d6071f1ec0e6b8' },
	AesCtrSourceVector{ key_hex: 'ff7a617ce69148e4f1726e2f43581de2aa62d9f805532edff1eed687fb54153d', iv_hex: 'ffffffffffffffffffffffffffffffff', input_hex: '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20212223', output_hex: '6e8cfc5908a8c0f1e68596e9c540b68bfe2872e224117e59efac5ce1068909abf8901c66' },
]
