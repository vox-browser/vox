// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

import webidl

fn test_aes_source_raw_jwk_generation_and_algorithm_class_metadata() {
	subtle := SubtleCrypto.create()
	for name in ['AES-CBC', 'AES-CTR', 'AES-GCM', 'AES-KW'] {
		usages := if name == 'AES-KW' { [KeyUsage.wrap_key] } else { [
				KeyUsage.encrypt,
			] }
		for bits in [u16(128), 192, 256] {
			material := []u8{len: int(bits / 8), init: u8(index)}
			for format in [KeyFormat.raw, .raw_secret] {
				direct := import_aes_key(name, format, material, true, usages)!
				assert direct.algorithm == CryptoKeyAlgorithm(AesKeyAlgorithm{
					name:   name
					length: bits
				})
				assert direct.type_ == .secret
				assert !direct.extractable
				assert direct.usages.len == 0
				assert export_aes_key(format, direct)! == material
				mut copied := material.clone()
				typed := subtle.import_key(format, copied, name, true, usages, '')!
				copied[0] ^= 1
				assert typed.handle() == material
				assert typed.extractable
				assert typed.usages == usages
				jwk := subtle.export_jwk(typed)!
				assert jwk.kty? == 'oct'
				assert jwk.k? == base64url_encode(material)
				assert jwk.alg? == 'A${bits}${name[4..]}'
				assert jwk.ext? == true
				assert jwk.key_ops? == usages.map(key_usage_string(it))
				assert jwk.use == none
				assert subtle.import_jwk(jwk, name, true, usages, '')!.handle() == material
				assert JsonWebKey.parse(subtle.export_key(.jwk, typed)!)!.alg? == jwk.alg?
			}
			duplicated := [usages[0], usages[0]]
			generated := generate_aes_key(AesKeyGenParams{ name: name, length: bits }, true,
				duplicated)!
			assert generated.handle().len == int(bits / 8)
			assert generated.algorithm_name() == name
			assert generated.usages == duplicated
			assert generated.extractable
			assert aes_key_length(AesKeyGenParams{ length: bits })! == u32(bits)
		}
	}
	// Each concrete AlgorithmMethods body leaves common metadata installation
	// to SubtleCrypto and can import a valid key with empty usages.
	assert AesCbc.create().import_key(.raw, []u8{len: 16}, true, [])!.usages.len == 0
	assert AesCtr.create().import_key(.raw, []u8{len: 16}, true, [])!.usages.len == 0
	assert AesGcm.create().import_key(.raw, []u8{len: 16}, true, [])!.usages.len == 0
	assert AesKw.create().import_key(.raw, []u8{len: 16}, true, [])!.usages.len == 0
}

fn aes_format_error(name string, format KeyFormat, jwk JsonWebKey, usages []KeyUsage, expected string) {
	if _ := import_aes_key(name, format, jwk.to_json().bytes(), true, usages) {
		assert false
	} else {
		assert err.msg() == expected
	}
}

fn test_aes_source_jwk_required_fields_and_validation_order() {
	for name in ['AES-CBC', 'AES-CTR', 'AES-GCM', 'AES-KW'] {
		usage := if name == 'AES-KW' { KeyUsage.wrap_key } else { KeyUsage.encrypt }
		aes_format_error(name, .spki, JsonWebKey{}, [.sign],
			"SyntaxError: Invalid key usage 'sign'")
		aes_format_error(name, .spki, JsonWebKey{}, [usage],
			'NotSupportedError: Only raw and jwk formats are supported')
		aes_format_error(name, .jwk, JsonWebKey{ kty: 'RSA', ext: false }, [usage],
			'DataError: Invalid key type')
		missing := if name in ['AES-CBC', 'AES-KW'] {
			"DataError: JWK has no 'k' field"
		} else {
			"DataError: Missing 'k' field"
		}
		aes_format_error(name, .jwk, JsonWebKey{ kty: 'oct', ext: false }, [usage], missing)
		base := JsonWebKey{
			kty: 'oct'
			k:   base64url_encode([]u8{len: 16})
			alg: 'A128${name[4..]}'
		}
		assert import_aes_key(name, .jwk, JsonWebKey{
			...base
			alg: none
		}.to_json().bytes(), true, [usage])!.handle().len == 16
		aes_format_error(name, .jwk, JsonWebKey{ ...base, alg: none, ext: false }, [
			usage,
		], 'DataError: Invalid ext field')
		aes_format_error(name, .jwk, JsonWebKey{ ...base, k: none }, [usage], if name in [
			'AES-CTR',
			'AES-GCM',
		] {
			"DataError: Missing 'k' field"
		} else {
			"DataError: JWK has no 'k' field"
		})
		aes_format_error(name, .jwk, JsonWebKey{
			...base
			k:   base64url_encode([]u8{len: 17})
			alg: 'wrong'
			use: 'wrong'
			ext: false
		}, [usage], 'DataError: Invalid key size: 136 bits')
		aes_format_error(name, .jwk, JsonWebKey{ ...base, alg: 'wrong', use: 'wrong', ext: false }, [
			usage,
		],
			'DataError: Contradictory key size: key has 128 bits, but alg specifies non-128-bit algorithm')
		aes_format_error(name, .jwk, JsonWebKey{ ...base, use: 'wrong', key_ops: [
			'bad',
			'bad',
		], ext: false }, [usage], 'DataError: Invalid use field')
		aes_format_error(name, .jwk, JsonWebKey{ ...base, key_ops: ['bad', 'bad'], ext: false }, [
			usage,
		], 'DataError: Duplicate key operation: bad')
		aes_format_error(name, .jwk, JsonWebKey{ ...base, ext: false }, [usage],
			'DataError: Invalid ext field')
		assert import_aes_key(name, .jwk, JsonWebKey{
			...base
			use: 'wrong'
		}.to_json().bytes(), false, [])!.handle().len == 16
	}
}

