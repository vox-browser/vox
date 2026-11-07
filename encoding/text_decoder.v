// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Encoding/TextDecoder.cpp and TextDecoder.idl.
module encoding

import encoding.iconv as viconv
import libjs

pub struct TextDecoderOptions {
pub:
	fatal      bool
	ignore_bom bool
}

pub struct TextDecodeOptions {
pub:
	stream bool
}

pub struct TextDecoderOutputQueue {
mut:
	single_output ?string
	builder       string
	has_builder   bool
}

pub fn (mut output TextDecoderOutputQueue) push(value string) ! {
	if value == '' {
		return
	}
	if output.has_builder {
		output.builder += value
		return
	}
	if output.single_output == none {
		output.single_output = value
		return
	}
	output.has_builder = true
	output.builder = output.single_output or { '' }
	output.single_output = none
	output.builder += value
}

pub fn (mut output TextDecoderOutputQueue) serialize() !string {
	if output.has_builder {
		return output.builder
	}
	if value := output.single_output {
		output.single_output = none
		return value
	}
	return ''
}

pub struct TextDecoderCommonMixin {
pub:
	encoding_   string
	fatal_      bool
	ignore_bom_ bool
mut:
	pending_input []u8
	bom_seen      bool
	// Flatten Source's owned UTF8-selected StreamingDecoder into this real
	// Common record; presence retains its OwnPtr null/VERIFY boundary.
	utf8_decoder_         SourceUtf8StreamingDecoder
	utf8_decoder_present_ bool
	// Source selected UTF16 variant belongs to the same Common owning record.
	utf16_decoder_         SourceUtf16StreamingDecoder
	utf16_decoder_present_ bool
	// Source selected Shift_JIS retains its genuine lead in this Common owner.
	shift_jis_decoder_         SourceShiftJisStreamingDecoder
	shift_jis_decoder_present_ bool
	// gb18030 and GBK share one decoder.
	gb18030_decoder_ Gb18030Decoder
}

fn new_text_decoder_common(encoding_name string, options TextDecoderOptions) TextDecoderCommonMixin {
	return TextDecoderCommonMixin{
		encoding_:   encoding_name
		fatal_:      options.fatal
		ignore_bom_: options.ignore_bom
	}
}

pub fn (decoder &TextDecoderCommonMixin) encoding() string {
	return decoder.encoding_
}

pub fn (decoder &TextDecoderCommonMixin) fatal() bool {
	return decoder.fatal_
}

pub fn (decoder &TextDecoderCommonMixin) ignore_bom() bool {
	return decoder.ignore_bom_
}

pub fn (mut decoder TextDecoderCommonMixin) set_decoder_to_new_instance_of_encoding_decoder() {
	decoder.pending_input.clear()
	decoder.bom_seen = false
	if decoder.encoding_ == 'utf-8' {
		decoder.utf8_decoder_ = SourceUtf8StreamingDecoder.create(!decoder.ignore_bom_)
		decoder.utf8_decoder_present_ = true
	} else if decoder.encoding_ == 'utf-16le' || decoder.encoding_ == 'utf-16be' {
		decoder.utf16_decoder_ = SourceUtf16StreamingDecoder.create(decoder.encoding_ == 'utf-16be', !decoder.ignore_bom_)
		decoder.utf16_decoder_present_ = true
	} else if decoder.encoding_ == 'shift_jis' {
		decoder.shift_jis_decoder_ = SourceShiftJisStreamingDecoder.create()
		decoder.shift_jis_decoder_present_ = true
	} else if decoder.encoding_ in ['gb18030', 'gbk'] {
		decoder.gb18030_decoder_ = Gb18030Decoder{}
	}
}

pub fn append_decoded_output(mut output TextDecoderOutputQueue, decoded string) ! {
	output.push(decoded)!
}

fn utf16_safe_decode_boundary(bytes []u8, big_endian bool) int {
	mut boundary := bytes.len - bytes.len % 2
	if boundary < 2 {
		return 0
	}
	last := if big_endian {
		(u16(bytes[boundary - 2]) << 8) | u16(bytes[boundary - 1])
	} else {
		u16(bytes[boundary - 2]) | (u16(bytes[boundary - 1]) << 8)
	}
	if last >= 0xd800 && last <= 0xdbff {
		boundary -= 2
	}
	return boundary
}

