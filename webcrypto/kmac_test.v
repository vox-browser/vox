module webcrypto

import x.json2

fn test_kmac_nist_vectors_through_production_subtle_dispatch() {
	subtle := SubtleCrypto.create()
	material := []u8{len: 32, init: u8(index + 0x40)}
	short := [u8(0), 1, 2, 3]
	long := []u8{len: 200, init: u8(index)}
	custom := 'My Tagged Application'.bytes()
	// Same six NIST SP800-185 samples as upstream kmac_vectors.js.
	for index, expected in [
		'e5780b0d3ea6f7d3a429c5706aa43a00fadbd7d49628839e3187243f456ee14e',
		'3b1fba963cd8b0b59e8c1a6d71888b7143651af8ba0a7070c0979e2811324aa5',
		'1f5b4e6cca02209e0dcb5ca635b89a15e271ecc760071dfd805faa38f9729230',
		'20c570c31346f703c9ac36c61c03cb64c3970d0cfc787e9b79599d273a68d2f7f69d4cc3de9d104a351689f27cf6f5951f0103f33f4f24871024d9c27773a8dd',
		'75358cf39e41494e949707927cee0af20a3ff553904c86b08f21cc414bcfd691589d27cf5e15369cbbff8b9a4c2eb17800855d0235ff635da82533ec6b759b69',
		'b58618f71f92e1d56c1b8c55ddd7cd188b97b4ca4d99831eb2699a837da2e4d970fbacfde50033aea585f1a2708510c32d07880801bd182898fe476876fc8965',
	] {
		name := if index < 3 { 'KMAC128' } else { 'KMAC256' }
		key := subtle.import_key(.raw_secret, material, name, true, [.sign, .verify], '')!
		params := KmacParams{ name: name.to_lower(), output_length: if index < 3 {
			u32(256)
		} else {
			u32(512)
		}, customization: if index in [0, 4] { []u8{} } else { custom } }
		message := if index in [0, 1, 3] { short } else { long }
		signature := subtle.sign(params, key, message)!
		assert signature.hex() == expected
		assert subtle.verify(params, key, signature, message)!
		mut changed := signature.clone()
		changed[0] ^= 1
		assert !subtle.verify(params, key, changed, message)!
		assert !subtle.verify(params, key, signature[..signature.len - 1], message)!
	}
}

fn test_kmac_key_generation_formats_and_metadata() {
	subtle := SubtleCrypto.create()
	for name in ['KMAC128', 'KMAC256'] {
		assert subtle.generate_key(AlgorithmParams{name: name}, false, [.sign])!.key != none
		generated := subtle.generate_key(KmacKeyGenParams{ name: name }, true, [
			.verify,
			.sign,
		])!
		key := generated.key or { panic('no secret key') }
		bits := if name == 'KMAC128' { u32(128) } else { u32(256) }
		assert key.type_ == .secret
		assert (key.algorithm as KmacKeyAlgorithm).length == bits
		assert key.handle().len == int(bits / 8)
		assert key.usages == [KeyUsage.sign, .verify]
		raw := subtle.export_key(.raw_secret, key)!
		jwk := subtle.export_jwk(key)!
		expected_alg := if name == 'KMAC128' { 'K128' } else { 'K256' }
		assert (jwk.alg or { '' }) == expected_alg
		assert jwk.ext or { false }
		assert subtle.import_jwk(jwk, name, true, [.sign], '')!.handle() == raw
		assert subtle.import_jwk(JsonWebKey{ ...jwk, use: 'sig' }, name, true, [.sign], '')!.handle() == raw
		assert subtle.import_key(.jwk, subtle.export_key(.jwk, key)!, name, true, [.verify], '')!.handle() == raw
	}
	key := subtle.import_key(.raw_secret, []u8{len: 32, init: 42}, KmacImportParams{ name: 'KMAC128', length: u32(255) }, false, [.sign], '')!
	assert (key.algorithm as KmacKeyAlgorithm).length == 255
	assert key.handle().len == 31 // Matches current upstream's length / 8 slicing.
	if _ := subtle.export_key(.raw_secret, key) {
		assert false
	} else {
		assert err.msg().starts_with('InvalidAccessError:')
	}
}

fn test_kmac_parameter_and_error_validation() {
	subtle := SubtleCrypto.create()
	parsed := KmacParams.from_value(json2.Any({
		'outputLength': json2.Any(f64(256))
	}))!
	assert parsed.output_length == 256
	if _ := KmacParams.from_value(json2.Any({
		'length': json2.Any(256)
	})) {
		assert false
	} else {
		assert err.msg().starts_with('TypeError:')
	}
	key := subtle.import_key(.raw_secret, []u8{len: 16}, 'KMAC128', false, [.sign], '')!
	for length in [u32(0), 1, 7, 9] {
		if _ := subtle.sign(KmacParams{ name: 'KMAC128', output_length: length }, key, []) {
			assert false
		} else {
			assert err.msg().starts_with('OperationError:')
		}
	}
	if _ := subtle.verify(KmacParams{ name: 'KMAC128', output_length: 256 }, key, [], []) {
		assert false
	} else {
		assert err.msg().starts_with('InvalidAccessError:')
	}
	if _ := subtle.sign('KMAC128', key, []) {
		assert false
	} else {
		assert err.msg() == 'TypeError: outputLength is required'
	}
	empty := subtle.generate_key(KmacKeyGenParams{ name: 'KMAC128', length: u32(0) }, false, [.sign])!.key or { panic('key') }
	assert empty.handle().len == 0
	assert (empty.algorithm as KmacKeyAlgorithm).length == 0
	assert empty.usages == [KeyUsage.sign]
	if _ := subtle.generate_key(KmacKeyGenParams{ name: 'KMAC128' }, false, [.encrypt]) {
		assert false
	} else {
		assert err.msg().starts_with('SyntaxError:')
	}
	if _ := subtle.import_key(.raw, key.handle(), 'KMAC128', false, [.sign], '') {
		assert false
	} else {
		assert err.msg().starts_with('NotSupportedError:')
	}
	for length in [u32(248), 257] {
		if _ := subtle.import_key(.raw_secret, []u8{len: 32}, KmacImportParams{ name: 'KMAC128', length: length }, false, [.sign], '') {
			assert false
		} else {
			assert err.msg().starts_with('DataError:')
		}
	}
	for jwk in [JsonWebKey{ kty: 'RSA', k: base64url_encode(key.handle()) },
		JsonWebKey{ kty: 'oct', k: base64url_encode(key.handle()), alg: 'K256' },
		JsonWebKey{ kty: 'oct', k: base64url_encode(key.handle()), use: 'sign' },
		JsonWebKey{ kty: 'oct', k: base64url_encode(key.handle()), key_ops: ['verify'] },
		JsonWebKey{ kty: 'oct', k: base64url_encode(key.handle()), ext: false }] {
		if _ := subtle.import_jwk(jwk, 'KMAC128', true, [.sign], '') {
			assert false
		} else {
			assert err.msg().starts_with('DataError:')
		}
	}
}
