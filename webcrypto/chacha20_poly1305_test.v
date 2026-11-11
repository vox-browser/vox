// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

import encoding.hex
import webidl

fn test_chacha_native_all_upstream_wpt_data_and_aad_fixtures() {
	subtle := SubtleCrypto.create()
	key := subtle.import_key(.raw_secret, hex.decode(chacha_source_key_hex)!, 'ChaCha20-Poly1305',
		false, [.encrypt, .decrypt], '')!
	for vector in chacha_source_vectors {
		params := AeadParams{
			name:            'ChaCha20-Poly1305'
			iv:              hex.decode(chacha_source_iv_hex)!
			additional_data: hex.decode(vector.aad_hex)!
		}
		input := hex.decode(vector.input_hex)!
		output := subtle.encrypt(params, key, input)!
		assert output.hex() == vector.output_hex
		assert subtle.decrypt(params, key, output)! == input
		assert subtle.encrypt(AeadParams{ ...params, tag_length: u8(128) }, key, input)! == output
		mut corrupt := output.clone()
		corrupt[corrupt.len - 1] ^= 1
		if _ := subtle.decrypt(params, key, corrupt) {
			assert false
		} else {
			assert err.msg() == 'OperationError: Decryption failed: EVP_DecryptFinal_ex(ctx.ptr(), plaintext.data() + out_len, &final_len) failed'
		}
	}
}

fn test_chacha_source_validation_order_and_real_backend_errors() {
	algorithm := ChaCha20Poly1305.create()
	bad_key := CryptoKey.create(.secret, false, KeyAlgorithm{}, [], [])
	for decrypt in [false, true] {
		if _ := chacha20_poly1305_crypt(AeadParams{ tag_length: u8(1) }, bad_key, [], decrypt) {
			assert false
		} else {
			assert err.msg() == 'OperationError: IV must have a length of 12 bytes'
		}
		params := AeadParams{
			iv:         []u8{len: 12}
			tag_length: u8(1)
		}
		if _ := chacha20_poly1305_crypt(params, bad_key, [], decrypt) {
			assert false
		} else {
			assert err.msg() == 'OperationError: tagLength must be 128'
		}
	}
	params := AeadParams{
		iv: []u8{len: 12}
	}
	if _ := algorithm.decrypt(params, bad_key, []) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Ciphertext must be at least 128 bits'
	}
	if _ := algorithm.encrypt(params, bad_key, []) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Encryption failed: ChaCha20-Poly1305 key must be 32 bytes'
	}
	if _ := algorithm.decrypt(params, bad_key, []u8{len: 16}) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Decryption failed: ChaCha20-Poly1305 key must be 32 bytes'
	}
	if _ := native_chacha20_poly1305(false, []u8{len: 32}, [], [], []) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Encryption failed: ChaCha20-Poly1305 nonce must be 12 bytes'
	}
	if _ := native_chacha20_poly1305(true, []u8{len: 32}, []u8{len: 12}, [], []) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Decryption failed: Ciphertext too short'
	}
}

fn chacha_import_error(format KeyFormat, jwk JsonWebKey, usages []KeyUsage, expected string) {
	if _ := import_chacha_key(format, jwk.to_json().bytes(), true, usages) {
		assert false
	} else {
		assert err.msg() == expected
	}
}

