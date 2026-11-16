// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
// CryptoAlgorithms.cpp EC formats, Certificate.cpp, PK/EC.cpp and ASN1/DER.cpp.
module webcrypto

const ec_public_key_oid = [u32(1), 2, 840, 10045, 2, 1]

fn ec_curve_oid(curve string) []int {
	return match curve {
		'P-256' { [1, 2, 840, 10045, 3, 1, 7] }
		'P-384' { [1, 3, 132, 0, 34] }
		'P-521' { [1, 3, 132, 0, 35] }
		else { []int{} }
	}
}

fn ec_curve_from_oid(oid []int) !string {
	for curve in ['P-256', 'P-384', 'P-521'] {
		if oid == ec_curve_oid(curve) { return curve }
	}
	return error('DataError: Unknown named curve ${oid}')
}

fn ec_encode_oid(segments []int) ![]u8 {
	if segments.len < 2 {
		return error('ASN1::Encoder: Object identifier must have at least two segments')
	}
	mut bytes := [u8(segments[0] * 40 + segments[1])]
	for segment in segments[2..] {
		if segment < 0 {
			return error('ASN1::Encoder: Object identifier segments must be non-negative')
		}
		if segment < 0x80 {
			bytes << u8(segment)
		} else if segment < 0x4000 {
			bytes << [u8((segment >> 7) | 0x80), u8(segment & 0x7f)]
		} else if segment < 0x200000 {
			bytes << [u8((segment >> 14) | 0x80), u8(((segment >> 7) & 0x7f) | 0x80),
				u8(segment & 0x7f)]
		} else {
			bytes << [u8((segment >> 21) | 0x80), u8(((segment >> 14) & 0x7f) | 0x80),
				u8(((segment >> 7) & 0x7f) | 0x80), u8(segment & 0x7f)]
		}
	}
	return okp_der_value(0x06, bytes)
}

fn parse_ec_public(bytes []u8) !EcPublicKeyHandle {
	if bytes.len == 0 { return error('DataError: Invalid public key length') }
	if bytes[0] in [u8(2), 3] { return native_ec_decompress(bytes) }
	if bytes[0] == 4 {
		if bytes.len < 3 {
			return error('DataError: Invalid length or not an uncompressed SECPxxxr1 point')
		}
		half := (bytes.len - 1) / 2
		if half * 2 + 1 != bytes.len {
			return error('DataError: Invalid uncompressed SECPxxxr1 point length')
		}
		return EcPublicKeyHandle{ x: bytes[1..half + 1].clone(), y: bytes[half + 1..].clone() }
	}
	if bytes.len % 2 == 0 {
		return EcPublicKeyHandle{ x: bytes[..bytes.len / 2].clone(), y: bytes[bytes.len / 2..].clone() }
	}
	return error('DataError: Unsupported public key format')
}

fn (reader &OkpDerReader) ec_peek_kind() !u32 {
    mut working_copy := OkpDerReader{ bytes: reader.bytes, position: reader.position }
    mut byte := working_copy.byte()!
    mut kind := byte & 0x1f
    if kind == 0x1f {
        kind = 0
        // Preserve DER.cpp's initial-byte condition and u8 truncation.
        for byte & 0x80 != 0 {
            byte = working_copy.byte()!
            kind = (kind << 7) | (byte & 0x7f)
        }
    }
    return u32(kind)
}

fn (mut reader OkpDerReader) enter_ec_optional() ![]u8 {
	if reader.bytes[reader.position] & 0x20 == 0 {
		return error('DataError: ASN1::Decoder: Entering a non-constructed type')
	}
	// Source REWRITE_TAG(Sequence) retains the constructed bit and skips kind.
	return reader.read_contents(false, true)
}

fn parse_ec_parameters(mut reader OkpDerReader) ![]int {
	oid := decode_okp_oid(reader.read(false)!)!.map(int(it))
	ec_curve_from_oid(oid)!
	return oid
}

fn parse_ec_private(bytes []u8) !EcPrivateKeyHandle {
	mut outer := OkpDerReader{ bytes: bytes }
	mut body := OkpDerReader{ bytes: outer.read(true)! }
	if body.read_rsa_integer()! != [u8(1)] { return error('DataError: Invalid version') }
	d := body.read(false)!
	mut parameters := ?[]int(none)
	if body.position < body.bytes.len && body.ec_peek_kind()! == 0 {
		mut scope := OkpDerReader{ bytes: body.enter_ec_optional()! }
		parameters = parse_ec_parameters(mut scope)!
	}
	mut point := ?EcPublicKeyHandle(none)
	if body.position < body.bytes.len && body.ec_peek_kind()! == 1 {
		mut scope := OkpDerReader{ bytes: body.enter_ec_optional()! }
		bitstring := scope.read(false)!
		if bitstring.len == 0 || bitstring[0] != 0 {
			return error('DataError: ASN1::BitStringView: Cannot get raw bytes with unused bits')
		}
		public_key := parse_ec_public(bitstring[1..])!
		if public_key.x.len != d.len { return error('DataError: Invalid public key length') }
		point = public_key
	}
	// EXIT_SCOPE discards unread nested DER, preserving optional fields as read.
	return EcPrivateKeyHandle{ d: d, parameters: parameters, public_key: point }
}

