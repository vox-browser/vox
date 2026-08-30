// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Encoding/TextDecoder.cpp and TextDecoder.idl.
module encoding

import encoding.iconv as viconv

pub struct TextDecoderOptions {
pub:
	fatal      bool
	ignore_bom bool
}

pub struct TextDecodeOptions {
pub:
	stream bool
}

pub struct TextDecoder {
pub:
	encoding_   string
	fatal_      bool
	ignore_bom_ bool
}

pub fn TextDecoder.construct(label string, options TextDecoderOptions) !&TextDecoder {
	return TextDecoder.construct_impl(label, options)
}

pub fn TextDecoder.construct_impl(label string, options TextDecoderOptions) !&TextDecoder {
	canonical := get_an_encoding(label) or { return error('RangeError: Invalid encoding ${label}') }
	if encoding_ascii_lowercase(canonical) == 'replacement' {
		return error('RangeError: Invalid encoding ${label}')
	}
	return &TextDecoder{
		encoding_:   encoding_ascii_lowercase(canonical)
		fatal_:      options.fatal
		ignore_bom_: options.ignore_bom
	}
}

pub fn TextDecoder.create() &TextDecoder {
	return TextDecoder.construct('utf-8', TextDecoderOptions{}) or { panic(err) }
}

pub fn (decoder &TextDecoder) encoding() string {
	return decoder.encoding_
}

pub fn (decoder &TextDecoder) fatal() bool {
	return decoder.fatal_
}

pub fn (decoder &TextDecoder) ignore_bom() bool {
	return decoder.ignore_bom_
}

pub fn (decoder &TextDecoder) decode(input ?[]u8, options TextDecodeOptions) !string {
	// Current LibWeb keeps a shared codec and leaves streaming as a FIXME.
	_ = options
	bytes := input or { []u8{} }
	mut result := match decoder.encoding_ {
		'utf-8' {
			decode_utf8(bytes, decoder.fatal_)!
		}
		'utf-16le' {
			decode_utf16(bytes, false, decoder.fatal_)!
		}
		'utf-16be' {
			decode_utf16(bytes, true, decoder.fatal_)!
		}
		'x-user-defined' {
			decode_x_user_defined(bytes)
		}
		else {
			viconv.encoding_to_vstring(bytes, decoder.encoding_) or {
				if decoder.fatal_ {
					return error('TypeError: Decoding failed')
				}
				return decode_single_byte_replacing(bytes)
			}
		}
	}
	// TextDecoder's BOM processing. ignoreBOM=true exposes the initial BOM.
	if !decoder.ignore_bom_ && result.starts_with('\ufeff') {
		result = result['\ufeff'.len..]
	}
	// Preserve the current upstream fatal check, which rejects any replacement
	// character in the decoded output, including one encoded in the input.
	if decoder.fatal_ && result.contains('\ufffd') {
		return error('TypeError: Decoding failed')
	}
	return result
}

fn append_utf8_code_point(mut output []u8, code_point u32) {
	if code_point <= 0x7f {
		output << u8(code_point)
	} else if code_point <= 0x7ff {
		output << u8(0xc0 | (code_point >> 6))
		output << u8(0x80 | (code_point & 0x3f))
	} else if code_point <= 0xffff {
		output << u8(0xe0 | (code_point >> 12))
		output << u8(0x80 | ((code_point >> 6) & 0x3f))
		output << u8(0x80 | (code_point & 0x3f))
	} else {
		output << u8(0xf0 | (code_point >> 18))
		output << u8(0x80 | ((code_point >> 12) & 0x3f))
		output << u8(0x80 | ((code_point >> 6) & 0x3f))
		output << u8(0x80 | (code_point & 0x3f))
	}
}

fn append_replacement(mut output []u8) {
	output << [u8(0xef), 0xbf, 0xbd]
}

fn decode_utf8(input []u8, fatal bool) !string {
	mut output := []u8{}
	mut i := 0
	for i < input.len {
		first := input[i]
		if first <= 0x7f {
			output << first
			i++
			continue
		}
		mut needed := 0
		mut code_point := u32(0)
		mut minimum := u32(0)
		if first >= 0xc2 && first <= 0xdf {
			needed = 1
			code_point = u32(first & 0x1f)
			minimum = 0x80
		} else if first >= 0xe0 && first <= 0xef {
			needed = 2
			code_point = u32(first & 0x0f)
			minimum = 0x800
		} else if first >= 0xf0 && first <= 0xf4 {
			needed = 3
			code_point = u32(first & 0x07)
			minimum = 0x10000
		} else {
			if fatal { return error('TypeError: Decoding failed') }
			append_replacement(mut output)
			i++
			continue
		}
		if i + needed >= input.len {
			if fatal { return error('TypeError: Decoding failed') }
			append_replacement(mut output)
			break
		}
		mut valid := true
		for offset in 1 .. needed + 1 {
			continuation := input[i + offset]
			if continuation & 0xc0 != 0x80 {
				valid = false
				break
			}
			code_point = (code_point << 6) | u32(continuation & 0x3f)
		}
		if !valid || code_point < minimum || code_point > 0x10ffff
			|| (code_point >= 0xd800 && code_point <= 0xdfff) {
			if fatal { return error('TypeError: Decoding failed') }
			append_replacement(mut output)
			i++
			continue
		}
		append_utf8_code_point(mut output, code_point)
		i += needed + 1
	}
	return output.bytestr()
}

fn decode_utf16(input []u8, big_endian bool, fatal bool) !string {
	mut output := []u8{}
	mut i := 0
	for i + 1 < input.len {
		unit := if big_endian {
			(u16(input[i]) << 8) | input[i + 1]
		} else {
			u16(input[i]) | (u16(input[i + 1]) << 8)
		}
		i += 2
		if unit >= 0xd800 && unit <= 0xdbff {
			if i + 1 < input.len {
				trailing := if big_endian {
					(u16(input[i]) << 8) | input[i + 1]
				} else {
					u16(input[i]) | (u16(input[i + 1]) << 8)
				}
				if trailing >= 0xdc00 && trailing <= 0xdfff {
					i += 2
					append_utf8_code_point(mut output, 0x10000 + ((u32(unit) - 0xd800) << 10) +
						(u32(trailing) - 0xdc00))
					continue
				}
			}
			if fatal { return error('TypeError: Decoding failed') }
			append_replacement(mut output)
		} else if unit >= 0xdc00 && unit <= 0xdfff {
			if fatal { return error('TypeError: Decoding failed') }
			append_replacement(mut output)
		} else {
			append_utf8_code_point(mut output, unit)
		}
	}
	if i < input.len {
		if fatal { return error('TypeError: Decoding failed') }
		append_replacement(mut output)
	}
	return output.bytestr()
}

fn decode_x_user_defined(input []u8) string {
	mut output := []u8{}
	for byte in input {
		if byte <= 0x7f {
			output << byte
		} else {
			append_utf8_code_point(mut output, 0xf780 + u32(byte - 0x80))
		}
	}
	return output.bytestr()
}

fn decode_single_byte_replacing(input []u8) string {
	mut output := []u8{}
	for byte in input {
		append_utf8_code_point(mut output, byte)
	}
	return output.bytestr()
}
