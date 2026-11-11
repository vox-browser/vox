// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

// Ladybird 37b74df276ffcd28e206b4f609cc1479505343d4.
fn test_raw_ec_import_validates_the_point_on_the_requested_curve() {
	subtle := SubtleCrypto.create()
	for name in ['ECDSA', 'ECDH'] {
		usages := if name == 'ECDSA' { [KeyUsage.verify] } else { []KeyUsage{} }
		generate_usages := if name == 'ECDSA' { [KeyUsage.sign, .verify] } else { [KeyUsage.derive_bits] }
		pair := subtle.generate_key(EcKeyGenParams{ name: name, named_curve: 'P-256' }, true, generate_usages)!.pair or { panic('pair') }
		raw := subtle.export_key(.raw, pair.public_key)!
		for format in [KeyFormat.raw, .raw_public] {
			key := subtle.import_key(format, raw, EcKeyImportParams{ name: name, named_curve: 'P-256' }, true, usages, '')!
			assert key.ec_algorithm().named_curve == 'P-256'
			for curve in ['P-384', 'P-521'] {
				if _ := subtle.import_key(format, raw, EcKeyImportParams{ name: name, named_curve: curve }, true, usages, '') {
					assert false
				} else {
					assert err.msg().starts_with('DataError:')
				}
			}
			mut off_curve := raw.clone()
			off_curve[off_curve.len - 1] ^= 1
			if _ := subtle.import_key(format, off_curve, EcKeyImportParams{ name: name, named_curve: 'P-256' }, true, usages, '') {
				assert false
			} else {
				assert err.msg().starts_with('DataError:')
			}
		}
	}
}