struct EcKeyInfo {
	curve  string
	handle CryptoKeyInternalHandle
}

fn parse_ec_key_info(bytes []u8, private_key bool) !EcKeyInfo {
	mut outer := OkpDerReader{ bytes: bytes }
	mut body := OkpDerReader{ bytes: outer.read(true)! }
	outer.exact()!
	if private_key && body.read_rsa_integer()! != [u8(0)] {
		return error('DataError: Invalid version value')
	}
	mut algorithm := OkpDerReader{ bytes: body.read(true)! }
	if decode_okp_oid(algorithm.read(false)!)! != ec_public_key_oid {
		return error('DataError: Invalid algorithm')
	}
	mut parameters := ?[]int(none)
	if algorithm.position < algorithm.bytes.len {
		if algorithm.ec_peek_kind()! == 5 {
			if algorithm.read(false)!.len != 0 {
				return error('DataError: ASN1::Decoder: Decoding null from a non-empty span')
			}
		} else {
			parameters = parse_ec_parameters(mut algorithm)!
		}
	}
	material := body.read(false)!
	mut handle := CryptoKeyInternalHandle(ByteBufferKeyHandle{})
	if private_key {
		handle = parse_ec_private(material)!
	} else {
		if material.len == 0 || material[0] != 0 {
			return error('DataError: ASN1::BitStringView: Cannot get raw bytes with unused bits')
		}
		handle = parse_ec_public(material[1..])!
	}
	outer_parameters := parameters or { return error('DataError: Invalid algorithm parameters') }
	curve := ec_curve_from_oid(outer_parameters)!
	if handle is EcPrivateKeyHandle {
		if inner := handle.parameters {
			if inner != outer_parameters { return error('DataError: Invalid algorithm parameters') }
		}
	}
	return EcKeyInfo{ curve: curve, handle: handle }
}

fn validate_ec_usages(name string, private_key bool, usages []KeyUsage) ! {
	if name == 'ECDH' && !private_key && usages.len != 0 {
		return error('SyntaxError: Usages must be empty')
	}
	allowed := if name == 'ECDH' {
		[KeyUsage.derive_key, .derive_bits]
	} else if private_key {
		[KeyUsage.sign]
	} else {
		[KeyUsage.verify]
	}
	for usage in usages {
		if usage !in allowed {
			return error("SyntaxError: Invalid key usage '${key_usage_string(usage)}'")
		}
	}
}

fn validate_ec_handle(curve string, handle CryptoKeyInternalHandle) ! {
	valid := match handle {
		EcPublicKeyHandle { native_ec_valid(curve, handle, none)! }
		EcPrivateKeyHandle {
			if point := handle.public_key { native_ec_valid(curve, point, handle.d)! } else { true }
		}
		else { panic('Invalid EC handle') }
	}
	if !valid { return error('DataError: Invalid key') }
}

fn decode_ec_jwk_scalar(encoded string, size int) ![]u8 {
	bytes := base64url_decode(encoded) or { return error('DataError: Failed to decode base64') }
	if bytes.len != size { return error('DataError: Invalid key size') }
	return bytes
}

fn parse_ec_jwk(params EcKeyImportParams, jwk JsonWebKey, extractable bool, usages []KeyUsage) !CryptoKeyInternalHandle {
	private_key := jwk.d != none
	validate_ec_usages(params.name, private_key, usages)!
	if (jwk.kty or { '' }) != 'EC' { return error('DataError: Invalid key type') }
	if usages.len != 0 {
		if use := jwk.use {
			if use != (if params.name == 'ECDH' { 'enc' } else { 'sig' }) {
				return error('DataError: Invalid key use')
			}
		}
	}
	validate_jwk_key_ops(jwk, usages)!
	if ext := jwk.ext {
		if !ext && extractable { return error('DataError: Invalid extractable') }
	}
	curve := jwk.crv or { return error('DataError: Invalid key crv') }
	if curve != params.named_curve { return error('DataError: Invalid algorithm') }
	size := ec_scalar_size(curve)
	if size == 0 { return error('DataError: Invalid algorithm') }
	if params.name == 'ECDSA' {
		if alg := jwk.alg {
			if alg != (match curve {
				'P-256' { 'ES256' }
				'P-384' { 'ES384' }
				else { 'ES512' }
			}) {
				return error('DataError: Invalid algorithm')
			}
		}
	}
	x := jwk.x or { return error('DataError: Invalid key') }
	y := jwk.y or { return error('DataError: Invalid key') }
	point := EcPublicKeyHandle{ x: decode_ec_jwk_scalar(x, size)!, y: decode_ec_jwk_scalar(y, size)! }
	if d := jwk.d {
		return EcPrivateKeyHandle{ d: decode_ec_jwk_scalar(d, size)!, public_key: point }
	}
	return point
}