fn test_chacha_source_formats_generation_and_jwk_error_order() {
	algorithm := ChaCha20Poly1305.create()
	for bytes in [0, 1, 31, 33] {
		if _ := algorithm.import_key(.raw_secret, []u8{len: bytes}, false, []) {
			assert false
		} else {
			assert err.msg() == 'DataError: Key data must be 256 bits'
		}
	}
	for format in [KeyFormat.raw, .spki, .pkcs8, .raw_seed, .raw_public, .raw_private] {
		chacha_import_error(format, JsonWebKey{}, [.sign], "SyntaxError: Invalid key usage 'sign'")
		chacha_import_error(format, JsonWebKey{}, [.encrypt],
			'NotSupportedError: Only raw-secret and jwk formats are supported')
	}
	base := JsonWebKey{
		kty: 'oct'
		k:   base64url_encode([]u8{len: 32})
		alg: 'C20P'
	}
	chacha_import_error(.jwk, JsonWebKey{ kty: 'RSA' }, [.encrypt], 'DataError: Invalid key type')
	chacha_import_error(.jwk, JsonWebKey{ ...base, k: none, alg: 'wrong' }, [.encrypt],
		"DataError: JWK has no 'k' field")
	chacha_import_error(.jwk, JsonWebKey{ ...base, alg: 'wrong', use: 'wrong' }, [
		.encrypt,
	], 'DataError: Invalid alg field')
	chacha_import_error(.jwk, JsonWebKey{ ...base, use: 'wrong', key_ops: ['bad', 'bad'] }, [
		.encrypt,
	], 'DataError: Invalid use field')
	chacha_import_error(.jwk, JsonWebKey{ ...base, key_ops: ['bad', 'bad'], ext: false }, [
		.encrypt,
	], 'DataError: Duplicate key operation: bad')
	chacha_import_error(.jwk, JsonWebKey{ ...base, ext: false }, [.encrypt],
		'DataError: Invalid ext field')
	key := algorithm.import_key(.jwk,
		JsonWebKey{
		...base
		alg: none
		use: 'wrong'
	}.to_json().bytes(), true, [])!
	assert key.type_ == .secret
	assert key.algorithm_name() == 'ChaCha20-Poly1305'
	assert !key.extractable
	assert key.usages.len == 0
	// Source JWK import admits every decoded width, including zero bytes.
	for size in [0, 1, 31, 33] {
		admitted := SubtleCrypto.create().import_jwk(JsonWebKey{
			...base
			k: base64url_encode([]u8{len: size})
		}, 'ChaCha20-Poly1305', true, [.encrypt], '')!
		assert admitted.handle().len == size
		assert SubtleCrypto.create().export_jwk(admitted)!.alg? == 'C20P'
		if _ := algorithm.encrypt(AeadParams{ iv: []u8{len: 12} }, admitted, []) {
			assert false
		} else {
			assert err.msg().ends_with('ChaCha20-Poly1305 key must be 32 bytes')
		}
	}
	duplicated := [KeyUsage.encrypt, .encrypt]
	generated := algorithm.generate_key(AlgorithmParams{}, true, duplicated)!
	generated_key := generated.key or { panic('key') }
	assert generated_key.handle().len == 32
	assert generated_key.extractable
	assert generated_key.usages == [KeyUsage.encrypt]
	assert algorithm.generate_key(AlgorithmParams{}, false, [])!.key?.usages.len == 0
	if _ := algorithm.generate_key(AlgorithmParams{}, false, [.sign]) {
		assert false
	} else {
		assert err.msg() == "SyntaxError: Invalid key usage 'sign'"
	}
	assert algorithm.get_key_length(AlgorithmParams{})!.value? == u32(256)
	exported := JsonWebKey.parse(algorithm.export_key(.jwk, generated_key)!)!
	assert exported.kty? == 'oct'
	assert exported.alg? == 'C20P'
	assert exported.key_ops? == ['encrypt']
	assert exported.ext? == true
	assert exported.use == none
	assert algorithm.export_key(.raw_secret, generated_key)! == generated_key.handle()
	for format in [KeyFormat.raw, .spki, .pkcs8, .raw_seed, .raw_public, .raw_private] {
		if _ := algorithm.export_key(format, generated_key) {
			assert false
		} else {
			assert err.msg() == 'NotSupportedError: Cannot export to unsupported format'
		}
	}
}

@[heap]
struct ChachaBindingHost {
mut:
	work   []fn ()
	settle []fn ()
}