fn decode_bytes_for_encoding(bytes []u8, encoding_name string, fatal bool) !string {
	if table := source_single_byte_table(encoding_name) {
		return decode_source_single_byte_to_utf8(bytes, table, fatal)
	}
	return match encoding_name {
		'utf-8' { decode_utf8(bytes, fatal)! }
		'utf-16le' { decode_utf16(bytes, false, fatal)! }
		'utf-16be' { decode_utf16(bytes, true, fatal)! }
		'x-user-defined' { decode_x_user_defined(bytes) }
		'gb18030', 'gbk' { decode_gb18030(bytes, fatal)! }
		else {
			viconv.encoding_to_vstring(bytes, encoding_name) or {
				if fatal {
					return error('TypeError: Decoding failed')
				}
				return decode_single_byte_replacing(bytes)
			}
		}
	}
}

fn (mut decoder TextDecoderCommonMixin) decode_item(input []u8, end_of_queue bool) !string {
	if decoder.encoding_ == 'utf-8' {
		if !decoder.utf8_decoder_present_ {
			panic('Source VERIFY: TextDecoderCommon owns its StreamingDecoder')
		}
		ok, decoded := decoder.utf8_decoder_.decode_owned_utf8(input, end_of_queue, decoder.fatal_)
		if !ok {
			return error('TypeError: Decoding failed')
		}
		return decoded
	}
	if decoder.encoding_ == 'utf-16le' || decoder.encoding_ == 'utf-16be' {
		if !decoder.utf16_decoder_present_ {
			panic('Source VERIFY: TextDecoderCommon owns its StreamingDecoder')
		}
		ok, decoded := decoder.utf16_decoder_.decode_owned_utf8(input, end_of_queue, decoder.fatal_)
		if !ok { return error('TypeError: Decoding failed') }
		return decoded
	}
	if decoder.encoding_ == 'shift_jis' {
		if !decoder.shift_jis_decoder_present_ {
			panic('Source VERIFY: TextDecoderCommon owns its StreamingDecoder')
		}
		ok, decoded := decoder.shift_jis_decoder_.decode_owned_utf8(input, end_of_queue, decoder.fatal_)
		if !ok { return error('TypeError: Decoding failed') }
		return decoded
	}
	if decoder.encoding_ in ['gb18030', 'gbk'] {
		ok, decoded := decoder.gb18030_decoder_.decode_owned_utf8(input, end_of_queue, decoder.fatal_)
		if !ok { return error('TypeError: Decoding failed') }
		return decoded
	}
	mut bytes := decoder.pending_input.clone()
	bytes << input
	mut boundary := bytes.len
	if !end_of_queue {
		boundary = match decoder.encoding_ {
			'utf-8' { find_utf8_safe_decode_boundary(bytes) }
			'utf-16le' { utf16_safe_decode_boundary(bytes, false) }
			'utf-16be' { utf16_safe_decode_boundary(bytes, true) }
			else { bytes.len }
		}
	}
	decoder.pending_input = bytes[boundary..].clone()
	mut decoded := decode_bytes_for_encoding(bytes[..boundary], decoder.encoding_, decoder.fatal_)!
	if decoded != '' && !decoder.bom_seen {
		decoder.bom_seen = true
		if !decoder.ignore_bom_ && decoded.starts_with('\ufeff') {
			decoded = decoded['\ufeff'.len..]
		}
	}
	if end_of_queue {
		decoder.pending_input.clear()
	}
	return decoded
}

pub fn (mut decoder TextDecoderCommonMixin) process_an_item(input []u8, end_of_queue bool, mut output TextDecoderOutputQueue) ! {
	decoded := decoder.decode_item(input, end_of_queue)!
	append_decoded_output(mut output, decoded)!
}

pub fn (_ &TextDecoderCommonMixin) serialize_io_queue(mut output TextDecoderOutputQueue) !string {
	return output.serialize()
}

pub struct TextDecoder {
	TextDecoderCommonMixin
}

pub fn TextDecoder.construct(label string, options TextDecoderOptions) !&TextDecoder {
	return TextDecoder.construct_impl(label, options)
}

pub fn TextDecoder.construct_impl(label string, options TextDecoderOptions) !&TextDecoder {
	canonical := get_an_encoding(label) or { return error('RangeError: Invalid encoding ${label}') }
	if encoding_ascii_lowercase(canonical) == 'replacement' {
		return error('RangeError: Invalid encoding ${label}')
	}
	mut decoder := &TextDecoder{
		TextDecoderCommonMixin: new_text_decoder_common(encoding_ascii_lowercase(canonical),
			options)
	}
	decoder.set_decoder_to_new_instance_of_encoding_decoder()
	return decoder
}

pub fn TextDecoder.create() &TextDecoder {
	return TextDecoder.construct('utf-8', TextDecoderOptions{}) or { panic(err) }
}

