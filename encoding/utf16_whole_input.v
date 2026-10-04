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
// Source Encoding UTF16 whole-input non-borrowable owner and Rust bridge.
module encoding

// Encoding::decode_without_bom_handling never borrows selected UTF16 input.
// Preserve its Off owner, rounded/min initial capacity and reserve loop;
// physical Rust String/Vec allocation remains a separate boundary.
fn decode_source_utf16_without_bom_handling(input []u8, big_endian bool) (string, bool) {
	mut decoder := SourceUtf16StreamingDecoder.create(big_endian, false)
	without_replacement := decoder.max_utf8_buffer_length_without_replacement(u64(input.len)) or { panic('Source UTF16 maximum capacity overflow') }
	mut rounded_without_replacement := u64(1)
	for rounded_without_replacement < without_replacement { rounded_without_replacement *= 2 }
	with_replacement := decoder.max_utf8_buffer_length(u64(input.len)) or { panic('Source UTF16 maximum capacity overflow') }
	capacity := if rounded_without_replacement < with_replacement {
		rounded_without_replacement
	} else {
		with_replacement
	}
	if capacity > u64(0x7fffffff) {
		panic('UTF16 whole-input UTF8 output exceeds flattened V int array capacity')
	}
	mut output := []u8{len: int(capacity)}
	mut total_read := 0
	mut total_written := 0
	mut total_had_errors := false
	for {
		result, read, written, had_errors := decoder.decode_to_utf8_at(input, total_read, mut output, total_written, true)
		total_read += read
		total_written += written
		total_had_errors = total_had_errors || had_errors
		match result.status {
			.input_empty { return output[..total_written].bytestr(), total_had_errors }
			.output_full {
				needed := decoder.max_utf8_buffer_length(u64(input.len - total_read)) or { panic('Source UTF16 maximum capacity overflow') }
				new_capacity := u64(total_written) + needed
				if new_capacity > u64(0x7fffffff) {
					panic('UTF16 whole-input UTF8 output exceeds flattened V int array capacity')
				}
				if new_capacity > u64(output.len) {
					output << []u8{len: int(new_capacity) - output.len}
				}
			}
			.malformed { panic('Source UTF16 replacement wrapper returned raw malformed status') }
		}
	}
	return '', false
}

// Original selected-UTF16 whole-input FFI removes one matching leading BOM,
// decodes in replacement mode, then withholds the entire fatal result.
fn decode_source_utf16_whole_to_utf8(input []u8, big_endian bool, remove_bom bool, fatal bool) !string {
	bom := if big_endian { [u8(0xfe), 0xff] } else { [u8(0xff), 0xfe] }
	bytes := if remove_bom && input.len >= 2 && input[..2] == bom { input[2..] } else { input }
	decoded, had_errors := decode_source_utf16_without_bom_handling(bytes, big_endian)
	if fatal && had_errors { return error('TypeError: Decoding failed') }
	return decoded
}