fn test_chacha_deferred_native_copies_and_typed_raw_compatibility() {
	mut host := &ChachaBindingHost{}
	subtle := SubtleCrypto.create()
	binding := SubtleCryptoBinding.create(subtle, webidl.PromiseContext{}, fn [mut host] (task fn ()) {
		host.work << task
	}, fn [mut host] (task fn ()) {
		host.settle << task
	})
	material := hex.decode(chacha_source_key_hex)!
	key := subtle.import_key(.raw, material, 'ChaCha20-Poly1305', true, [.encrypt], '')!
	assert subtle.export_key(.raw, key)! == material
	raw_import := binding.import_key(.raw,
		webidl.buffer_source_value(webidl.BufferSource.array_buffer(material)),
		webidl.string_value('ChaCha20-Poly1305'), true, [.encrypt])
	raw_export := binding.export_key(.raw, key)
	host.work[0]()
	host.work[1]()
	assert raw_import.state == .rejected
	assert raw_export.state == .rejected
	assert raw_import.result.object_value['message'].string_value == 'Only raw-secret and jwk formats are supported'
	assert raw_export.result.object_value['message'].string_value == 'Cannot export to unsupported format'
	vector := chacha_source_vectors.last()
	mut iv := webidl.BufferSource.array_buffer(hex.decode(chacha_source_iv_hex)!)
	mut aad := webidl.BufferSource.array_buffer(hex.decode(vector.aad_hex)!)
	mut input := webidl.BufferSource.array_buffer(hex.decode(vector.input_hex)!)
	promise := binding.encrypt(webidl.object_value({
		'name':           webidl.string_value('ChaCha20-Poly1305')
		'iv':             webidl.buffer_source_value(iv)
		'additionalData': webidl.buffer_source_value(aad)
	}), key, input)
	iv.write([]u8{len: 12}, 0)!
	aad.write([]u8{len: int(aad.byte_length())}, 0)!
	input.write([]u8{len: int(input.byte_length())}, 0)!
	host.work[2]()
	assert promise.state == .pending
	host.settle[0]()
	assert promise.state == .fulfilled
	assert webidl.get_buffer_source_copy(promise.result.buffer_value or { panic('bytes') }).hex() == vector.output_hex
	exported := binding.export_key(.jwk, key)
	host.work[3]()
	assert exported.result.object_value['alg'].string_value == 'C20P'
	wrapping_key := subtle.import_key(.raw, []u8{len: 16}, 'AES-KW', false, [
		.wrap_key,
	], '')!
	refused_wrap := binding.wrap_key(.raw, key, wrapping_key, webidl.string_value('AES-KW'))
	host.work[4]()
	assert refused_wrap.state == .rejected
	assert refused_wrap.result.object_value['message'].string_value == 'Cannot export to unsupported format'
}

struct ChachaSourceVector {
	input_hex  string
	aad_hex    string
	output_hex string
}

