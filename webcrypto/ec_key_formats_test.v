// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

import encoding.hex
import webidl

struct EcFormatVector {
	curve string
	spki  string
	pkcs8 string
}

// Pinned WPT sign_verify/ecdsa_vectors.js.
const ec_format_vectors = [
	EcFormatVector{ curve: 'P-256', spki: '3059301306072a8648ce3d020106082a8648ce3d030107034200040a051e386f67c4a6e1e5cbee7d37745b588ebe720f755916286f9629697a391711d86aeac96708d23a2623d8c6edbb54d9a43f64066931800f351d9e75ebee1e', pkcs8: '308187020100301306072a8648ce3d020106082a8648ce3d030107046d306b0201010420e6eecf9e626cca8e18079b92c5ee269e54ca128eafd48947ff51aba00ac0e5d6a144034200040a051e386f67c4a6e1e5cbee7d37745b588ebe720f755916286f9629697a391711d86aeac96708d23a2623d8c6edbb54d9a43f64066931800f351d9e75ebee1e' },
	EcFormatVector{ curve: 'P-384', spki: '3076301006072a8648ce3d020106052b81040022036200041d319d692dca5f5754ba7b32c11642c6d8d2b4fb8249c3f214d71e90b5252966d97f7beb1faab1e4f3e2605549c2eedb520329b3bea6b5e55624a15150a16966635f1916ef04dd758e69409d0633cb4b25994179b22a769c743436910e799951', pkcs8: '3081b6020100301006072a8648ce3d020106052b8104002204819e30819b020101043002a9a0d899efa87e7564110907e9d82c21bd6265a37abd9a6fdb0f80ec844dd3a1425320d67ddc30f5db74efb9a2e661a164036200041d319d692dca5f5754ba7b32c11642c6d8d2b4fb8249c3f214d71e90b5252966d97f7beb1faab1e4f3e2605549c2eedb520329b3bea6b5e55624a15150a16966635f1916ef04dd758e69409d0633cb4b25994179b22a769c743436910e799951' },
	EcFormatVector{ curve: 'P-521', spki: '30819b301006072a8648ce3d020106052b81040023038186000400a6deecfb489117f1e41cc4a064073d8673086e51db25086e8db764d4eff60aad6358fdcf967ac68459275e2a804f8eeeb7e4c4284b1451c0a5ea76fe7007ac054701c5eddaf9a89e7c4fdcc924c737d8f585da9703a954c23be7c14aafa66654b256770a938e7f26e700c603931c7bd0bdb5d0632c7d1eab466f09d976c24a323e1b7c', pkcs8: '3081ee020100301006072a8648ce3d020106052b810400230481d63081d3020101044201533e618f98ead1b513ec8878c8820d377a36d8f03f2ba046c931825a3d358730c0b26033dbb7f7e4a3d4434a035e24b707f9124766176e1af0b85df22eaaba9c25a18189038186000400a6deecfb489117f1e41cc4a064073d8673086e51db25086e8db764d4eff60aad6358fdcf967ac68459275e2a804f8eeeb7e4c4284b1451c0a5ea76fe7007ac054701c5eddaf9a89e7c4fdcc924c737d8f585da9703a954c23be7c14aafa66654b256770a938e7f26e700c603931c7bd0bdb5d0632c7d1eab466f09d976c24a323e1b7c' },
]

fn ec_test_key_info(curve string, material []u8, private_key bool) []u8 {
	mut algorithm := ec_encode_oid(ec_public_key_oid.map(int(it))) or { panic(err) }
	algorithm << ec_encode_oid(ec_curve_oid(curve)) or { panic(err) }
	mut body := []u8{}
	if private_key { body << [u8(2), 1, 0] }
	body << okp_der_value(0x30, algorithm)
	if private_key {
		body << okp_der_value(4, material)
	} else {
		mut bitstring := [u8(0)]
		bitstring << material
		body << okp_der_value(3, bitstring)
	}
	return okp_der_value(0x30, body)
}

