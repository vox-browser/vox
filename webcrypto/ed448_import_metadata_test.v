// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

import webidl

fn test_ed448_source_import_defaults_and_common_metadata_all_formats() {
	subtle := SubtleCrypto.create()
	private_bytes := native_edwards_private('Ed448')!
	public_bytes := native_edwards_public('Ed448', private_bytes)!
	private_der := export_okp_der('Ed448', private_bytes, true)
	public_der := export_okp_der('Ed448', public_bytes, false)
	private_jwk := JsonWebKey{ kty: 'OKP', crv: 'Ed448', alg: 'Ed448', x: base64url_encode(public_bytes), d: base64url_encode(private_bytes), ext: true }
	for format in [KeyFormat.pkcs8, .jwk] {
		material := if format == .pkcs8 { private_der } else { private_jwk.to_json().bytes() }
		class_key := ED448.create().import_key(AlgorithmParams{}, format, material, true, [.sign])!
		assert class_key.type_ == .private_key && !class_key.extractable && class_key.usages.len == 0
		assert class_key.handle() == private_bytes
		assert ED448.create().export_key(.pkcs8, class_key)! == private_der
		assert ED448.create().import_key(AlgorithmParams{}, format, material, true, [])!.usages.len == 0
		common := subtle.import_key(format, material, 'Ed448', true, [.sign, .sign], '')!
		assert common.extractable && common.usages == [.sign]
		assert common.internal_handle() == class_key.internal_handle()
		if _ := subtle.import_key(format, material, 'Ed448', true, [], '') {
			assert false
		} else {
			assert err.msg() == 'SyntaxError: usages must not be empty'
		}
	}
	public_jwk := JsonWebKey{ ...private_jwk, d: none }
	for format in [KeyFormat.spki, .raw, .jwk] {
		material := match format {
			.spki { public_der }
			.raw { public_bytes }
			else { public_jwk.to_json().bytes() }
		}
		class_key := ED448.create().import_key(AlgorithmParams{}, format, material, true, [.verify])!
		assert class_key.type_ == .public_key && !class_key.extractable && class_key.usages.len == 0
		common := subtle.import_key(format, material, 'Ed448', true, [.verify], '')!
		assert common.extractable && common.usages == [.verify] && common.handle() == public_bytes
		assert subtle.import_key(format, material, 'Ed448', true, [], '')!.usages.len == 0
	}
}

@[heap]
struct Ed448MetadataHost {
mut:
	work []fn ()
}

fn test_ed448_normalized_algorithm_import_keeps_common_setters_at_outer_boundary() {
	private_bytes := native_edwards_private('Ed448')!
	material := export_okp_der('Ed448', private_bytes, true)
	params := normalize_binding_algorithm(webidl.string_value('Ed448'), 'importKey')!
	class_key := normalized_import(params, .pkcs8, material, true, [])!
	assert !class_key.extractable && class_key.usages.len == 0
	mut host := &Ed448MetadataHost{}
	binding := SubtleCryptoBinding.create(SubtleCrypto.create(), webidl.PromiseContext{}, fn [mut host] (task fn ()) {
		host.work << task
	}, fn (_ fn ()) {})
	promise := binding.import_key(.pkcs8, webidl.buffer_source_value(webidl.BufferSource.array_buffer(material)), webidl.string_value('Ed448'), true, [.sign])
	host.work[0]()
	assert promise.state == .fulfilled
	key := crypto_key_from_value(promise.result)!
	assert key.extractable && key.usages == [.sign] && key.handle() == private_bytes
	empty := binding.import_key(.pkcs8, webidl.buffer_source_value(webidl.BufferSource.array_buffer(material)), webidl.string_value('Ed448'), true, [])
	host.work[1]()
	assert empty.state == .rejected && empty.result.object_value['message'].string_value == 'usages must not be empty'
}