// Exact source WPT ChaCha20-Poly1305 inputs, AAD and expected bytes.
const chacha_source_key_hex = '348a696769035efe3bf19f8abdfe99bfe4aca5ef75ac13cedb09cd8a2d57a659'
const chacha_source_iv_hex = '000102030405060708090a0b'
const chacha_source_vectors = [
	ChachaSourceVector{
		input_hex:  ''
		aad_hex:    ''
		output_hex: 'ca1fa0a9a9dda235fc7e7fed9e625629'
	},
	ChachaSourceVector{
		input_hex:  '156eea7cc14c56cb94db030a4a9d95ff'
		aad_hex:    ''
		output_hex: 'e2eedeeaca6074cacdc77e28a75d41ac572d9244f5ec57a2c859e43302f967ff'
	},
	ChachaSourceVector{
		input_hex:  'b6c8f9df648cd088b70f38e74197b18cb81e1e4350d50bccb8fb5a7379c87bb2e3d6ed5461ed1e9f36f340a3962a446b815b794b4bd43a4403502077b2256cc807837f3aacd118eb4b9c2baeb897068625abaca193'
		aad_hex:    ''
		output_hex: '4148cd496fa0f289ee1345c5ac5765df61f5ff39e22b247dcddad3fc662deab31747579c91106a624b8c43f9e67c257fc0912881cb1f0fb60fe2d36f848472cc4924f5c7d4bbef212ecb7c864c15f2e977b3d8c1d2912b3069991c3e31af9a8ede44dbe542'
	},
	ChachaSourceVector{
		input_hex:  '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f40'
		aad_hex:    ''
		output_hex: 'f78136950f29240651157729e1cdda5cc9faf369a6eb39a66d38939403f88f1ed4b098ebd4d852da555629715c7b4f3b71fb63f9b4fe03c5348bc9230a9c203b0ee17530647e3a709dc312b9b261d7e971'
	},
	ChachaSourceVector{
		input_hex:  ''
		aad_hex:    '0102030405060708'
		output_hex: '00b0af259c278d5dc6e0dfd6efd432d7'
	},
	ChachaSourceVector{
		input_hex:  '156eea7cc14c56cb94db030a4a9d95ff'
		aad_hex:    '0102030405060708'
		output_hex: 'e2eedeeaca6074cacdc77e28a75d41ac282dc7436d5063cbf68952ceb717afb0'
	},
	ChachaSourceVector{
		input_hex:  'b6c8f9df648cd088b70f38e74197b18cb81e1e4350d50bccb8fb5a7379c87bb2e3d6ed5461ed1e9f36f340a3962a446b815b794b4bd43a4403502077b2256cc807837f3aacd118eb4b9c2baeb897068625abaca193'
		aad_hex:    '0102030405060708'
		output_hex: '4148cd496fa0f289ee1345c5ac5765df61f5ff39e22b247dcddad3fc662deab31747579c91106a624b8c43f9e67c257fc0912881cb1f0fb60fe2d36f848472cc4924f5c7d4bbef212ecb7c864c15f2e977b3d8c1d2c7790799f5897a64486671a9f4da6f69'
	},
	ChachaSourceVector{
		input_hex:  '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f40'
		aad_hex:    '0102030405060708'
		output_hex: 'f78136950f29240651157729e1cdda5cc9faf369a6eb39a66d38939403f88f1ed4b098ebd4d852da555629715c7b4f3b71fb63f9b4fe03c5348bc9230a9c203b0e890037c1a64a7cfb5b24bf70eccc2366'
	},
	ChachaSourceVector{
		input_hex:  ''
		aad_hex:    '090a0b0c0d0e0f101112131415161718'
		output_hex: 'a37a8ba6cdbe84ec11131f04102f0df2'
	},
	ChachaSourceVector{
		input_hex:  '156eea7cc14c56cb94db030a4a9d95ff'
		aad_hex:    '090a0b0c0d0e0f101112131415161718'
		output_hex: 'e2eedeeaca6074cacdc77e28a75d41ac12f2fddc348a43a2c9267d772c359377'
	},
	ChachaSourceVector{
		input_hex:  'b6c8f9df648cd088b70f38e74197b18cb81e1e4350d50bccb8fb5a7379c87bb2e3d6ed5461ed1e9f36f340a3962a446b815b794b4bd43a4403502077b2256cc807837f3aacd118eb4b9c2baeb897068625abaca193'
		aad_hex:    '090a0b0c0d0e0f101112131415161718'
		output_hex: '4148cd496fa0f289ee1345c5ac5765df61f5ff39e22b247dcddad3fc662deab31747579c91106a624b8c43f9e67c257fc0912881cb1f0fb60fe2d36f848472cc4924f5c7d4bbef212ecb7c864c15f2e977b3d8c1d2a1fac033c185b9379415c2a8d4cbfcb8'
	},
	ChachaSourceVector{
		input_hex:  '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f40'
		aad_hex:    '090a0b0c0d0e0f101112131415161718'
		output_hex: 'f78136950f29240651157729e1cdda5cc9faf369a6eb39a66d38939403f88f1ed4b098ebd4d852da555629715c7b4f3b71fb63f9b4fe03c5348bc9230a9c203b0e58149fb991e601f26aff37073c55b3b8'
	},
]
