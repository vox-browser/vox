// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

import encoding.hex
import webidl

fn test_hmac_native_upstream_libcrypto_vectors_and_verify() {
	subtle := SubtleCrypto.create()
	sha1_key := subtle.import_key(.raw, hex.decode('c852e54a2c032bc963d3c2790f7643ef36c37aca')!, HmacImportParams{ hash: 'SHA-1' }, true, [
		.sign,
		.verify,
	], '')!
	message := hex.decode('000000000000000016030300101400000ca1911a2059b545a9b4ad753e')!
	assert subtle.sign('HMAC', sha1_key, message)!.hex() == '2c5732613ba784870e4f42072ff0e741d715f456'
	key := subtle.import_key(.raw_secret, 'Well Hello Friends'.bytes(), HmacImportParams{ hash: 'sha-256' }, true, [
		.sign,
		.verify,
	], '')!
	signature := subtle.sign('HMAC', key, 'Some bogus data'.bytes())!
	assert signature.hex() == '1af22062de3b8465c125239976151bec1521821f23ca1166dd8c6ef1813b7f1b'
	assert subtle.verify('HMAC', key, signature, 'Some bogus data'.bytes())!
	assert !subtle.verify('HMAC', key, signature[..31], 'Some bogus data'.bytes())!
	assert !subtle.verify('HMAC', key, signature, 'different'.bytes())!
	assert subtle.sign('HMAC', key, []u8{len: 64, init: `a`})!.hex() == '1d90ce68450bbad6be1cb23aea7fac4b6808a477812aad5d05e215e8f4cb06af'
	assert subtle.sign('HMAC', key, []u8{len: 63, init: `a`})!.hex() == '9ba39ef3b4305f6f67d0a8b0f0cb12f585e219ba0c8be543f09339a8a307f195'
	sha512_key := subtle.import_key(.raw, 'Well Hello Friends'.bytes(), 'HMAC', true, [.sign], 'SHA-512')!
	assert subtle.sign('HMAC', sha512_key, 'Some bogus data'.bytes())!.hex() == 'eba83411fd5b465befbb675e7dc27c2c6be1cfe6c7e47debca97b74cd34d6f089f0d3af1cb0079782f058eeb94480d50643bca70e269384fe4b0490fc54c7aa7'
}

fn test_hmac_source_fractional_generation_import_and_class_metadata() {
	hmac := HMAC.create()
	for hash, length in {
		'SHA-1':   u32(512)
		'SHA-256': u32(512)
		'SHA-384': u32(1024)
		'SHA-512': u32(1024)
	} {
		generated := hmac.generate_key(HmacKeyGenParams{ hash: hash }, true, [.sign, .sign])!
		key := generated.key or { panic('key') }
		assert (key.algorithm as HmacKeyAlgorithm).length == length
		assert key.handle().len == int(length / 8)
		assert key.usages == [KeyUsage.sign]
		assert (hmac.get_key_length(HmacImportParams{ hash: hash })!.value or { panic('length') }) == length
	}
	for length in [u32(7), 9, 65536, 65545] {
		key := hmac.generate_key(HmacKeyGenParams{ hash: 'SHA-256', length: length }, false, [.verify])!.key or { panic('key') }
		assert (key.algorithm as HmacKeyAlgorithm).length == length
		assert key.handle().len == int(u16(length) / 8)
		assert (hmac.get_key_length(HmacImportParams{ hash: 'SHA-256', length: length })!.value or { panic('length') }) == length
	}
	for length in [u32(9), 15, 16] {
		key := hmac.import_key(HmacImportParams{ hash: 'SHA-256', length: length }, .raw, [
			u8(0xab),
			0xcd,
		], true, [.sign])!
		assert (key.algorithm as HmacKeyAlgorithm).length == length
		assert key.handle() == [u8(0xab), 0xcd][..int(length / 8)]
		assert !key.extractable && key.usages.len == 0
	}
	empty := hmac.import_key(HmacImportParams{ hash: 'SHA-256', length: 7 }, .raw_secret, [u8(0xff)], false, [.verify])!
	assert empty.handle().len == 0 && (empty.algorithm as HmacKeyAlgorithm).length == 7
	if _ := hmac.sign(AlgorithmParams{}, empty, []) {
		assert false
	} else {
		assert err.msg() == 'OperationError: HMAC operation failed'
	}
	for length in [u32(0), 8, 17] {
		if _ := hmac.import_key(HmacImportParams{ hash: 'SHA-256', length: length }, .raw, [
			u8(1),
			2,
		], false, [.sign]) {
			assert false
		} else {
			assert err.msg() == if length == 0 { 'DataError: Invalid key length' } else { 'DataError: Invalid data size' }
		}
	}
}

