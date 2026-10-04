// Copyright Mozilla Foundation. See the COPYRIGHT
// file at the top-level directory of this distribution.
//
// Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
// https://www.apache.org/licenses/LICENSE-2.0> or the MIT license
// <LICENSE-MIT or https://opensource.org/licenses/MIT>, at your
// option. This file may not be copied, modified, or distributed
// except according to those terms.

// The above license applies to code in this file. The data in this
// file is generated from WHATWG's indexes.json, which came under
// the following license:

// Copyright © WHATWG (Apple, Google, Mozilla, Microsoft).
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

// Source shift_jis.rs body and ascii_compatible_two_byte_decoder_function! UTF8 expansion.
module encoding

struct SourceShiftJisDecoder {
mut:
	// Source stores the normalized lead offset, not the original byte.
	lead ?u8
}

fn SourceShiftJisDecoder.new_inner() SourceShiftJisDecoder { return SourceShiftJisDecoder{} }

fn (decoder &SourceShiftJisDecoder) in_neutral_state() bool { return decoder.lead == none }

fn (decoder &SourceShiftJisDecoder) plus_one_if_lead(byte_length u64) ?u64 {
	if decoder.lead != none {
		if byte_length == u64(0xffffffffffffffff) { return none }
		return byte_length + 1
	}
	return byte_length
}

fn (decoder &SourceShiftJisDecoder) max_utf16_buffer_length(byte_length u64) ?u64 {
	return decoder.plus_one_if_lead(byte_length)
}

fn (decoder &SourceShiftJisDecoder) max_utf8_buffer_length_without_replacement(byte_length u64) ?u64 {
	return decoder.max_utf8_buffer_length(byte_length)
}

fn (decoder &SourceShiftJisDecoder) max_utf8_buffer_length(byte_length u64) ?u64 {
	length := decoder.plus_one_if_lead(byte_length) or { return none }
	if length > u64(0xffffffffffffffff) / 3 { return none }
	return 3 * length
}

// shift_jis.rs trail-body lookup priority; None retains its later ASCII
// unread versus consumed-two-byte malformed branch in the owning raw call.
fn source_shift_jis_trail_decode(lead_minus_offset u8, byte u8) ?u16 {
	if lead_minus_offset == 1 && byte >= 0x9f && byte <= 0xf1 { return 0x3041 + u16(byte - 0x9f) }
	mut trail_minus_offset := 0
	if byte >= 0x40 && byte <= 0x7e {
		trail_minus_offset = int(byte) - 0x40
	} else if byte >= 0x80 && byte <= 0xfc {
		trail_minus_offset = int(byte) - 0x41
	} else {
		return none
	}
	if lead_minus_offset == 2 && trail_minus_offset < 0x56 {
		return 0x30a1 + u16(trail_minus_offset)
	}
	pointer := u64(lead_minus_offset) * 188 + u64(trail_minus_offset)
	if pointer >= 1410 && pointer - 1410 < u64(source_jis0208_level1_kanji.len) {
		return source_jis0208_level1_kanji[int(pointer - 1410)]
	}
	if pointer >= 4418 && pointer - 4418 < u64(source_jis0208_level2_and_additional_kanji.len) {
		return source_jis0208_level2_and_additional_kanji[int(pointer - 4418)]
	}
	if pointer >= 10744 && pointer - 10744 < u64(source_ibm_kanji.len) {
		return source_ibm_kanji[int(pointer - 10744)]
	}
	if pointer >= 8272 && pointer - 8272 < u64(source_ibm_kanji.len) {
		return source_ibm_kanji[int(pointer - 8272)]
	}
	if pointer >= 8836 && pointer <= 10715 { return u16(0xe000 - 8836 + pointer) }
	if bmp := source_jis0208_symbol_decode(pointer) { return bmp }
	if bmp := source_jis0208_range_decode(pointer) { return bmp }
	return none
}

fn (mut decoder SourceShiftJisDecoder) decode_to_utf8_raw(input []u8, mut output []u8, last bool) (SingleByteDecoderResult, int, int) {
	return decoder.decode_to_utf8_raw_at(input, 0, mut output, 0, last)
}