fn test_aes_source_lengths_generation_errors_and_malformed_handle_export() {
	for name in ['AES-CBC', 'AES-CTR', 'AES-GCM', 'AES-KW'] {
		for bytes in [0, 1, 15, 17, 23, 25, 31, 33] {
			if _ := import_aes_key(name, .raw, []u8{len: bytes}, false, []) {
				assert false
			} else {
				assert err.msg() == "DataError: Invalid key length '${bytes * 8}' bits (must be either 128, 192, or 256 bits)"
			}
		}
		for bits in [u16(0), 1, 127, 129, 193, 257, 65535] {
			if _ := generate_aes_key(AesKeyGenParams{ name: name, length: bits }, false, [
				.sign,
			])
			{
				assert false
			} else {
				assert err.msg() == "SyntaxError: Invalid key usage 'sign'"
			}
			if _ := generate_aes_key(AesKeyGenParams{ name: name, length: bits }, false, []) {
				assert false
			} else {
				assert err.msg() == 'OperationError: Cannot create ${name} key with unusual amount of ${bits} bits'
			}
			if _ := aes_key_length(AesKeyGenParams{ length: bits }) {
				assert false
			} else {
				assert err.msg() == 'OperationError: Invalid key length'
			}
			if _ := SubtleCrypto.create().generate_key(AesKeyGenParams{ name: name, length: bits },
				false, [])
			{
				assert false
			} else {
				assert err.msg().starts_with('OperationError: Cannot create')
			}
		}
		key := CryptoKey.create(.secret, true, AesKeyAlgorithm{ name: name, length: 128 }, [], [
			u8(1),
		])
		if name == 'AES-CBC' {
			if _ := export_aes_key(.jwk, key) {
				assert false
			} else {
				assert err.msg() == 'OperationError: unclear key size'
			}
		} else {
			// Pinned CTR/GCM/KW omit alg for a malformed handle; only CBC errors.
			assert JsonWebKey.parse(export_aes_key(.jwk, key)!)!.alg == none
		}
		assert export_aes_key(.raw_secret, key)! == [u8(1)]
		for format in [KeyFormat.pkcs8, .spki, .raw_public, .raw_private, .raw_seed] {
			if _ := export_aes_key(format, key) {
				assert false
			} else {
				assert err.msg() == 'NotSupportedError: Cannot export to unsupported format'
			}
		}
	}
}

@[heap]
struct AesFormatBindingHost {
mut:
	work   []fn ()
	settle []fn ()
}

fn test_aes_source_binding_import_copies_data_and_installs_common_slots() {
	mut host := &AesFormatBindingHost{}
	binding := SubtleCryptoBinding.create(SubtleCrypto.create(), webidl.PromiseContext{}, fn [mut host] (task fn ()) {
		host.work << task
	}, fn [mut host] (task fn ()) {
		host.settle << task
	})
	mut data := webidl.BufferSource.array_buffer([]u8{len: 24, init: u8(index)})
	mut usages := [KeyUsage.encrypt]
	imported := binding.import_key(.raw_secret, webidl.buffer_source_value(data),
		webidl.string_value('AES-GCM'), true, usages)
	data.write([]u8{len: 24}, 0)!
	usages[0] = .sign
	assert imported.state == .pending
	host.work[0]()
	assert imported.state == .fulfilled
	key := crypto_key_from_value(imported.result)!
	assert key.handle() == []u8{len: 24, init: u8(index)}
	assert key.extractable
	assert key.usages == [.encrypt]
	exported := binding.export_key(.jwk, key)
	host.work[1]()
	assert exported.state == .fulfilled
	assert exported.result.object_value['alg'].string_value == 'A192GCM'
	assert host.settle.len == 0
	invalid := binding.generate_key(webidl.object_value({
		'name':   webidl.string_value('AES-GCM')
		'length': webidl.number_value(1)
	}), false, [.sign])
	host.work[2]()
	assert invalid.state == .rejected
	assert invalid.result.object_value['message'].string_value == "Invalid key usage 'sign'"
}