fn test_hmac_source_hash_format_and_validation_order() {
	hmac := HMAC.create()
	if _ := hmac.generate_key(HmacKeyGenParams{ hash: 'bad', length: 0 }, false, [.encrypt]) {
		assert false
	} else {
		assert err.msg() == "SyntaxError: Invalid key usage 'encrypt'"
	}
	if _ := hmac.generate_key(HmacKeyGenParams{ hash: 'bad', length: 0 }, false, [.sign]) {
		assert false
	} else {
		assert err.msg() == 'OperationError: Invalid length'
	}
	if _ := hmac.get_key_length(HmacImportParams{ hash: 'bad', length: 0 }) {
		assert false
	} else {
		assert err.msg() == 'TypeError: Invalid key length'
	}
	if _ := hmac.get_key_length(HmacImportParams{ hash: 'SHA3-256' }) {
		assert false
	} else {
		assert err.msg() == "NotSupportedError: Invalid hash function 'SHA3-256'"
	}
	assert (hmac.get_key_length(HmacImportParams{ hash: 'SHA3-256', length: 9 })!.value or { panic('length') }) == 9
	sha3_key := SubtleCrypto.create().import_key(.raw, [u8(1)], HmacImportParams{ hash: 'SHA3-256' }, true, [.sign], '')!
	assert hmac.export_key(.raw, sha3_key)! == [u8(1)]
	if _ := hmac.sign(AlgorithmParams{}, sha3_key, []) {
		assert false
	} else {
		assert err.msg() == "NotSupportedError: Invalid hash function 'SHA3-256'"
	}
	if _ := hmac.export_key(.jwk, sha3_key) {
		assert false
	} else {
		assert err.msg() == 'DataError: Invalid algorithm'
	}
	if _ := hmac.import_key(HmacImportParams{}, .spki, [], false, [.encrypt]) {
		assert false
	} else {
		assert err.msg() == "SyntaxError: Invalid key usage 'encrypt'"
	}
	if _ := hmac.import_key(HmacImportParams{}, .spki, [], false, [.sign]) {
		assert false
	} else {
		assert err.msg() == 'NotSupportedError: Invalid key format'
	}
	if _ := hmac.import_key(HmacImportParams{}, .raw, [], false, []) {
		assert false
	} else {
		assert err.msg() == 'DataError: No data provided'
	}
}

fn test_hmac_source_jwk_algorithm_use_and_export() {
	subtle := SubtleCrypto.create()
	jwk := JsonWebKey{
		kty:     'oct'
		k:       'q80'
		alg:     'HS256'
		use:     'sig'
		key_ops: [
			'sign',
			'verify',
		]
		ext:     true
	}
	key := subtle.import_jwk(jwk, HmacImportParams{ hash: 'SHA-256', length: 9 }, true, [
		.sign,
		.verify,
	], '')!
	assert key.handle() == [u8(0xab)] && key.extractable
	exported := subtle.export_jwk(key)!
	assert (exported.alg or { '' }) == 'HS256' && (exported.k or { '' }) == 'qw'
	assert (exported.key_ops or { [] }) == ['sign', 'verify'] && (exported.ext or { false })
	assert subtle.export_key(.raw_secret, key)! == [u8(0xab)]
	assert JsonWebKey.parse(subtle.export_key(.jwk, key)!)! == exported
	if _ := subtle.import_jwk(JsonWebKey{ kty: 'oct' }, 'HMAC', true, [.sign], 'SHA-256') {
		assert false
	} else {
		assert err.msg() == "DataError: JWK has no 'k' field"
	}
	if _ := subtle.import_jwk(JsonWebKey{ ...jwk, use: 'sign' }, 'HMAC', true, [.sign], 'SHA-256') {
		assert false
	} else {
		assert err.msg() == 'DataError: Invalid use in JsonWebKey'
	}
	if _ := subtle.import_jwk(JsonWebKey{ ...jwk, alg: 'HS512', use: 'sig', ext: false }, 'HMAC', true, [.sign], 'SHA-256') {
		assert false
	} else {
		assert err.msg() == 'DataError: Invalid algorithm'
	}
	if _ := subtle.import_jwk(JsonWebKey{ ...jwk, ext: false }, 'HMAC', true, [.sign], 'SHA-256') {
		assert false
	} else {
		assert err.msg() == 'DataError: Invalid ext field'
	}
	class_key := HMAC.create().import_key(HmacImportParams{ hash: 'SHA-256' }, .jwk, JsonWebKey{ ...jwk, use: 'anything', key_ops: [] }.to_json().bytes(), false, [])!
	assert class_key.handle() == [u8(0xab), 0xcd]
}

@[heap]
struct HmacBindingHost {
mut:
	work   []fn ()
	settle []fn ()
}

fn test_hmac_deferred_import_length_and_native_sign_copy() {
	mut host := &HmacBindingHost{}
	binding := SubtleCryptoBinding.create(SubtleCrypto.create(), webidl.PromiseContext{}, fn [mut host] (task fn ()) {
		host.work << task
	}, fn [mut host] (task fn ()) { host.settle << task })
	mut material := webidl.BufferSource.array_buffer([u8(0xab), 0xcd])
	mut members := {
		'name':   webidl.string_value('HMAC')
		'hash':   webidl.string_value('SHA-256')
		'length': webidl.number_value(9)
	}
	imported := binding.import_key(.raw_secret, webidl.buffer_source_value(material), webidl.object_value(members), true, [.sign])
	members['length'] = webidl.number_value(0)
	material.write([u8(0), 0], 0)!
	assert imported.state == .pending
	host.work[0]()
	key := crypto_key_from_value(imported.result)!
	assert key.handle() == [u8(0xab)] && (key.algorithm as HmacKeyAlgorithm).length == 9
	mut message := webidl.BufferSource.array_buffer('original'.bytes())
	signed := binding.sign(webidl.string_value('HMAC'), key, message)
	message.write('mutated!'.bytes(), 0)!
	host.work[1]()
	assert signed.state == .pending
	host.settle[0]()
	assert webidl.get_buffer_source_copy(signed.result.buffer_value or { panic('signature') }) == hmac_sign(key, 'original'.bytes())!
	invalid := binding.import_key(.raw, webidl.buffer_source_value(webidl.BufferSource.array_buffer([
		u8(1),
		2,
	])), webidl.object_value({
		'name':   webidl.string_value('HMAC')
		'hash':   webidl.string_value('SHA-256')
		'length': webidl.number_value(8)
	}), false, [.sign])
	assert invalid.state == .pending
	host.work[2]()
	assert invalid.state == .rejected && invalid.result.object_value['message'].string_value == 'Invalid data size'
}
