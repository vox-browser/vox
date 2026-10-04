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
// Same selected Source Shift_JIS outer owner, direct UTF16 destination/bridge.
module encoding

fn (decoder &SourceShiftJisStreamingDecoder) max_utf16_buffer_length(byte_length u64) ?u64 {
	if decoder.life_cycle == .finished { panic('Must not use a decoder that has finished.') }
	return decoder.variant.max_utf16_buffer_length(byte_length)
}

fn (mut decoder SourceShiftJisStreamingDecoder) decode_to_utf16_without_replacement(input []u8, mut output []u16, last bool) (SingleByteDecoderResult, int, int) {
	return decoder.decode_to_utf16_without_replacement_at(input, 0, mut output, 0, last)
}

fn (mut decoder SourceShiftJisStreamingDecoder) decode_to_utf16_without_replacement_at(input []u8, input_start int, mut output []u16, output_start int, last bool) (SingleByteDecoderResult, int, int) {
	if decoder.life_cycle == .finished { panic('Must not use a decoder that has finished.') }
	result, read, written := decoder.variant.decode_to_utf16_raw_at(input, input_start, mut output, output_start, last)
	if last && result.status == .input_empty { decoder.life_cycle = .finished }
	return result, read, written
}

fn (mut decoder SourceShiftJisStreamingDecoder) decode_to_utf16(input []u8, mut output []u16, last bool) (SingleByteDecoderResult, int, int, bool) {
	return decoder.decode_to_utf16_at(input, 0, mut output, 0, last)
}

fn (mut decoder SourceShiftJisStreamingDecoder) decode_to_utf16_at(input []u8, input_start int, mut output []u16, output_start int, last bool) (SingleByteDecoderResult, int, int, bool) {
	mut total_read := input_start
	mut total_written := output_start
	mut had_errors := false
	for {
		result, read, written := decoder.decode_to_utf16_without_replacement_at(input, total_read, mut output, total_written, last)
		total_read += read
		total_written += written
		match result.status {
			.input_empty, .output_full {
				return result, total_read - input_start, total_written - output_start, had_errors
			}
			.malformed {
				had_errors = true
				// Source indexes one replacement unit after the genuine malformed
				// result. Held-lead EOF can reach it without output capacity.
				if total_written >= output.len {
					panic('Source UTF16 replacement output index out of bounds')
				}
				output[total_written] = 0xfffd
				total_written++
			}
		}
	}
	return SingleByteDecoderResult{ status: .input_empty }, total_read - input_start, total_written - output_start, had_errors
}

// Original Source Rust owning u16 Vec bridge. Retain failed partial callback
// units internally until the actual C++ caller examines the success flag.
fn (mut decoder SourceShiftJisStreamingDecoder) decode_owned_utf16(input []u8, last bool, fatal bool) (bool, []u16) {
	capacity := decoder.max_utf16_buffer_length(u64(input.len)) or { return false, []u16{} }
	if capacity > u64(0x7fffffff) {
		panic('Shift JIS streaming UTF16 output exceeds flattened V int array capacity')
	}
	mut output := []u16{len: int(capacity)}
	if fatal {
		result, _, written := decoder.decode_to_utf16_without_replacement(input, mut output, last)
		return result.status == .input_empty, output[..written].clone()
	}
	result, _, written, _ := decoder.decode_to_utf16(input, mut output, last)
	return result.status == .input_empty, output[..written].clone()
}
