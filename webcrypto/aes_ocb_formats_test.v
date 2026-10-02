// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

import webidl

fn test_aes_ocb_source_generation_format_defaults_and_exact_errors() {
	source := AesOcb.create()
	for bits in [u16(128), 192, 256] {
		generated := source.generate_key(AesKeyGenParams{ length: bits }, true, [
			.encrypt,
			.encrypt,
		])!.key or { panic('key') }
		assert generated.handle().len == int(bits / 8)
		assert generated.usages == [.encrypt, .encrypt]
		key := source.import_key(AlgorithmParams{}, .raw_secret, generated.handle(), true, [])!
		assert !key.extractable
		assert key.usages.len == 0
		assert key.type_ == .secret
		assert (key.algorithm as AesKeyAlgorithm).length == bits
		assert source.export_key(.raw_secret, key)! == generated.handle()
		jwk := JsonWebKey{
			kty: 'oct'
			k:   base64url_encode(key.handle())
			alg: 'A${bits}OCB'
		}
		assert source.import_key(AlgorithmParams{}, .jwk, jwk.to_json().bytes(), true, [.encrypt])!.usages.len == 0
		if _ := source.import_key(AlgorithmParams{}, .jwk, JsonWebKey{
			...jwk
			alg: 'wrong'
		}.to_json().bytes(), true, [.encrypt])
		{
			assert false
		} else {
			assert err.msg() == 'DataError: Contradictory key size: key has ${bits} bits, but alg specifies non-${bits}-bit algorithm'
		}
		assert source.get_key_length(AesKeyGenParams{ length: bits })!.value? == u32(bits)
	}
	for bits in [u16(0), 1, 127, 129, 193, 257] {
		if _ := source.generate_key(AesKeyGenParams{ length: bits }, false, [.sign]) {
			assert false
		} else {
			assert err.msg() == "SyntaxError: Invalid key usage 'sign'"
		}
		if _ := source.generate_key(AesKeyGenParams{ length: bits }, false, []) {
			assert false
		} else {
			assert err.msg() == 'OperationError: Cannot create AES-OCB key with unusual amount of ${bits} bits'
		}
		if _ := source.get_key_length(AesKeyGenParams{ length: bits }) {
			assert false
		} else {
			assert err.msg() == 'OperationError: Invalid key length: ${bits}'
		}
	}
	for size in [0, 1, 15, 17, 23, 25, 31, 33] {
		if _ := source.import_key(AlgorithmParams{}, .raw_secret, []u8{len: size}, true, []) {
			assert false
		} else {
			assert err.msg() == "DataError: Invalid key length '${size * 8}' bits (must be either 128, 192, or 256 bits)"
		}
	}
	if _ := source.import_key(AlgorithmParams{}, .raw, []u8{len: 16}, true, []) {
		assert false
	} else {
		assert err.msg() == 'NotSupportedError: Only raw-secret and jwk formats are supported'
	}
	invalid := CryptoKey.create(.secret, true, AesKeyAlgorithm{ name: 'AES-OCB' }, [], [
		u8(1),
	])
	assert JsonWebKey.parse(source.export_key(.jwk, invalid)!)!.alg == none
	if _ := source.export_key(.raw, invalid) {
		assert false
	} else {
		assert err.msg() == 'NotSupportedError: Cannot export to unsupported format'
	}
}

fn test_aes_ocb_native_exact_source_failure_diagnostics() {
	source := AesOcb.create()
	key := source.import_key(AlgorithmParams{}, .raw_secret, []u8{len: 16}, false, [])!
	if _ := source.encrypt(AeadParams{}, key, []) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Encryption failed: EVP_CIPHER_CTX_ctrl(ctx.ptr(), EVP_CTRL_AEAD_SET_IVLEN, iv.size(), nullptr) failed'
	}
	params := AeadParams{
		iv: []u8{len: 12}
	}
	mut output := source.encrypt(params, key, 'native authentication'.bytes())!
	output[output.len - 1] ^= 1
	if _ := source.decrypt(params, key, output) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Decryption failed: EVP_DecryptFinal_ex(ctx.ptr(), plaintext.data() + out_len, &final_len) failed'
	}
}

@[heap]
struct AesOcbFormatBindingHost {
mut:
	tasks []fn ()
}

fn test_aes_ocb_common_import_metadata_and_async_source_get_length() {
	mut host := &AesOcbFormatBindingHost{}
	binding := SubtleCryptoBinding.create(SubtleCrypto.create(), webidl.PromiseContext{}, fn [mut host] (task fn ()) {
		host.tasks << task
	}, fn (_ fn ()) {})
	imported := binding.import_key(.raw_secret,
		webidl.buffer_source_value(webidl.BufferSource.array_buffer([]u8{len: 16})),
		webidl.string_value('AES-OCB'), true, [])
	assert imported.state == .pending
	host.tasks[0]()
	assert imported.state == .rejected
	assert imported.result.object_value['message'].string_value == 'usages must not be empty'
	valid := binding.import_key(.raw_secret,
		webidl.buffer_source_value(webidl.BufferSource.array_buffer([]u8{len: 16})),
		webidl.string_value('AES-OCB'), true, [.encrypt])
	host.tasks[1]()
	key := crypto_key_from_value(valid.result)!
	assert key.extractable
	assert key.usages == [.encrypt]
	base := SubtleCrypto.create().import_key(.raw, []u8{len: 16}, 'HKDF', false, [
		.derive_key,
	], '')!
	derived := binding.derive_key(webidl.object_value({
		'name': webidl.string_value('HKDF')
		'hash': webidl.string_value('SHA-256')
		'salt': webidl.buffer_source_value(webidl.BufferSource.array_buffer([]))
		'info': webidl.buffer_source_value(webidl.BufferSource.array_buffer([]))
	}), base, webidl.object_value({
		'name':   webidl.string_value('AES-OCB')
		'length': webidl.number_value(1)
	}), false, [.encrypt])
	host.tasks[2]()
	assert derived.state == .rejected
	assert derived.result.object_value['message'].string_value == 'Invalid key length: 1'
}