fn test_ec_formats_exact_source_der_and_jwk_reach_real_operations() {
	subtle := SubtleCrypto.create()
	for vector in ec_format_vectors {
		for name in ['ECDSA', 'ECDH'] {
			params := EcKeyImportParams{ name: name, named_curve: vector.curve }
			public_usages := if name == 'ECDSA' { [KeyUsage.verify] } else { []KeyUsage{} }
			private_usages := if name == 'ECDSA' {
				[KeyUsage.sign]
			} else {
				[KeyUsage.derive_bits, .derive_key]
			}
			public_key := subtle.import_key(.spki, hex.decode(vector.spki)!, params, true, public_usages, '')!
			private_key := subtle.import_key(.pkcs8, hex.decode(vector.pkcs8)!, params, true, private_usages, '')!
			assert subtle.export_key(.spki, public_key)!.hex() == vector.spki
			assert subtle.export_key(.pkcs8, private_key)!.hex() == vector.pkcs8
			public_jwk := subtle.export_jwk(public_key)!
			private_jwk := subtle.export_jwk(private_key)!
			assert public_jwk.kty? == 'EC' && private_jwk.crv? == vector.curve
			assert private_jwk.alg == none && private_jwk.use == none && private_jwk.d != none
			restored := subtle.import_jwk(private_jwk, params, true, private_usages, '')!
			public_restored := subtle.import_jwk(public_jwk, params, true, public_usages, '')!
			assert restored.internal_handle() == private_key.internal_handle()
			assert public_restored.internal_handle() == public_key.internal_handle()
			raw := subtle.export_key(.raw, public_key)!
			assert subtle.export_key(.raw_public, public_key)! == raw
			assert subtle.import_key(.raw, raw, params, true, public_usages, '')!.internal_handle() == public_key.internal_handle()
			assert subtle.import_key(.raw_public, raw, params, true, public_usages, '')!.internal_handle() == public_key.internal_handle()
			if name == 'ECDSA' {
				signature := subtle.sign(EcdsaParams{ hash: 'SHA-256' }, restored, 'source'.bytes())!
				assert subtle.verify(EcdsaParams{ hash: 'SHA-256' }, public_restored, signature, 'source'.bytes())!
			} else {
				result := subtle.derive_bits(EcdhKeyDeriveParams{ name: 'ECDH', public_key: public_restored }, restored, none)!
				assert result.len == ec_scalar_size(vector.curve)
			}
		}
	}
}

fn test_ec_compressed_unprefixed_raw_and_source_validation_boundary() {
	subtle := SubtleCrypto.create()
	for vector in ec_format_vectors {
		params := EcKeyImportParams{ name: 'ECDSA', named_curve: vector.curve }
		key := subtle.import_key(.spki, hex.decode(vector.spki)!, params, true, [.verify], '')!
		point := key.internal_handle() as EcPublicKeyHandle
		mut compressed := [u8(2 + (point.y.last() & 1))]
		compressed << point.x
		assert subtle.import_key(.raw, compressed, params, true, [.verify], '')!.internal_handle() == key.internal_handle()
		assert subtle.import_key(.spki, ec_test_key_info(vector.curve, compressed, false), params, true, [.verify], '')!.internal_handle() == key.internal_handle()
		mut unprefixed := point.x.clone()
		unprefixed << point.y
		assert subtle.import_key(.raw, unprefixed, params, true, [.verify], '')!.internal_handle() == key.internal_handle()
		// Source raw parser neither checks curve membership nor the named scalar width.
		raw_bad := [u8(4), 0, 0]
		parsed := subtle.import_key(.raw, raw_bad, params, true, [.verify], '')!
		assert (parsed.internal_handle() as EcPublicKeyHandle).x == [u8(0)]
		if _ := subtle.import_key(.spki, ec_test_key_info(vector.curve, raw_bad, false), params, true, [.verify], '') {
			assert false
		} else {
			assert err.msg() == 'DataError: Invalid key'
		}
		if _ := subtle.import_key(.raw, [u8(4), 0], params, true, [.verify], '') {
			assert false
		} else {
			assert err.msg() == 'DataError: Failed to parse key'
		}
	}
	// Compressed size chooses the decoding curve before attaching requested metadata.
	vector := ec_format_vectors[0]
	p256 := subtle.import_key(.spki, hex.decode(vector.spki)!, EcKeyImportParams{ name: 'ECDSA', named_curve: 'P-256' }, true, [.verify], '')!
	point := p256.internal_handle() as EcPublicKeyHandle
	mut compressed := [u8(2 + (point.y.last() & 1))]
	compressed << point.x
	wrong_curve := subtle.import_key(.raw, compressed, EcKeyImportParams{ name: 'ECDSA', named_curve: 'P-384' }, true, [.verify], '')!
	assert (wrong_curve.algorithm as EcKeyAlgorithm).named_curve == 'P-384'
	assert wrong_curve.internal_handle() == p256.internal_handle()
	if _ := subtle.import_key(.spki, hex.decode(vector.spki)!, EcKeyImportParams{ name: 'ECDSA', named_curve: 'P-384' }, true, [.verify], '') {
		assert false
	} else {
		assert err.msg() == 'DataError: Invalid algorithm'
	}
}

