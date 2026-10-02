// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

import webidl

fn test_exchange_source_class_import_defaults_and_common_metadata_all_formats() {
	subtle := SubtleCrypto.create()
	for name in ['X25519', 'X448'] {
		material := native_edwards_private(name)!
		public_bytes := native_edwards_public(name, material)!
		private_der := export_okp_der(name, material, true)
		public_der := export_okp_der(name, public_bytes, false)
		jwk := JsonWebKey{
			kty:     'OKP'
			crv:     name
			x:       base64url_encode(public_bytes)
			d:       base64url_encode(material)
			ext:     true
			key_ops: [
				'deriveKey',
				'deriveBits',
			]
		}
		for format in [KeyFormat.pkcs8, .jwk] {
			bytes := if format == .pkcs8 { private_der } else { jwk.to_json().bytes() }
			class_key := import_exchange_key(name, format, bytes, true, [.derive_bits, .derive_key])!
			assert class_key.type_ == .private_key && !class_key.extractable && class_key.usages.len == 0
			assert class_key.handle() == material
			assert export_exchange_key(name, .pkcs8, class_key)! == private_der
			common := subtle.import_key(format, bytes, name, true, [.derive_bits, .derive_key,
				.derive_bits], '')!
			assert common.extractable && common.usages == [.derive_key, .derive_bits, .derive_bits]
			assert common.internal_handle() == class_key.internal_handle()
			assert import_exchange_key(name, format, bytes, true, [])!.usages.len == 0
			if _ := subtle.import_key(format, bytes, name, true, [], '') {
				assert false
			} else {
				assert err.msg() == 'SyntaxError: usages must not be empty'
			}
		}
		public_jwk := JsonWebKey{ ...jwk, d: none, key_ops: []string{} }
		for format in [KeyFormat.spki, .raw, .jwk] {
			bytes := match format {
				.spki { public_der }
				.raw { public_bytes }
				else { public_jwk.to_json().bytes() }
			}
			class_key := import_exchange_key(name, format, bytes, true, [])!
			assert class_key.type_ == .public_key && !class_key.extractable && class_key.usages.len == 0
			common := subtle.import_key(format, bytes, name, true, [], '')!
			assert common.extractable && common.usages.len == 0 && common.handle() == public_bytes
		}
		if name == 'X25519' {
			assert !X25519.create().import_key(AlgorithmParams{}, .raw_public, public_bytes, true, [])!.extractable
			assert subtle.import_key(.raw_public, public_bytes, name, true, [], '')!.extractable
		}
	}
}

@[heap]
struct ExchangeMetadataHost {
mut:
	tasks []fn ()
}

fn test_exchange_async_import_installs_source_metadata_after_copied_class_import() {
	mut host := &ExchangeMetadataHost{}
	binding := SubtleCryptoBinding.create(SubtleCrypto.create(), webidl.PromiseContext{}, fn [mut host] (task fn ()) {
		host.tasks << task
	}, fn (_ fn ()) {})
	for index, name in ['X25519', 'X448'] {
		material := native_edwards_private(name)!
		mut source := webidl.BufferSource.array_buffer(export_okp_der(name, material, true))
		promise := binding.import_key(.pkcs8, webidl.buffer_source_value(source), webidl.string_value(name), true, [.derive_bits])
		source.write([]u8{len: int(source.byte_length())}, 0)!
		assert promise.state == .pending
		host.tasks[index]()
		assert promise.state == .fulfilled
		key := crypto_key_from_value(promise.result)!
		assert key.type_ == .private_key && key.extractable && key.usages == [.derive_bits]
		assert key.handle() == material
	}
}
