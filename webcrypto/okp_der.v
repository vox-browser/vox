// SPDX-License-Identifier: BSD-2-Clause
// Narrow translation of CryptoAlgorithms.cpp parse_an_ASN1_structure,
// LibCrypto Certificate.cpp OKP branches, DER Decoder/Encoder, and PK.h wraps.
module webcrypto

struct OkpDerReader {
	bytes []u8
mut:
	position int
}

fn (mut reader OkpDerReader) byte() !u8 {
	if reader.position >= reader.bytes.len {
		return error('DataError: ASN1::Decoder: Reading byte from an empty entry')
	}
	value := reader.bytes[reader.position]
	reader.position++
	return value
}

fn (mut reader OkpDerReader) read(sequence bool) ![]u8 {
	return reader.read_contents(sequence, sequence)
}

// Container entry points validate their own tag kind before reading contents.
fn (mut reader OkpDerReader) read_contents(sequence bool, constructed_value bool) ![]u8 {
	mut tag := reader.byte()!
    constructed := tag & 0x20 != 0
	mut kind := tag & 0x1f
	if kind == 0x1f {
		kind = 0
		for tag & 0x80 != 0 {
			tag = reader.byte()!
			kind = (kind << 7) | (tag & 0x7f)
		}
	}
	if sequence && (kind != 16 || !constructed) {
		return error('DataError: ASN1::Decoder: Expected a constructed Sequence')
	}
	if !constructed_value && constructed {
		return error('DataError: ASN1::Decoder: Trying to read a constructed value as primitive')
	}
	if constructed_value && !constructed {
		return error('DataError: ASN1::Decoder: Entering a non-constructed type')
	}
	// READ_OBJECT supplies universal class/kind overrides in the source. Its
	// primitive reads decode the bytes without checking the original tag kind.
	first := reader.byte()!
	mut length := u64(first)
	if first & 0x80 != 0 {
		count := int(first & 0x7f)
		if count == 0 || count == 0x7f {
			return error('DataError: ASN1::Decoder: Length has an invalid count value')
		}
		if count > 8 {
			return error('DataError: ASN1::Decoder: Length is larger than the target type')
		}
		length = 0
		for _ in 0 .. count { length = (length << 8) | u64(reader.byte()!) }
	}
	if length > u64(reader.bytes.len - reader.position) {
		return error('DataError: ASN1::Decoder: Reading bytes from an empty entry')
	}
	end := reader.position + int(length)
	result := reader.bytes[reader.position..end].clone()
	reader.position = end
	return result
}

fn (reader &OkpDerReader) exact() ! {
	if reader.position != reader.bytes.len {
		return error('DataError: Not all bytes were consumed during the parsing phase')
	}
}

fn decode_okp_oid(bytes []u8) ![]u32 {
	if bytes.len == 0 {
		return error('DataError: ASN1::Decoder: Decoding object identifier from an empty span')
	}
	mut result := [u32(0)]
	mut value := u64(0)
	for byte in bytes {
		if value == 0 && byte == 0x80 {
			return error('DataError: ASN1::Decoder: Object identifier has a non-minimally encoded subidentifier')
		}
		value = (value << 7) | u64(byte & 0x7f)
		if value > 0x0fffffff {
			return error('DataError: ASN1::Decoder: Object identifier has an excessively large subidentifier')
		}
		if byte & 0x80 == 0 {
			result << u32(value)
			value = 0
		}
	}
	if value != 0 {
		return error('DataError: ASN1::Decoder: Object identifier ends with an unterminated subidentifier')
	}
	if result[1] >= 1600 {
		return error('DataError: ASN1::Decoder: Invalid encoding in object identifier')
	}
	result[0] = result[1] / 40
	result[1] %= 40
	return result
}

fn okp_oid_last(name string) u8 {
	return match name {
		'X25519' { 110 }
		'X448' { 111 }
		'Ed25519' { 112 }
		else { 113 }
	}
}

struct NoParameterKeyInfo {
	oid      []u32
	material []u8
}

fn parse_no_parameter_key_info(bytes []u8, private_key bool) !NoParameterKeyInfo {
	mut outer := OkpDerReader{ bytes: bytes }
	sequence := outer.read(true)!
	outer.exact()!
	mut body := OkpDerReader{ bytes: sequence }
	if private_key {
		version := body.read(false)!
		if version.len == 0 || (version.len > 1 && ((version[0] == 0xff && version[1] & 0x80 != 0) || (version[0] == 0 && version[1] & 0x80 == 0))) || version[0] & 0x80 != 0 {
			return error('DataError: Invalid version encoding')
		}
		if version.any(it != 0) { return error('DataError: Invalid version value') }
	}
	mut algorithm := OkpDerReader{ bytes: body.read(true)! }
	oid := decode_okp_oid(algorithm.read(false)!)!
	// Certificate::parse_algorithm_identifier leaves no-parameter algorithms
	// without consuming their remaining inner bytes.
	material := body.read(false)!
	if private_key { return NoParameterKeyInfo{ oid: oid, material: material } }
	if material.len == 0 || material[0] != 0 {
		return error('DataError: ASN1::BitStringView: Cannot get raw bytes with unused bits')
	}
	return NoParameterKeyInfo{ oid: oid, material: material[1..].clone() }
}

fn parse_okp_der(name string, bytes []u8, private_key bool) ![]u8 {
	info := parse_no_parameter_key_info(bytes, private_key)!
	if info.oid != [u32(1), 3, 101, u32(okp_oid_last(name))] {
		return error('DataError: Invalid algorithm')
	}
	if private_key {
		mut curve := OkpDerReader{ bytes: info.material }
		result := curve.read(false)!
		curve.exact()!
		if name == 'Ed25519' && result.len != 32 {
			return error('DataError: Invalid Ed25519 private key')
		}
		return result
	}
	return info.material.clone()
}

fn okp_der_value(tag u8, bytes []u8) []u8 {
	mut output := [tag]
	if bytes.len < 0x80 {
		output << u8(bytes.len)
	} else {
		mut count := 0
		mut length := u64(bytes.len)
		for length != 0 {
			count++
			length >>= 8
		}
		output << u8(0x80 | count)
		for index in 0 .. count { output << u8(u64(bytes.len) >> ((count - index - 1) * 8)) }
	}
	output << bytes
	return output
}

fn wrap_no_parameter_key_info(oid_bytes []u8, material []u8, private_key bool) []u8 {
	algorithm := okp_der_value(0x30, okp_der_value(0x06, oid_bytes))
	mut body := []u8{}
	if private_key { body << [u8(0x02), 0x01, 0x00] }
	body << algorithm
	if private_key {
		body << okp_der_value(0x04, material)
	} else {
		mut bit_string := [u8(0)]
		bit_string << material
		body << okp_der_value(0x03, bit_string)
	}
	return okp_der_value(0x30, body)
}

fn export_okp_der(name string, material []u8, private_key bool) []u8 {
	return wrap_no_parameter_key_info([u8(0x2b), 0x65, okp_oid_last(name)], if private_key {
		okp_der_value(0x04, material)
	} else {
		material
	}, private_key)
}