fn test_ec_private_optional_fields_validation_and_export_preserve_source() {
	subtle := SubtleCrypto.create()
	vector := ec_format_vectors[0]
	params := EcKeyImportParams{ name: 'ECDSA', named_curve: vector.curve }
	key := subtle.import_key(.pkcs8, hex.decode(vector.pkcs8)!, params, true, [.sign], '')!
	handle := key.internal_handle() as EcPrivateKeyHandle
	// Missing public point is accepted; PKCS8 retains its absence; JWK recomputes it.
	without_point := EcPrivateKeyHandle{ d: handle.d }
	der := ec_test_key_info(vector.curve, export_ec_private(without_point)!, true)
	imported := subtle.import_key(.pkcs8, der, params, true, [.sign], '')!
	assert (imported.internal_handle() as EcPrivateKeyHandle).public_key == none
	assert subtle.export_key(.pkcs8, imported)! == der
	jwk := subtle.export_jwk(imported)!
	assert jwk.x? == subtle.export_jwk(key)!.x? && jwk.y? == subtle.export_jwk(key)!.y?
	// Inner parameters are preserved only if present and must match the outer curve.
	with_parameters := EcPrivateKeyHandle{ ...handle, parameters: ec_curve_oid(vector.curve) }
	parameter_der := ec_test_key_info(vector.curve, export_ec_private(with_parameters)!, true)
	assert subtle.export_key(.pkcs8, subtle.import_key(.pkcs8, parameter_der, params, true, [.sign], '')!)! == parameter_der
	wrong_parameters := EcPrivateKeyHandle{ ...handle, parameters: ec_curve_oid('P-384') }
	if _ := subtle.import_key(.pkcs8, ec_test_key_info(vector.curve, export_ec_private(wrong_parameters)!, true), params, true, [.sign], '') {
		assert false
	} else {
		assert err.msg() == 'DataError: Invalid algorithm parameters'
	}
	mut wrong_d := handle.d.clone()
	wrong_d[wrong_d.len - 1] ^= 1
	if _ := subtle.import_key(.pkcs8, ec_test_key_info(vector.curve, export_ec_private(EcPrivateKeyHandle{ ...handle, d: wrong_d })!, true), params, true, [.sign], '') {
		assert false
	} else {
		assert err.msg() == 'DataError: Invalid key'
	}
	short_handle := EcPrivateKeyHandle{ ...handle, d: handle.d[1..].clone() }
	if _ := subtle.import_key(.pkcs8, ec_test_key_info(vector.curve, export_ec_private(short_handle)!, true), params, true, [.sign], '') {
		assert false
	} else {
		assert err.msg() == 'DataError: Invalid public key length'
	}
	// Source accepts zero d without a public point; JWK's d*G cannot be encoded.
	zero_der := ec_test_key_info(vector.curve, export_ec_private(EcPrivateKeyHandle{ d: [u8(0)] })!, true)
	zero_key := subtle.import_key(.pkcs8, zero_der, params, true, [.sign], '')!
	if _ := subtle.export_jwk(zero_key) {
		assert false
	} else {
		assert err.msg() == 'DataError: Failed to encode public key'
	}
	// Inner trailing bytes are not checked by source EC::parse_ec_key.
	mut inner := export_ec_private(handle)!
	inner << [u8(5), 0]
	assert subtle.import_key(.pkcs8, ec_test_key_info(vector.curve, inner, true), params, true, [.sign], '')!.internal_handle() == key.internal_handle()
}

fn test_ec_jwk_metadata_and_native_key_validation_rejections() {
	subtle := SubtleCrypto.create()
	params := EcKeyImportParams{ name: 'ECDSA', named_curve: 'P-256' }
	key := subtle.import_key(.pkcs8, hex.decode(ec_format_vectors[0].pkcs8)!, params, true, [.sign], '')!
	jwk := subtle.export_jwk(key)!
	for variant in [JsonWebKey{ ...jwk, kty: 'RSA' }, JsonWebKey{ ...jwk, use: 'enc' },
		JsonWebKey{ ...jwk, ext: false }, JsonWebKey{ ...jwk, crv: none },
		JsonWebKey{ ...jwk, crv: 'P-384' }, JsonWebKey{ ...jwk, alg: 'ES384' },
		JsonWebKey{ ...jwk, x: none }, JsonWebKey{ ...jwk, x: '$$' }, JsonWebKey{ ...jwk, y: 'AA' },
		JsonWebKey{ ...jwk, d: base64_url_bytes_encode([]u8{len: 32}) }] {
		if _ := subtle.import_jwk(variant, params, true, [.sign], '') {
			assert false
		} else {
			assert err.msg().starts_with('DataError:')
		}
	}
	assert subtle.import_jwk(JsonWebKey{ ...jwk, alg: 'ES256' }, params, true, [.sign], '')!.internal_handle() == key.internal_handle()
	if _ := ECDSA.create().import_key(params, .spki, [], true, [.sign]) {
		assert false
	} else {
		assert err.msg() == "SyntaxError: Invalid key usage 'sign'"
	}
	if _ := ECDSA.create().import_key(EcKeyImportParams{ named_curve: 'bad' }, .raw, [], true, [.sign]) {
		assert false
	} else {
		assert err.msg() == "NotSupportedError: Unsupported named curve 'bad'"
	}
	if _ := ECDH.create().import_key(params, .raw, [], true, [.derive_bits]) {
		assert false
	} else {
		assert err.msg() == 'SyntaxError: Usages must be empty'
	}
	if _ := subtle.import_key(.pkcs8, hex.decode(ec_format_vectors[0].pkcs8)!, params, true, [], '') {
		assert false
	} else {
		assert err.msg() == 'SyntaxError: usages must not be empty'
	}
	if _ := subtle.export_key(.raw, key) {
		assert false
	} else {
		assert err.msg() == 'InvalidAccessError: Key is not a public key'
	}
}

