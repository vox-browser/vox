// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

import webidl

fn test_kmac_source_import_defaults_bit_slicing_and_formats() {
	source := KMAC.create()
	material := [u8(0xab), 0xcd]
	for name in ['KMAC128', 'KMAC256'] {
		params := KmacImportParams{ name: name, length: u32(9) }
		key := source.import_key(params, .raw_secret, material, true, [.verify, .sign])!
		assert key.type_ == .secret && !key.extractable && key.usages.len == 0
		assert key.handle() == [u8(0xab)]
		assert (key.algorithm as KmacKeyAlgorithm).length == 9
		assert source.export_key(.raw_secret, key)! == key.handle()
		jwk := JsonWebKey.parse(source.export_key(.jwk, key)!)!
		assert !(jwk.ext or { true }) && (jwk.key_ops or { ['unexpected'] }).len == 0
		assert (jwk.alg or { '' }) == if name == 'KMAC128' { 'K128' } else { 'K256' }
		decoded := source.import_key(KmacImportParams{ name: name }, .jwk, jwk.to_json().bytes(), false, [])!
		assert decoded.handle() == key.handle() && decoded.usages.len == 0 && !decoded.extractable
		for format in [KeyFormat.raw, .raw_public, .raw_private, .raw_seed, .spki, .pkcs8] {
			if _ := source.import_key(params, format, material, false, [.encrypt]) {
				assert false
			} else {
				assert err.msg() == "SyntaxError: Invalid key usage 'encrypt'"
			}
			if _ := source.import_key(params, format, material, false, []) {
				assert false
			} else {
				assert err.msg() == 'NotSupportedError: Only raw-secret and jwk formats are supported'
			}
			if _ := source.export_key(format, key) {
				assert false
			} else {
				assert err.msg() == 'NotSupportedError: Cannot export to unsupported format'
			}
		}
		empty := source.import_key(KmacImportParams{ name: name }, .raw_secret, [], true, [.sign])!
		assert empty.handle().len == 0 && (empty.algorithm as KmacKeyAlgorithm).length == 0
		assert !empty.extractable && empty.usages.len == 0
		for length in [u32(8), 17] {
			if _ := source.import_key(KmacImportParams{ name: name, length: length }, .raw_secret, material, false, []) {
				assert false
			} else {
				assert err.msg() == 'DataError: Invalid data size'
			}
		}
	}
}

fn test_kmac_source_generation_usage_and_common_error_order() {
	subtle := SubtleCrypto.create()
	for name in ['KMAC128', 'KMAC256'] {
		for length in [u32(0), 9, 65536, 65545] {
			if _ := KMAC.create().generate_key(KmacKeyGenParams{ name: name, length: length }, false, [.encrypt]) {
				assert false
			} else {
				assert err.msg() == "SyntaxError: Invalid key usage 'encrypt'"
			}
			if length != 0 {
				key := KMAC.create().generate_key(KmacKeyGenParams{ name: name, length: length }, true, [
					.verify,
					.verify,
					.sign,
				])!.key or { panic('key') }
				assert key.extractable && key.usages == [.verify, .verify, .sign]
				assert (key.algorithm as KmacKeyAlgorithm).length == length
				assert key.handle().len == int(u16(length) / 8)
			}
		}
		if _ := subtle.generate_key(KmacKeyGenParams{ name: name, length: u32(0) }, false, []) {
			assert false
		} else {
			assert err.msg() == 'OperationError: Invalid key length'
		}
		if _ := subtle.generate_key(KmacKeyGenParams{ name: name, length: u32(9) }, false, []) {
			assert false
		} else {
			assert err.msg() == 'SyntaxError: usages must not be empty'
		}
		if _ := subtle.import_key(.raw, [], name, true, [], '') {
			assert false
		} else {
			assert err.msg() == 'NotSupportedError: Only raw-secret and jwk formats are supported'
		}
		key := subtle.import_key(.raw_secret, [u8(0xab), 0xcd], KmacImportParams{ name: name, length: u32(9) }, true, [
			.verify,
			.sign,
			.sign,
		], '')!
		assert key.extractable && key.usages == [.sign, .verify]
		assert key.handle() == [u8(0xab)] && (key.algorithm as KmacKeyAlgorithm).length == 9
	}
}

