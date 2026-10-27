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
// Source encoding_rs Utf8Decoder and decoder_functions! control expansion.
module encoding

// utf_8.rs::Utf8Decoder owns these actual five slots across raw calls.
struct SourceUtf8Decoder {
mut:
	code_point     u32
	bytes_seen     int
	bytes_needed   int
	lower_boundary u8 = 0x80
	upper_boundary u8 = 0xbf
}

fn SourceUtf8Decoder.new_inner() SourceUtf8Decoder {
	return SourceUtf8Decoder{}
}

fn (decoder &SourceUtf8Decoder) in_neutral_state() bool {
	return decoder.bytes_needed == 0
}

fn (decoder &SourceUtf8Decoder) extra_from_state() u64 {
	return if decoder.bytes_needed == 0 { u64(0) } else { u64(decoder.bytes_seen + 1) }
}

// Source checked uint capacities on the pinned 64-bit native ABI. Allocating
// these capacities into narrower V arrays remains a separate owner boundary.
fn (decoder &SourceUtf8Decoder) max_utf16_buffer_length(byte_length u64) ?u64 {
	extra := u64(1) + decoder.extra_from_state()
	if byte_length > u64(0xffffffffffffffff) - extra {
		return none
	}
	return byte_length + extra
}

fn (decoder &SourceUtf8Decoder) max_utf8_buffer_length_without_replacement(byte_length u64) ?u64 {
	extra := u64(3) + decoder.extra_from_state()
	if byte_length > u64(0xffffffffffffffff) - extra {
		return none
	}
	return byte_length + extra
}

fn (decoder &SourceUtf8Decoder) max_utf8_buffer_length(byte_length u64) ?u64 {
	extra := decoder.extra_from_state()
	if byte_length > u64(0xffffffffffffffff) - extra {
		return none
	}
	sum := byte_length + extra
	if sum > u64(0xffffffffffffffff) / 3 {
		return none
	}
	product := sum * 3
	if product > u64(0xffffffffffffffff) - 3 {
		return none
	}
	return product + 3
}

fn (mut decoder SourceUtf8Decoder) decode_to_utf8_raw(input []u8, mut output []u8, last bool) (SingleByteDecoderResult, int, int) {
	return decoder.decode_to_utf8_raw_at(input, 0, mut output, 0, last)
}

// Base offsets lower Source slices into their original actual array owners.
fn (mut decoder SourceUtf8Decoder) decode_to_utf8_raw_at(input []u8, input_start int, mut output []u8, output_start int, last bool) (SingleByteDecoderResult, int, int) {
	mut read := input_start
	mut written := output_start
	for {
		// decoder_functions! loop_preamble and Utf8Destination's actual
		// copy_utf8_up_to_invalid_from validate then copy the minimum span.
		if decoder.bytes_needed == 0 {
			remaining_input := input.len - read
			remaining_output := output.len - written
			length := if remaining_input < remaining_output {
				remaining_input
			} else {
				remaining_output
			}
			valid := source_utf8_valid_up_to(input[read..read + length])
			for index in 0 .. valid {
				output[written + index] = input[read + index]
			}
			read += valid
			written += valid
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
		if u64(written) + 3 >= u64(output.len) {
			return SingleByteDecoderResult{ status: .output_full }, read - input_start, written - output_start
		}
		byte := input[read]
		read++
		if decoder.bytes_needed == 0 {
			if byte < 0x80 {
				output[written] = byte
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
			output[written] = u8((point >> 18) | 0xf0)
			output[written + 1] = u8(((point & 0x3f000) >> 12) | 0x80)
			output[written + 2] = u8(((point & 0xfc0) >> 6) | 0x80)
			output[written + 3] = u8((point & 0x3f) | 0x80)
			written += 4
		} else {
			point := u16(decoder.code_point)
			if point < 0x800 {
				output[written] = u8((point >> 6) | 0xc0)
				output[written + 1] = u8((point & 0x3f) | 0x80)
				written += 2
			} else {
				output[written] = u8((point >> 12) | 0xe0)
				output[written + 1] = u8(((point & 0xfc0) >> 6) | 0x80)
				output[written + 2] = u8((point & 0x3f) | 0x80)
				written += 3
			}
		}
		decoder.code_point = 0
		decoder.bytes_needed = 0
		decoder.bytes_seen = 0
	}
	return SingleByteDecoderResult{ status: .input_empty }, read - input_start, written - output_start
}

// Source Decoder::decode_to_utf8 replacement loop over the actual UTF8 variant.
fn (mut decoder SourceUtf8Decoder) decode_to_utf8(input []u8, mut output []u8, last bool) (SingleByteDecoderResult, int, int, bool) {
	return decoder.decode_to_utf8_at(input, 0, mut output, 0, last)
}

fn (mut decoder SourceUtf8Decoder) decode_to_utf8_at(input []u8, input_start int, mut output []u8, output_start int, last bool) (SingleByteDecoderResult, int, int, bool) {
	mut had_errors := false
	mut total_read := input_start
	mut total_written := output_start
	for {
		result, read, written := decoder.decode_to_utf8_raw_at(input, total_read, mut output, total_written, last)
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
				output[total_written] = 0xef
				total_written++
				output[total_written] = 0xbf
				total_written++
				output[total_written] = 0xbd
				total_written++
			}
		}
	}
	return SingleByteDecoderResult{ status: .input_empty }, total_read - input_start, total_written - output_start, had_errors
}

