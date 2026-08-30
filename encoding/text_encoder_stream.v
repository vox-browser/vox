// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Encoding/TextEncoderStream.cpp. The JS-to-DOMString and
// TransformStream callback plumbing is exposed as typed write/flush methods.
module encoding

pub struct TextEncoderStream {
mut:
	leading_surrogate ?u16
	chunks_           [][]u8
}

pub struct ScalarValueConversion {
pub:
	value          ?u32
	reprocess_item bool
}

pub fn TextEncoderStream.create() &TextEncoderStream {
	return TextEncoderStream.construct_impl()
}

pub fn TextEncoderStream.construct_impl() &TextEncoderStream {
	return &TextEncoderStream{}
}

pub fn (stream &TextEncoderStream) encoding() string {
	return (&TextEncoderCommonMixin{}).encoding()
}

pub fn (stream &TextEncoderStream) chunks() [][]u8 {
	mut result := [][]u8{cap: stream.chunks_.len}
	for chunk in stream.chunks_ {
		result << chunk.clone()
	}
	return result
}

pub fn (mut stream TextEncoderStream) encode_and_enqueue_chunk(input []u16) []u8 {
	mut output := []u8{}
	mut i := 0
	for i < input.len {
		item := input[i]
		conversion := stream.convert_code_unit_to_scalar_value(item)
		if scalar := conversion.value {
			append_utf8_code_point(mut output, scalar)
		}
		if conversion.reprocess_item {
			continue
		}
		i++
	}
	if output.len > 0 {
		stream.chunks_ << output.clone()
	}
	return output
}

// https://encoding.spec.whatwg.org/#convert-code-unit-to-scalar-value
pub fn (mut stream TextEncoderStream) convert_code_unit_to_scalar_value(item u16) ScalarValueConversion {
	if leading := stream.leading_surrogate {
		stream.leading_surrogate = none
		if item >= 0xdc00 && item <= 0xdfff {
			return ScalarValueConversion{
				value: 0x10000 + ((u32(leading) - 0xd800) << 10) + (u32(item) - 0xdc00)
			}
		}
		return ScalarValueConversion{
			value:          u32(0xfffd)
			reprocess_item: true
		}
	}
	if item >= 0xd800 && item <= 0xdbff {
		stream.leading_surrogate = item
		return ScalarValueConversion{}
	}
	if item >= 0xdc00 && item <= 0xdfff {
		return ScalarValueConversion{ value: u32(0xfffd) }
	}
	return ScalarValueConversion{ value: u32(item) }
}

pub fn (mut stream TextEncoderStream) encode_string_and_enqueue_chunk(input string) []u8 {
	mut units := []u16{}
	for rune_ in input.runes() {
		code_point := u32(rune_)
		if code_point > 0xffff {
			value := code_point - 0x10000
			units << u16(0xd800 + (value >> 10))
			units << u16(0xdc00 + (value & 0x3ff))
		} else {
			units << u16(code_point)
		}
	}
	return stream.encode_and_enqueue_chunk(units)
}

pub fn (mut stream TextEncoderStream) encode_and_flush() []u8 {
	if stream.leading_surrogate == none {
		return []u8{}
	}
	stream.leading_surrogate = none
	chunk := [u8(0xef), 0xbf, 0xbd]
	stream.chunks_ << chunk.clone()
	return chunk
}
