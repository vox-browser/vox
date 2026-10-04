// Copyright Mozilla Foundation
//
// Permission is hereby granted, free of charge, to any
// person obtaining a copy of this software and associated
// documentation files (the "Software"), to deal in the
// Software without restriction, including without
// limitation the rights to use, copy, modify, merge,
// publish, distribute, sublicense, and/or sell copies of
// the Software, and to permit persons to whom the Software
// is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice
// shall be included in all copies or substantial portions
// of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
// ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
// TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
// PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT
// SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
// CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
// IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.
// Source UTF8 variant decoder_functions! UTF16 destination expansion.
module encoding

fn (mut decoder SourceUtf8Decoder) decode_to_utf16_raw(input []u8, mut output []u16, last bool) (SingleByteDecoderResult, int, int) {
	return decoder.decode_to_utf16_raw_at(input, 0, mut output, 0, last)
}

// Base offsets lower Source slices into their original actual array owners.
fn (mut decoder SourceUtf8Decoder) decode_to_utf16_raw_at(input []u8, input_start int, mut output []u16, output_start int, last bool) (SingleByteDecoderResult, int, int) {
	mut read := input_start
	mut written := output_start
	for {
		// Utf16Destination::copy_utf8_up_to_invalid_from keeps the
		// original input and output owners with their current positions.
		if decoder.bytes_needed == 0 {
			fast_read, fast_written := source_convert_utf8_to_utf16_up_to_invalid_at(input, read, mut output, written)
			read += fast_read
			written += fast_written
		}
		if read == input.len {
			if last && decoder.bytes_needed != 0 {
				bad_bytes := decoder.bytes_seen + 1
				decoder.code_point = 0
				decoder.bytes_needed = 0
				decoder.bytes_seen = 0
				// Source EOF intentionally does not reset either boundary.
				return SingleByteDecoderResult{ status: .malformed, malformed_length: bad_bytes }, read - input_start, written - output_start
			}
			return SingleByteDecoderResult{ status: .input_empty }, read - input_start, written - output_start
		}
		if u64(written) + 1 >= u64(output.len) {
			return SingleByteDecoderResult{ status: .output_full }, read - input_start, written - output_start
		}
		byte := input[read]
		read++
		if decoder.bytes_needed == 0 {
			if byte < 0x80 {
				output[written] = u16(byte)
				written++
				continue
			}
			if byte < 0xc2 {
				return SingleByteDecoderResult{ status: .malformed, malformed_length: 1 }, read - input_start, written - output_start
			}
			if byte < 0xe0 {
				decoder.bytes_needed = 1
				decoder.code_point = u32(byte) & 0x1f
				continue
			}
			if byte < 0xf0 {
				if byte == 0xe0 {
					decoder.lower_boundary = 0xa0
				} else if byte == 0xed {
					decoder.upper_boundary = 0x9f
				}
				decoder.bytes_needed = 2
				decoder.code_point = u32(byte) & 0xf
				continue
			}
			if byte < 0xf5 {
				if byte == 0xf0 {
					decoder.lower_boundary = 0x90
				} else if byte == 0xf4 {
					decoder.upper_boundary = 0x8f
				}
				decoder.bytes_needed = 3
				decoder.code_point = u32(byte) & 0x7
				continue
			}
			return SingleByteDecoderResult{ status: .malformed, malformed_length: 1 }, read - input_start, written - output_start
		}
		if !(byte >= decoder.lower_boundary && byte <= decoder.upper_boundary) {
			bad_bytes := decoder.bytes_seen + 1
			decoder.code_point = 0
			decoder.bytes_needed = 0
			decoder.bytes_seen = 0
			decoder.lower_boundary = 0x80
			decoder.upper_boundary = 0xbf
			read-- // ByteUnreadHandle::unread retains the offending byte.
			return SingleByteDecoderResult{ status: .malformed, malformed_length: bad_bytes }, read - input_start, written - output_start
		}
		decoder.lower_boundary = 0x80
		decoder.upper_boundary = 0xbf
		decoder.code_point = (decoder.code_point << 6) | (u32(byte) & 0x3f)
		decoder.bytes_seen++
		if decoder.bytes_seen != decoder.bytes_needed {
			continue
		}
		if decoder.bytes_needed == 3 {
			point := decoder.code_point
			output[written] = u16(0xd7c0 + (point >> 10))
			output[written + 1] = u16(0xdc00 + (point & 0x3ff))
			written += 2
		} else {
			output[written] = u16(decoder.code_point)
			written++
		}
		decoder.code_point = 0
		decoder.bytes_needed = 0
		decoder.bytes_seen = 0
	}
	return SingleByteDecoderResult{ status: .input_empty }, read - input_start, written - output_start
}

// Source Decoder::decode_to_utf16 replacement loop over the actual UTF8 variant.
fn (mut decoder SourceUtf8Decoder) decode_to_utf16(input []u8, mut output []u16, last bool) (SingleByteDecoderResult, int, int, bool) {
	return decoder.decode_to_utf16_at(input, 0, mut output, 0, last)
}

fn (mut decoder SourceUtf8Decoder) decode_to_utf16_at(input []u8, input_start int, mut output []u16, output_start int, last bool) (SingleByteDecoderResult, int, int, bool) {
	mut had_errors := false
	mut total_read := input_start
	mut total_written := output_start
	for {
		result, read, written := decoder.decode_to_utf16_raw_at(input, total_read, mut output, total_written, last)
		total_read += read
		total_written += written
		match result.status {
			.input_empty, .output_full {
				return result, total_read - input_start, total_written - output_start, had_errors
			}
			.malformed {
				had_errors = true
				// Preserve Source's actual indexed writes, including its
				// fatal short-destination EOF boundary after pending input.
				output[total_written] = 0xfffd
				total_written++
			}
		}
	}
	return SingleByteDecoderResult{ status: .input_empty }, total_read - input_start, total_written - output_start, had_errors
}
