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
// Source UTF16-selected outer Decoder and actual UTF16 bridge owner.
module encoding

// Source Decoder specialized to genuine UTF16 Off/Remove constructors. Other
// encoding/BOM-sniffing constructors cannot enter this retained owner.
enum Utf16DecoderLifeCycle {
	at_utf16_be_start
	at_utf16_le_start
	seen_utf16_be_first
	seen_utf16_le_first
	converting
	finished
}

struct SourceUtf16StreamingDecoder {
mut:
	variant    SourceUtf16Decoder
	life_cycle Utf16DecoderLifeCycle
}

fn SourceUtf16StreamingDecoder.create(big_endian bool, remove_bom bool) SourceUtf16StreamingDecoder {
	return SourceUtf16StreamingDecoder{
		variant:    SourceUtf16Decoder.new_inner(big_endian)
		life_cycle: if !remove_bom {
			Utf16DecoderLifeCycle.converting
		} else if big_endian {
			Utf16DecoderLifeCycle.at_utf16_be_start
		} else {
			Utf16DecoderLifeCycle.at_utf16_le_start
		}
	}
}

fn (decoder &SourceUtf16StreamingDecoder) max_utf16_buffer_length(byte_length u64) ?u64 {
	match decoder.life_cycle {
		.converting, .at_utf16_be_start, .at_utf16_le_start {
			return decoder.variant.max_utf16_buffer_length(byte_length)
		}
		.seen_utf16_be_first, .seen_utf16_le_first {
			if byte_length > u64(0xffffffffffffffff) - 2 { return none }
			sum := byte_length + 2
			if sum > u64(0xffffffffffffffff) - 1 { return none }
			return 1 + (sum + 1) / 2
		}
		.finished { panic('Must not use a decoder that has finished.') }
	}
}

fn (mut decoder SourceUtf16StreamingDecoder) decode_to_utf16_without_replacement(input []u8, mut output []u16, last bool) (SingleByteDecoderResult, int, int) {
	return decoder.decode_to_utf16_without_replacement_at(input, 0, mut output, 0, last)
}

fn (mut decoder SourceUtf16StreamingDecoder) decode_to_utf16_without_replacement_at(input []u8, input_start int, mut output []u16, output_start int, last bool) (SingleByteDecoderResult, int, int) {
	mut offset := 0
	for {
		match decoder.life_cycle {
			.converting {
				return decoder.checking_end_utf16(input, input_start, mut output, output_start, last)
			}
			.at_utf16_be_start, .at_utf16_le_start {
				if input_start == input.len {
					return SingleByteDecoderResult{ status: .input_empty }, 0, 0
				}
				first := if decoder.life_cycle == .at_utf16_be_start { u8(0xfe) } else { u8(0xff) }
				if input[input_start] == first {
					decoder.life_cycle = if decoder.life_cycle == .at_utf16_be_start {
						Utf16DecoderLifeCycle.seen_utf16_be_first
					} else {
						Utf16DecoderLifeCycle.seen_utf16_le_first
					}
					offset++
					continue
				}
				decoder.life_cycle = .converting
			}
			.seen_utf16_be_first, .seen_utf16_le_first {
				first := if decoder.life_cycle == .seen_utf16_be_first {
					u8(0xfe)
				} else {
					u8(0xff)
				}
				second := if decoder.life_cycle == .seen_utf16_be_first {
					u8(0xff)
				} else {
					u8(0xfe)
				}
				if input_start + offset >= input.len {
					if last {
						return decoder.after_one_potential_bom_byte_utf16(input, input_start, mut output, output_start, last, offset, first)
					}
					return SingleByteDecoderResult{ status: .input_empty }, offset, 0
				}
				if input[input_start + offset] == second {
					decoder.life_cycle = .converting
					offset++
					// Off/Remove fixed-UTF16 constructors select exactly the
					// matching encoding already; Source morph is unreachable.
					result, read, written := decoder.checking_end_utf16(input, input_start + offset, mut output, output_start, last)
					return result, read + offset, written
				}
				return decoder.after_one_potential_bom_byte_utf16(input, input_start, mut output, output_start, last, offset, first)
			}
			.finished { panic('Must not use a decoder that has finished.') }
		}
	}
	return SingleByteDecoderResult{ status: .input_empty }, 0, 0
}

fn (mut decoder SourceUtf16StreamingDecoder) after_one_potential_bom_byte_utf16(input []u8, input_start int, mut output []u16, output_start int, last bool, offset int, first_byte u8) (SingleByteDecoderResult, int, int) {
	decoder.life_cycle = .converting
	if offset == 0 {
		first_result, _, first_written := decoder.variant.decode_to_utf16_raw_at([first_byte], 0, mut output, output_start, false)
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

fn (mut decoder SourceUtf16StreamingDecoder) checking_end_utf16(input []u8, input_start int, mut output []u16, output_start int, last bool) (SingleByteDecoderResult, int, int) {
	result, read, written := decoder.variant.decode_to_utf16_raw_at(input, input_start, mut output, output_start, last)
	if last && result.status == .input_empty { decoder.life_cycle = .finished }
	return result, read, written
}

fn (mut decoder SourceUtf16StreamingDecoder) decode_to_utf16(input []u8, mut output []u16, last bool) (SingleByteDecoderResult, int, int, bool) {
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

// Original Rust streaming decode_to_utf16 owns its maximum-capacity u16 Vec.
// Retain actual partial callback units internally on fatal failure; the C++
// caller withholds the failed result instead of exposing that partial output.
fn (mut decoder SourceUtf16StreamingDecoder) decode_owned_utf16(input []u8, last bool, fatal bool) (bool, []u16) {
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