pub fn (decoder &TextDecoder) encoding() string {
	return decoder.TextDecoderCommonMixin.encoding()
}

pub fn (decoder &TextDecoder) fatal() bool {
	return decoder.TextDecoderCommonMixin.fatal()
}

pub fn (decoder &TextDecoder) ignore_bom() bool {
	return decoder.TextDecoderCommonMixin.ignore_bom()
}

pub fn (decoder &TextDecoder) decode(input ?[]u8, options TextDecodeOptions) !string {
	bytes := input or { []u8{} }
	mut mutable_decoder := unsafe { &TextDecoder(decoder) }
	if mutable_decoder.encoding_ == 'utf-8' {
		if !mutable_decoder.utf8_decoder_present_ {
			panic('Source VERIFY: TextDecoderCommon owns its StreamingDecoder')
		}
		// TextDecoder calls its actual owner's UTF16 destination, while
		// Common/Stream call to_utf8. Preserve reset before exposing the
		// saved result; failed fatal callback units stay internal.
		ok, units := mutable_decoder.utf8_decoder_.decode_owned_utf16(bytes, !options.stream, mutable_decoder.fatal_)
		if !options.stream {
			mutable_decoder.set_decoder_to_new_instance_of_encoding_decoder()
		}
		if !ok {
			return error('TypeError: Decoding failed')
		}
		owned_result := libjs.utf16_string_from_code_units(units)
		// Retain the existing public string projection. Validated UTF8
		// decoding produces only well-formed UTF16 units here.
		return owned_result.str()
	}
	if mutable_decoder.encoding_ == 'utf-16le' || mutable_decoder.encoding_ == 'utf-16be' {
		if !mutable_decoder.utf16_decoder_present_ {
			panic('Source VERIFY: TextDecoderCommon owns its StreamingDecoder')
		}
		ok, units := mutable_decoder.utf16_decoder_.decode_owned_utf16(bytes, !options.stream, mutable_decoder.fatal_)
		// Source resets a flushed owner before exposing its saved success or
		// error, preserving retained variant/BOM slots only for streaming.
		if !options.stream { mutable_decoder.set_decoder_to_new_instance_of_encoding_decoder() }
		if !ok { return error('TypeError: Decoding failed') }
		owned_result := libjs.utf16_string_from_code_units(units)
		return owned_result.str()
	}
	if mutable_decoder.encoding_ == 'shift_jis' {
		if !mutable_decoder.shift_jis_decoder_present_ {
			panic('Source VERIFY: TextDecoderCommon owns its StreamingDecoder')
		}
		// Source TextDecoder consumes the actual owner's direct UTF16
		// destination; Common/Stream retain the same owner's UTF8 method.
		ok, units := mutable_decoder.shift_jis_decoder_.decode_owned_utf16(bytes, !options.stream, mutable_decoder.fatal_)
		if !options.stream { mutable_decoder.set_decoder_to_new_instance_of_encoding_decoder() }
		if !ok { return error('TypeError: Decoding failed') }
		owned_result := libjs.utf16_string_from_code_units(units)
		return owned_result.str()
	}
	if mutable_decoder.encoding_ in ['gb18030', 'gbk'] {
		ok, units := mutable_decoder.gb18030_decoder_.decode_owned_utf16(bytes, !options.stream, mutable_decoder.fatal_)
		if !options.stream { mutable_decoder.set_decoder_to_new_instance_of_encoding_decoder() }
		if !ok { return error('TypeError: Decoding failed') }
		owned_result := libjs.utf16_string_from_code_units(units)
		return owned_result.str()
	}
	mut output := TextDecoderOutputQueue{}
	mutable_decoder.process_an_item(bytes, !options.stream, mut output) or {
		// TextDecoder.cpp replaces a flushed decoder before exposing its
		// result, including a decoding error. Streaming errors retain it.
		if !options.stream {
			mutable_decoder.set_decoder_to_new_instance_of_encoding_decoder()
		}
		return err
	}
	if !options.stream {
		mutable_decoder.set_decoder_to_new_instance_of_encoding_decoder()
	}
	return mutable_decoder.serialize_io_queue(mut output)
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
	output, had_errors := decode_source_utf8_without_bom_handling(input)
	// The actual Rust bridge replaces first and withholds callback output
	// in fatal mode when the Source whole-input decoder reports errors.
	if fatal && had_errors {
		return error('TypeError: Decoding failed')
	}
	return output
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

fn decode_single_byte_replacing(input []u8) string {
	mut output := []u8{}
	for byte in input {
		append_utf8_code_point(mut output, byte)
	}
	return output.bytestr()
}