fn import_ec_key(params EcKeyImportParams, format KeyFormat, material []u8, extractable bool, usages []KeyUsage) !&CryptoKey {
	// Invalid named curves are a NotSupportedError regardless of key format,
	// usages, or whether the supplied key data is well-formed.
	if ec_scalar_size(params.named_curve) == 0 {
		return error("NotSupportedError: Unsupported named curve '${params.named_curve}'")
	}
	mut private_key := format == .pkcs8
	mut handle := CryptoKeyInternalHandle(ByteBufferKeyHandle{})
	if format == .jwk {
		jwk := decode_json_web_key_dictionary(material)!
		private_key = jwk.d != none
		handle = parse_ec_jwk(params, jwk, extractable, usages)!
		validate_ec_handle(params.named_curve, handle)!
	} else if format in [.spki, .pkcs8] {
		validate_ec_usages(params.name, private_key, usages)!
		info := parse_ec_key_info(material, private_key)!
		if info.curve != params.named_curve { return error('DataError: Invalid algorithm') }
		handle = info.handle
		validate_ec_handle(info.curve, handle)!
	} else if format in [.raw, .raw_public] {
		if ec_scalar_size(params.named_curve) == 0 { return error('DataError: Invalid algorithm') }
		validate_ec_usages(params.name, false, usages)!
		handle = parse_ec_public(material) or { return error('DataError: Failed to parse key') }
		validate_ec_handle(params.named_curve, handle)!
	} else {
		return error('NotSupportedError: Invalid key format')
	}
	return CryptoKey.create_with_internal_handle(if private_key {
		KeyType.private_key
	} else {
		KeyType.public_key
	}, false, EcKeyAlgorithm{ name: params.name, named_curve: params.named_curve }, [], handle)
}

fn export_ec_private(handle EcPrivateKeyHandle) ![]u8 {
	mut body := rsa_der_integer([u8(1)])
	body << okp_der_value(0x04, handle.d)
	if parameters := handle.parameters { body << okp_der_value(0xa0, ec_encode_oid(parameters)!) }
	if point := handle.public_key {
		mut bitstring := [u8(0)]
		bitstring << ec_point_to_uncompressed(point)
		body << okp_der_value(0xa1, okp_der_value(0x03, bitstring))
	}
	return okp_der_value(0x30, body)
}

fn export_ec_jwk(key &CryptoKey) !JsonWebKey {
	curve := (key.algorithm as EcKeyAlgorithm).named_curve
	if ec_scalar_size(curve) == 0 { return error('DataError: Invalid algorithm') }
	mut jwk := JsonWebKey{ kty: 'EC', crv: curve, key_ops: key.usages.map(key_usage_string(it)), ext: key.extractable }
	point := match key.internal_handle_ {
		EcPublicKeyHandle { key.internal_handle_ }
		EcPrivateKeyHandle {
			jwk.d = base64_url_bytes_encode(key.internal_handle_.d)
			native_ec_public(curve, key.internal_handle_.d) or { return error('DataError: Failed to encode public key') }
		}
		else { panic('Invalid EC handle') }
	}
	jwk.x = base64_url_bytes_encode(point.x)
	jwk.y = base64_url_bytes_encode(point.y)
	return jwk
}

fn export_ec_key(format KeyFormat, key &CryptoKey) ![]u8 {
	if format == .jwk { return export_ec_jwk(key)!.to_json().bytes() }
	if format !in [.spki, .pkcs8, .raw, .raw_public] {
		return error('NotSupportedError: Invalid key format')
	}
	if format == .pkcs8 {
		if key.type_ != .private_key {
			return error('InvalidAccessError: Key is not a private key')
		}
	} else if key.type_ != .public_key {
		return error('InvalidAccessError: Key is not a public key')
	}
	curve := (key.algorithm as EcKeyAlgorithm).named_curve
	if ec_scalar_size(curve) == 0 { return error('DataError: Invalid algorithm') }
	if format in [.raw, .raw_public] {
		return ec_point_to_uncompressed(key.internal_handle_ as EcPublicKeyHandle)
	}
	mut identifier := ec_encode_oid(ec_public_key_oid.map(int(it)))!
	identifier << ec_encode_oid(ec_curve_oid(curve))!
	mut body := []u8{}
	if format == .pkcs8 { body << rsa_der_integer([u8(0)]) }
	body << okp_der_value(0x30, identifier)
	if format == .pkcs8 {
		body << okp_der_value(0x04, export_ec_private(key.internal_handle_ as EcPrivateKeyHandle)!)
	} else {
		mut bitstring := [u8(0)]
		bitstring << ec_point_to_uncompressed(key.internal_handle_ as EcPublicKeyHandle)
		body << okp_der_value(0x03, bitstring)
	}
	return okp_der_value(0x30, body)
}
