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
// Selected Source Shift_JIS ASCII-borrow/Off whole-input owner and UTF8 FFI.
module encoding

// Source ascii.rs scalar fallback (STRIDE=16), then ascii_valid_up_to.
// Preserve is_ascii/validate_ascii_stride_tail and final tail order.
fn source_shift_jis_ascii_valid_up_to(input []u8) int {
	mut consumed := 0
	full_strides := input.len - input.len % 16
	for consumed < full_strides {
		mut all_ascii := true
		for index in consumed .. consumed + 16 {
			if input[index] >= 0x80 {
				all_ascii = false
				break
			}
		}
		if !all_ascii {
			for index in 0 .. 16 {
				if input[consumed + index] >= 0x80 { return consumed + index }
			}
			panic('Source ASCII scalar stride tail invariant')
		}
		consumed += 16
	}
	for consumed < input.len {
		if input[consumed] >= 0x80 { return consumed }
		consumed++
	}
	return input.len
}

fn decode_source_shift_jis_without_bom_handling(input []u8) (string, bool) {
	valid_up_to := source_shift_jis_ascii_valid_up_to(input)
	if valid_up_to == input.len {
		return input.bytestr(), false
	}
	mut decoder := SourceShiftJisStreamingDecoder.create()
	remaining := u64(input.len - valid_up_to)
	without_replacement := u64(valid_up_to) + decoder.max_utf8_buffer_length_without_replacement(remaining) or {
		panic('Source Shift JIS maximum capacity overflow')
	}
	mut rounded_without_replacement := u64(1)
	for rounded_without_replacement < without_replacement {
		rounded_without_replacement *= 2
	}
	with_replacement := u64(valid_up_to) + decoder.max_utf8_buffer_length(remaining) or {
		panic('Source Shift JIS maximum capacity overflow')
	}
	capacity := if rounded_without_replacement < with_replacement {
		rounded_without_replacement
	} else {
		with_replacement
	}
	if capacity > u64(0x7fffffff) {
		panic('Shift JIS whole-input UTF8 output exceeds flattened V int array capacity')
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
					panic('Source Shift JIS maximum capacity overflow')
				}
				new_capacity := u64(total_written) + needed
				if new_capacity > u64(0x7fffffff) {
					panic('Shift JIS whole-input UTF8 output exceeds flattened V int array capacity')
				}
				if new_capacity > u64(output.len) {
					output << []u8{len: int(new_capacity) - output.len}
				}
			}
			.malformed {
				panic('Source Shift JIS replacement wrapper returned raw malformed status')
			}
		}
	}
	return '', false
}

// Source whole Rust bridge selects the same complete byte span for Shift_JIS
// with or without matching-BOM removal, then withholds the entire fatal result.
fn decode_source_shift_jis_whole_to_utf8(input []u8, fatal bool) !string {
	decoded, had_errors := decode_source_shift_jis_without_bom_handling(input)
	if fatal && had_errors { return error('TypeError: Decoding failed') }
	return decoded
}