// Source Encoding::decode_without_bom_handling's UTF8 potentially-borrowable
// branch owns the genuine Off Decoder and its existing raw UTF8 variant.
// The compatibility string owns copied bytes; logical spare capacity
// and reserve requests retain Source's actual control path.
fn decode_source_utf8_without_bom_handling(input []u8) (string, bool) {
	valid_up_to := source_utf8_valid_up_to(input)
	if valid_up_to == input.len {
		return input.bytestr(), false
	}
	mut decoder := SourceUtf8StreamingDecoder.create(false)
	remaining := u64(input.len - valid_up_to)
	without_replacement := u64(valid_up_to) + decoder.max_utf8_buffer_length_without_replacement(remaining) or {
		panic('Source UTF8 maximum capacity overflow')
	}
	mut rounded_without_replacement := u64(1)
	for rounded_without_replacement < without_replacement {
		rounded_without_replacement *= 2
	}
	with_replacement := u64(valid_up_to) + decoder.max_utf8_buffer_length(remaining) or {
		panic('Source UTF8 maximum capacity overflow')
	}
	capacity := if rounded_without_replacement < with_replacement {
		rounded_without_replacement
	} else {
		with_replacement
	}
	if capacity > u64(0x7fffffff) {
		panic('UTF8 output exceeds flattened V int array capacity')
	}
	mut output := []u8{len: int(capacity)}
	for index in 0 .. valid_up_to {
		output[index] = input[index]
	}
	mut total_read := valid_up_to
	mut total_written := valid_up_to
	mut total_had_errors := false
	for {
		result, read, written, had_errors := decoder.decode_to_utf8_at(input, total_read, mut output, total_written, true)
		total_read += read
		total_written += written
		total_had_errors = total_had_errors || had_errors
		match result.status {
			.input_empty {
				return output[..total_written].bytestr(), total_had_errors
			}
			.output_full {
				// String::reserve requests this many additional bytes from
				// its current produced length, including pending decoder state.
				needed := decoder.max_utf8_buffer_length(u64(input.len - total_read)) or {
					panic('Source UTF8 maximum capacity overflow')
				}
				new_capacity := u64(total_written) + needed
				if new_capacity > u64(0x7fffffff) {
					panic('UTF8 output exceeds flattened V int array capacity')
				}
				if new_capacity > u64(output.len) {
					output << []u8{len: int(new_capacity) - output.len}
				}
			}
			.malformed {
				panic('Source UTF8 replacement wrapper returned raw malformed status')
			}
		}
	}
	return '', false
}

// Source's original whole Rust bridge selects matching-BOM removal before
// constructing the actual Off owner, then withholds the complete fatal output.
fn decode_source_utf8_whole_to_utf8(input []u8, remove_bom bool, fatal bool) !string {
	span := if remove_bom && input.len >= 3 && input[..3] == [u8(0xef), 0xbb, 0xbf] {
		input[3..]
	} else {
		input
	}
	return decode_utf8(span, fatal)
}