@[heap]
struct EcFormatsBindingHost {
mut:
	work   []fn ()
	settle []fn ()
}

fn test_ec_binding_import_export_copies_bytes_and_reaches_native_key() {
	mut host := &EcFormatsBindingHost{}
	binding := SubtleCryptoBinding.create(SubtleCrypto.create(), webidl.PromiseContext{}, fn [mut host] (task fn ()) {
		host.work << task
	}, fn [mut host] (task fn ()) { host.settle << task })
	mut material := webidl.BufferSource.array_buffer(hex.decode(ec_format_vectors[2].pkcs8)!)
	algorithm := webidl.object_value({
		'name':       webidl.string_value('ECDSA')
		'namedCurve': webidl.string_value('P-521')
	})
	promise := binding.import_key(.pkcs8, webidl.buffer_source_value(material), algorithm, true, [.sign])
	material.write([u8(0)], 0)!
	host.work[0]()
	assert promise.state == .fulfilled
	key := crypto_key_from_value(promise.result)!
	assert key.usages == [KeyUsage.sign] && key.extractable
	assert (key.algorithm as EcKeyAlgorithm).named_curve == 'P-521'
	exported := binding.export_key(.pkcs8, key)
	host.work[1]()
	assert exported.state == .fulfilled
	bytes := exported.result.buffer_value or { panic('bytes') }
	assert webidl.get_buffer_source_copy(bytes).hex() == ec_format_vectors[2].pkcs8
	signature := SubtleCrypto.create().sign(EcdsaParams{ hash: 'SHA-512' }, key, 'real'.bytes())!
	assert signature.len == 132
}

fn test_ec_binding_derive_and_wrapped_import_reach_real_operations() {
	mut host := &EcFormatsBindingHost{}
	subtle := SubtleCrypto.create()
	binding := SubtleCryptoBinding.create(subtle, webidl.PromiseContext{}, fn [mut host] (task fn ()) {
		host.work << task
	}, fn [mut host] (task fn ()) { host.settle << task })
	params := EcKeyImportParams{ name: 'ECDH', named_curve: 'P-256' }
	private_key := subtle.import_key(.pkcs8, hex.decode(ec_format_vectors[0].pkcs8)!, params, true, [.derive_bits], '')!
	public_key := subtle.import_key(.spki, hex.decode(ec_format_vectors[0].spki)!, params, true, [], '')!
	derive_algorithm := webidl.object_value({
		'name':   webidl.string_value('ECDH')
		'public': crypto_key('', public_key)
	})
	derived := binding.derive_bits(derive_algorithm, private_key, 9)
	host.work[0]()
	assert derived.state == .fulfilled && host.settle.len == 0
	derived_bytes := derived.result.buffer_value or { panic('derived bytes') }
	assert webidl.get_buffer_source_copy(derived_bytes) == subtle.derive_bits(EcdhKeyDeriveParams{ name: 'ECDH', public_key: public_key }, private_key, 9)!
	wrapping_key := subtle.import_key(.raw, []u8{len: 16}, 'AES-GCM', true, [
		.wrap_key,
		.unwrap_key,
	], '')!
	algorithm := webidl.object_value({
		'name': webidl.string_value('AES-GCM')
		'iv':   webidl.buffer_source_value(webidl.BufferSource.array_buffer([]u8{len: 12}))
	})
	wrapped := binding.wrap_key(.pkcs8, private_key, wrapping_key, algorithm)
	host.work[1]()
	assert wrapped.state == .fulfilled
	wrapped_bytes := wrapped.result.buffer_value or { panic('wrapped bytes') }
	import_algorithm := webidl.object_value({
		'name':       webidl.string_value('ECDH')
		'namedCurve': webidl.string_value('P-256')
	})
	unwrapped := binding.unwrap_key(.pkcs8, wrapped_bytes, wrapping_key, algorithm, import_algorithm, true, [.derive_bits])
	host.work[2]()
	assert unwrapped.state == .fulfilled
	assert crypto_key_from_value(unwrapped.result)!.internal_handle() == private_key.internal_handle()
}