@[heap]
struct KmacFormatHost {
mut:
	work   []fn ()
	settle []fn ()
}

fn test_kmac_deferred_import_copy_and_direct_kem_import_metadata() {
	mut host := &KmacFormatHost{}
	subtle := SubtleCrypto.create()
	binding := SubtleCryptoBinding.create(subtle, webidl.PromiseContext{}, fn [mut host] (task fn ()) {
		host.work << task
	}, fn [mut host] (task fn ()) { host.settle << task })
	mut bytes := webidl.BufferSource.array_buffer([u8(0xab), 0xcd])
	algorithm := webidl.object_value({
		'name':   webidl.string_value('KMAC128')
		'length': webidl.number_value(9)
	})
	imported := binding.import_key(.raw_secret, webidl.buffer_source_value(bytes), algorithm, true, [
		.verify,
		.sign,
	])
	bytes.write([u8(0), 0], 0)!
	assert imported.state == .pending
	host.work[0]()
	key := crypto_key_from_value(imported.result)!
	assert key.extractable && key.usages == [.sign, .verify] && key.handle() == [u8(0xab)]
	assert (key.algorithm as KmacKeyAlgorithm).length == 9
	// KEM methods call AlgorithmMethods import directly, accept empty shared
	// usages, and install common metadata before the crypto task settlement.
	pair := subtle.generate_key(AlgorithmParams{ name: 'ML-KEM-512' }, true, [
		.encapsulate_key,
		.decapsulate_key,
	])!.pair or { panic('pair') }
	for name in ['KMAC128', 'KMAC256', 'AES-OCB'] {
		typed := subtle.encapsulate_key('ML-KEM-512', pair.public_key, name, true, [])!
		typed_key := typed.shared_key or { panic('key') }
		assert typed_key.extractable && typed_key.usages.len == 0
		typed_ciphertext := typed.ciphertext or { panic('ciphertext') }
		decoded := subtle.decapsulate_key('ML-KEM-512', pair.private_key, typed_ciphertext, name, true, [])!
		assert decoded.extractable && decoded.usages.len == 0 && decoded.handle() == typed_key.handle()
	}
	encapsulated := binding.encapsulate_key(webidl.string_value('ML-KEM-512'), pair.public_key, webidl.string_value('KMAC128'), true, [])
	host.work[1]()
	assert encapsulated.state == .pending && host.settle.len == 1
	host.settle[0]()
	assert encapsulated.state == .fulfilled
	shared_key := crypto_key_from_value(encapsulated.result.object_value['sharedKey'])!
	assert shared_key.extractable && shared_key.usages.len == 0 && shared_key.handle().len == 32
	ciphertext := encapsulated.result.object_value['ciphertext'].buffer_value or { panic('ciphertext') }
	decapsulated := binding.decapsulate_key(webidl.string_value('ML-KEM-512'), pair.private_key, ciphertext, webidl.string_value('KMAC128'), true, [])
	host.work[2]()
	assert decapsulated.state == .pending
	host.settle[1]()
	assert decapsulated.state == .fulfilled
	result := crypto_key_from_value(decapsulated.result)!
	assert result.extractable && result.usages.len == 0 && result.handle() == shared_key.handle()
	rejected := binding.import_key(.raw_secret, webidl.buffer_source_value(webidl.BufferSource.array_buffer([]u8{len: 32})), webidl.string_value('KMAC128'), true, [])
	host.work[3]()
	assert rejected.state == .rejected && rejected.result.object_value['message'].string_value == 'usages must not be empty'
}
