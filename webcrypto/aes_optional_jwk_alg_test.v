// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

// Ladybird de36f3b0390167ee33e3fbe9da600d31369da0ba.
fn test_aes_jwk_without_alg_imports_and_exports_the_selected_algorithm() {
	subtle := SubtleCrypto.create()
	for name in ['AES-CBC', 'AES-CTR', 'AES-GCM', 'AES-KW', 'AES-OCB'] {
		usage := if name == 'AES-KW' { KeyUsage.wrap_key } else { KeyUsage.encrypt }
		for size in [16, 24, 32] {
			jwk := JsonWebKey{ kty: 'oct', k: base64url_encode([]u8{len: size}) }
			key := subtle.import_jwk(jwk, name, true, [usage], '')!
			assert key.handle().len == size
			assert subtle.export_jwk(key)!.alg? == 'A${size * 8}${name[4..]}'
			if _ := subtle.import_jwk(JsonWebKey{ ...jwk, alg: 'wrong' }, name, true, [usage], '') {
				assert false
			} else {
				assert err.msg().starts_with('DataError:')
			}
		}
	}
}
