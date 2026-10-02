// SPDX-License-Identifier: BSD-2-Clause
module webcrypto

fn test_ec_der_peek_preserves_source_high_tag_initial_byte_and_u8_kind() {
	for vector in [
		DerPeekVector{
			bytes: [u8(0x3f)]
			kind:  0
		},
		DerPeekVector{
			bytes: [u8(0x1f)]
			kind:  0
		},
		DerPeekVector{
			bytes: [u8(0xbf), 0x10]
			kind:  16
		},
		DerPeekVector{
			bytes: [u8(0xbf), 0x82, 0x00]
			kind:  0
		},
		DerPeekVector{
			bytes: [u8(0xbf), 0x82, 0x01]
			kind:  1
		},
	] {
		reader := OkpDerReader{
			bytes: vector.bytes
		}
		assert reader.ec_peek_kind()! == vector.kind
		assert reader.position == 0
	}
	reader := OkpDerReader{
		bytes: [u8(0xbf)]
	}
	if _ := reader.ec_peek_kind() {
		assert false
	} else {
		assert err.msg() == 'DataError: ASN1::Decoder: Reading byte from an empty entry'
	}
	assert reader.position == 0
}

fn test_der_sequence_type_belongs_to_original_tag() {
	mut reader := OkpDerReader{
		bytes: [u8(0xbf), 0x10, 0x02, 0x05, 0x00]
	}
	assert reader.read(true)! == [u8(5), 0]
	reader.exact()!
	mut primitive := OkpDerReader{
		bytes: [u8(0x9f), 0x10, 0x00]
	}
	if _ := primitive.read(true) {
		assert false
	} else {
		assert err.msg() == 'DataError: ASN1::Decoder: Expected a constructed Sequence'
	}
}

fn test_ec_private_optional_curve_high_tag_cannot_bypass_source_validation() {
	subtle := SubtleCrypto.create()
	params := EcKeyImportParams{
		name:        'ECDSA'
		named_curve: 'P-256'
	}
	pair := subtle.generate_key(EcKeyGenParams{ name: 'ECDSA', named_curve: 'P-256' }, true, [
		.sign,
	])!.pair or { panic('pair') }
	key := pair.private_key
	handle := key.internal_handle() as EcPrivateKeyHandle
	for tag in [[u8(0x3f)], [u8(0xbf), 0x82, 0x00]] {
		mut body := [u8(2), 1, 1]
		body << okp_der_value(4, handle.d)
		curve := ec_encode_oid(ec_curve_oid('P-384'))!
		body << tag
		// These source tags retain the existing field's normal DER length.
		body << u8(curve.len)
		body << curve
		inner := okp_der_value(0x30, body)
		parsed := parse_ec_private(inner)!
		assert parsed.parameters? == ec_curve_oid('P-384')
		mut algorithm := ec_encode_oid(ec_public_key_oid.map(int(it)))!
		algorithm << ec_encode_oid(ec_curve_oid('P-256'))!
		mut info := [u8(2), 1, 0]
		info << okp_der_value(0x30, algorithm)
		info << okp_der_value(4, inner)
		if _ := subtle.import_key(.pkcs8, okp_der_value(0x30, info), params, true, [
			.sign,
		], '')
		{
			assert false
		} else {
			assert err.msg() == 'DataError: Invalid algorithm parameters'
		}
	}
}

struct DerPeekVector {
	bytes []u8
	kind  u32
}