fn (mut decoder SourceShiftJisDecoder) decode_to_utf8_raw_at(input []u8, input_start int, mut output []u8, output_start int, last bool) (SingleByteDecoderResult, int, int) {
	mut read := input_start
	mut written := output_start
	// Source prolog handles the actual retained lead before ASCII copying.
	if lead := decoder.lead {
		if read == input.len {
			if last {
				decoder.lead = none
				return SingleByteDecoderResult{ status: .malformed, malformed_length: 1 }, 0, 0
			}
			return SingleByteDecoderResult{ status: .input_empty }, 0, 0
		}
		if written + 2 >= output.len {
			return SingleByteDecoderResult{ status: .output_full }, 0, 0
		}
		decoder.lead = none
		byte := input[read]
		read++
		if bmp := source_shift_jis_trail_decode(lead, byte) {
			written += source_write_utf16_bmp_as_utf8_at(bmp, mut output, written)
		} else {
			if byte < 0x80 { read-- }
			return SingleByteDecoderResult{ status: .malformed, malformed_length: if byte < 0x80 {
				1
			} else {
				2
			} }, read - input_start, written - output_start
		}
	}
	mut copy_ascii := true
	for {
		if copy_ascii {
			remaining_input := input.len - read
			remaining_output := output.len - written
			pending := if remaining_output < remaining_input {
				SingleByteDecoderStatus.output_full
			} else {
				SingleByteDecoderStatus.input_empty
			}
			length := if remaining_output < remaining_input {
				remaining_output
			} else {
				remaining_input
			}
			mut copied := 0
			for copied < length && input[read] < 128 {
				output[written] = input[read]
				read++
				written++
				copied++
			}
			if copied == length {
				return SingleByteDecoderResult{ status: pending }, read - input_start, written - output_start
			}
		} else if read == input.len {
			return SingleByteDecoderResult{ status: .input_empty }, read - input_start, written - output_start
		}
		if written + 2 >= output.len {
			return SingleByteDecoderResult{ status: .output_full }, read - input_start, written - output_start
		}
		non_ascii := input[read]
		read++
		if non_ascii < 128 {
			// Macro's inner loop reserves a BMP handle before this ASCII read,
			// then returns to the actual outer ASCII-copy path (punctuation=false).
			output[written] = non_ascii
			written++
			copy_ascii = true
			continue
		}
		mut lead_minus_offset := u8(0)
		if non_ascii >= 0x81 && non_ascii <= 0x9f {
			lead_minus_offset = non_ascii - 0x81
		} else if non_ascii >= 0xe0 && non_ascii <= 0xfc {
			lead_minus_offset = non_ascii - 0xc1
		} else {
			if non_ascii >= 0xa1 && non_ascii <= 0xdf {
				written += source_write_utf16_bmp_as_utf8_at(0xff61 + u16(non_ascii - 0xa1), mut output, written)
			} else if non_ascii == 0x80 {
				written += source_write_utf16_bmp_as_utf8_at(0x80, mut output, written)
			} else {
				return SingleByteDecoderResult{ status: .malformed, malformed_length: 1 }, read - input_start, written - output_start
			}
			copy_ascii = true
			continue
		}
		if read == input.len {
			if last {
				return SingleByteDecoderResult{ status: .malformed, malformed_length: 1 }, read - input_start, written - output_start
			}
			decoder.lead = lead_minus_offset
			return SingleByteDecoderResult{ status: .input_empty }, read - input_start, written - output_start
		}
		byte := input[read]
		read++
		if bmp := source_shift_jis_trail_decode(lead_minus_offset, byte) {
			written += source_write_utf16_bmp_as_utf8_at(bmp, mut output, written)
		} else {
			if byte < 0x80 { read-- }
			return SingleByteDecoderResult{ status: .malformed, malformed_length: if byte < 0x80 {
				1
			} else {
				2
			} }, read - input_start, written - output_start
		}
		copy_ascii = false
	}
	return SingleByteDecoderResult{ status: .input_empty }, read - input_start, written - output_start
}
