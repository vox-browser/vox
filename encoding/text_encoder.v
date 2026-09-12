// Copyright (c) 2021-2024, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/Encoding/TextEncoder.cpp and the TextEncoderCommon mixin. V
// strings are always UTF-8 (like AK::String), so encode() is just the string's bytes, and
// encode_into() walks the source's code points, writing each one's UTF-8 bytes into a caller-provided
// destination buffer only when the whole code point fits, reporting how much was read (in UTF-16 code
// units) and written (in bytes). The Uint8Array/ArrayBuffer wrapping is binding-layer (the JS runtime);
// here encode() returns the raw byte sequence and encode_into() fills a []u8 window directly.
// https://encoding.spec.whatwg.org/#textencoder
module encoding

// https://encoding.spec.whatwg.org/#dictdef-textencoderencodeintoresult
pub struct TextEncoderEncodeIntoResult {
pub:
	read    u64
	written u64
}

pub struct TextEncoderCommonMixin {}

pub fn (_ &TextEncoderCommonMixin) encoding() string {
	return 'utf-8'
}

// https://encoding.spec.whatwg.org/#textencoder
pub struct TextEncoder {}

pub fn TextEncoder.create() &TextEncoder {
	return TextEncoder.construct_impl()
}

pub fn TextEncoder.construct_impl() &TextEncoder {
	return &TextEncoder{}
}

// https://encoding.spec.whatwg.org/#dom-textencoder-encoding — the encoding getter returns "utf-8".
pub fn (encoder &TextEncoder) encoding() string {
	return (&TextEncoderCommonMixin{}).encoding()
}

pub fn (_ &TextEncoder) encode_to_byte_buffer(input string) []u8 {
	return input.bytes()
}

// https://encoding.spec.whatwg.org/#dom-textencoder-encode — the UTF-8 bytes of input. The V string
// (like AK::String) is always UTF-8, so this is a copy of its bytes.
pub fn (encoder &TextEncoder) encode(input string) []u8 {
	return encoder.encode_to_byte_buffer(input)
}

// https://encoding.spec.whatwg.org/#dom-textencoder-encodeinto — encode source into destination,
// returning the number of code units read and bytes written.
//
// AD-HOC (upstream): a detached destination has byte length 0, so no bytes are copied and the result
// is { 0, 0 }. Here an empty destination []u8 yields the same result without special-casing.
pub fn (encoder &TextEncoder) encode_into(source string, mut destination []u8) TextEncoderEncodeIntoResult {
	return encoder.encode_into_result(source, mut destination)
}

pub fn (_ &TextEncoder) encode_into_result(source string, mut destination []u8) TextEncoderEncodeIntoResult {
	// 1-2. Let read and written be 0. (Named with `_count` suffixes to avoid shadowing V's builtins.)
	mut read_count := u64(0)
	mut written_count := u64(0)
	// 3-5. The UTF-8 encoder and I/O queues collapse to walking source's code points (V strings are UTF-8).
	// 6. While true:
	for code_point in source.runes() {
		// 6.1-6.3. result is this code point's UTF-8 bytes; running out of code points finishes the loop.
		result := code_point.bytes()
		// 6.4.1. If destination's byte length − written is >= the number of bytes in result:
		if u64(destination.len) - written_count >= u64(result.len) {
			// 6.4.1.1/6.4.1.2. An astral code point reads as 2 UTF-16 code units, otherwise 1.
			if u32(code_point) > 0xFFFF {
				read_count += 2
			} else {
				read_count += 1
			}
			// 6.4.1.3/6.4.1.4. Write result into destination at startingOffset written; advance written.
			for byte in result {
				destination[written_count] = byte
				written_count++
			}
		} else {
			// 6.4.2. Otherwise, break.
			break
		}
	}
	// 7. Return «[ "read" → read, "written" → written ]».
	return TextEncoderEncodeIntoResult{
		read:    read_count
		written: written_count
	}
}
