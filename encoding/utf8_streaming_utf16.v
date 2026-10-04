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
// Source UTF8-selected outer Decoder and actual UTF16 bridge owner.
module encoding

fn (decoder &SourceUtf8StreamingDecoder) max_utf16_buffer_length(byte_length u64) ?u64 {
	match decoder.life_cycle {
		.converting, .at_utf8_start { return decoder.variant.max_utf16_buffer_length(byte_length) }
		.seen_utf8_first, .seen_utf8_second {
			if byte_length > u64(0xffffffffffffffff) - 2 { return none }
			sum := byte_length + 2
			if sum > u64(0xffffffffffffffff) - 1 { return none }
			return sum + 1
		}
		.finished { panic('Must not use a decoder that has finished.') }
	}
}

fn (mut decoder SourceUtf8StreamingDecoder) decode_to_utf16_without_replacement(input []u8, mut output []u16, last bool) (SingleByteDecoderResult, int, int) {
	return decoder.decode_to_utf16_without_replacement_at(input, 0, mut output, 0, last)
}

// Source public_decode_function! expanded for the UTF16 destination;
// only actual UTF8-selected Off/Remove constructors are reachable.
fn (mut decoder SourceUtf8StreamingDecoder) decode_to_utf16_without_replacement_at(input []u8, input_start int, mut output []u16, output_start int, last bool) (SingleByteDecoderResult, int, int) {
	mut offset := 0
	for {
		match decoder.life_cycle {
			.converting {
				return decoder.checking_end_utf16(input, input_start, mut output, output_start, last)
			}
			.at_utf8_start {
				if input_start == input.len {
					return SingleByteDecoderResult{ status: .input_empty }, 0, 0
				}
				if input[input_start] == 0xef {
					decoder.life_cycle = .seen_utf8_first
					offset++
					continue
				}
				decoder.life_cycle = .converting
			}
			.seen_utf8_first {
				if input_start + offset >= input.len {
					if last {
						return decoder.after_one_potential_bom_byte_utf16(input, input_start, mut output, output_start, last, offset)
					}
					return SingleByteDecoderResult{ status: .input_empty }, offset, 0
				}
				if input[input_start + offset] == 0xbb {
					decoder.life_cycle = .seen_utf8_second
					offset++
					continue
				}
				return decoder.after_one_potential_bom_byte_utf16(input, input_start, mut output, output_start, last, offset)
			}
			.seen_utf8_second {
				if input_start + offset >= input.len {
					if last {
						return decoder.after_two_potential_bom_bytes_utf16(input, input_start, mut output, output_start, last, offset)
					}
					return SingleByteDecoderResult{ status: .input_empty }, offset, 0
				}
				if input[input_start + offset] == 0xbf {
					decoder.life_cycle = .converting
					offset++
					result, read, written := decoder.checking_end_utf16(input, input_start + offset, mut output, output_start, last)
					return result, read + offset, written
				}
				return decoder.after_two_potential_bom_bytes_utf16(input, input_start, mut output, output_start, last, offset)
			}
			.finished { panic('Must not use a decoder that has finished.') }
		}
	}
	return SingleByteDecoderResult{ status: .input_empty }, 0, 0
}

fn (mut decoder SourceUtf8StreamingDecoder) after_one_potential_bom_byte_utf16(input []u8, input_start int, mut output []u16, output_start int, last bool, offset int) (SingleByteDecoderResult, int, int) {
	decoder.life_cycle = .converting
	if offset == 0 {
		first_result, _, first_written := decoder.variant.decode_to_utf16_raw_at([u8(0xef)], 0, mut output, output_start, false)
		match first_result.status {
			.input_empty {
				result, read, written := decoder.checking_end_utf16(input, input_start, mut output, output_start + first_written, last)
				return result, read, first_written + written
			}
			.malformed { return first_result, 0, first_written }
			.output_full { panic('Output buffer must have been too small.') }
		}
	}
	return decoder.checking_end_utf16(input, input_start, mut output, output_start, last)
}

fn (mut decoder SourceUtf8StreamingDecoder) after_two_potential_bom_bytes_utf16(input []u8, input_start int, mut output []u16, output_start int, last bool, offset int) (SingleByteDecoderResult, int, int) {
	decoder.life_cycle = .converting
	if offset == 0 {
		first_result, _, first_written := decoder.variant.decode_to_utf16_raw_at([
			u8(0xef),
			0xbb,
		], 0, mut output, output_start, false)
		match first_result.status {
			.input_empty {
				result, read, written := decoder.checking_end_utf16(input, input_start, mut output, output_start + first_written, last)
				return result, read, first_written + written
			}
			.malformed {
				// EF BB cannot be malformed in the actual UTF8 variant
				// with last=false; Source's pending-BB arm is foreign-only.
				return first_result, 0, first_written
			}
			.output_full { panic('Output buffer must have been too small.') }
		}
	}
	if offset == 1 {
		return decoder.after_one_potential_bom_byte_utf16(input, input_start, mut output, output_start, last, 0)
	}
	return decoder.checking_end_utf16(input, input_start, mut output, output_start, last)
}

fn (mut decoder SourceUtf8StreamingDecoder) checking_end_utf16(input []u8, input_start int, mut output []u16, output_start int, last bool) (SingleByteDecoderResult, int, int) {
	result, read, written := decoder.variant.decode_to_utf16_raw_at(input, input_start, mut output, output_start, last)
	if last && result.status == .input_empty { decoder.life_cycle = .finished }
	return result, read, written
}

fn (mut decoder SourceUtf8StreamingDecoder) decode_to_utf16(input []u8, mut output []u16, last bool) (SingleByteDecoderResult, int, int, bool) {
	mut had_errors := false
	mut total_read := 0
	mut total_written := 0
	for {
		result, read, written := decoder.decode_to_utf16_without_replacement_at(input, total_read, mut output, total_written, last)
		total_read += read
		total_written += written
		match result.status {
			.input_empty, .output_full { return result, total_read, total_written, had_errors }
			.malformed {
				had_errors = true
				output[total_written] = 0xfffd
				total_written++
			}
		}
	}
	return SingleByteDecoderResult{ status: .input_empty }, total_read, total_written, had_errors
}

// Rust streaming decode_to_utf16 owns this maximum-capacity u16 buffer.
// Return produced callback units even on fatal failure; the actual C++ caller
// withholds that failed result instead of exposing the partial buffer.
fn (mut decoder SourceUtf8StreamingDecoder) decode_owned_utf16(input []u8, last bool, fatal bool) (bool, []u16) {
	capacity := decoder.max_utf16_buffer_length(u64(input.len)) or { return false, []u16{} }
	if capacity > u64(0x7fffffff) {
		panic('UTF16 streaming output exceeds flattened V int array capacity')
	}
	mut output := []u16{len: int(capacity)}
	if fatal {
		result, _, written := decoder.decode_to_utf16_without_replacement(input, mut output, last)
		return result.status == .input_empty, output[..written].clone()
	}
	result, _, written, _ := decoder.decode_to_utf16(input, mut output, last)
	return result.status == .input_empty, output[..written].clone()
}
