// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Encoding/TextDecoderStream.cpp. TransformStream controller
// plumbing is represented by the observable chunks queue used by the V host.
module encoding

pub fn is_utf8_continuation_byte(byte u8) bool {
	return byte & 0xc0 == 0x80
}

pub fn is_utf8_second_byte_in_range(lead u8, byte u8) bool {
	if !is_utf8_continuation_byte(byte) {
		return false
	}
	if lead == 0xe0 {
		return byte >= 0xa0
	}
	if lead == 0xed {
		return byte <= 0x9f
	}
	if lead == 0xf0 {
		return byte >= 0x90
	}
	if lead == 0xf4 {
		return byte <= 0x8f
	}
	return true
}

pub fn find_utf8_safe_decode_boundary(bytes []u8) int {
	mut scan := 0
	for scan < bytes.len && scan < 4 {
		position := bytes.len - scan - 1
		byte := bytes[position]
		if is_utf8_continuation_byte(byte) {
			scan++
			continue
		}
		if byte & 0x80 == 0 {
			return position + 1
		}
		expected_length := if byte >= 0xc2 && byte <= 0xdf {
			2
		} else if byte >= 0xe0 && byte <= 0xef {
			3
		} else if byte >= 0xf0 && byte <= 0xf4 {
			4
		} else {
			return bytes.len
		}
		if bytes.len - position >= 2
			&& !is_utf8_second_byte_in_range(byte, bytes[position + 1]) {
			return bytes.len
		}
		if bytes.len - position >= expected_length {
			return bytes.len
		}
		return position
	}
	return bytes.len
}

pub struct TextDecoderStream {
	TextDecoderCommonMixin
mut:
	chunks_ []string
}

pub fn TextDecoderStream.create_for_constructor(label string, options TextDecoderOptions) !&TextDecoderStream {
	canonical := get_an_encoding(label) or { return error('RangeError: Invalid encoding ${label}') }
	if encoding_ascii_lowercase(canonical) == 'replacement' {
		return error('RangeError: Invalid encoding ${label}')
	}
	mut stream := &TextDecoderStream{
		TextDecoderCommonMixin: new_text_decoder_common(encoding_ascii_lowercase(canonical),
			options)
	}
	stream.set_decoder_to_new_instance_of_encoding_decoder()
	return stream
}

pub fn TextDecoderStream.create(label string, options TextDecoderOptions) !&TextDecoderStream {
	return TextDecoderStream.create_for_constructor(label, options)
}

pub fn (stream &TextDecoderStream) chunks() []string {
	return stream.chunks_.clone()
}

// A native TransformStream already owns its output queue. These methods keep
// only incremental decoder state, without retaining another copy of each
// string after the consumer has read it.
pub fn (mut stream TextDecoderStream) decode_chunk(chunk []u8) !string {
	mut output := TextDecoderOutputQueue{}
	stream.process_an_item(chunk, false, mut output)!
	return stream.serialize_io_queue(mut output)
}

pub fn (mut stream TextDecoderStream) flush() !string {
	mut output := TextDecoderOutputQueue{}
	stream.process_an_item([], true, mut output)!
	return stream.serialize_io_queue(mut output)
}

pub fn (mut stream TextDecoderStream) decode_and_enqueue_chunk(chunk []u8) !string {
	decoded := stream.decode_chunk(chunk)!
	stream.enqueue_decoded_output(decoded)
	return decoded
}

pub fn (mut stream TextDecoderStream) flush_and_enqueue() !string {
	decoded := stream.flush()!
	stream.enqueue_decoded_output(decoded)
	return decoded
}

pub fn (mut stream TextDecoderStream) enqueue_decoded_output(decoded string) {
	if decoded != '' {
		stream.chunks_ << decoded
	}
}
