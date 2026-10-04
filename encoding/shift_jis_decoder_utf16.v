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

// Source shift_jis.rs same body, UTF16 expansion of macros.rs:324–340.
// Both destinations retain the same actual normalized lead owner.
module encoding

fn (mut decoder SourceShiftJisDecoder) decode_to_utf16_raw(input []u8, mut output []u16, last bool) (SingleByteDecoderResult, int, int) {
	return decoder.decode_to_utf16_raw_at(input, 0, mut output, 0, last)
}

fn (mut decoder SourceShiftJisDecoder) decode_to_utf16_raw_at(input []u8, input_start int, mut output []u16, output_start int, last bool) (SingleByteDecoderResult, int, int) {
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
		if written >= output.len {
			return SingleByteDecoderResult{ status: .output_full }, 0, 0
		}
		decoder.lead = none
		byte := input[read]
		read++
		if bmp := source_shift_jis_trail_decode(lead, byte) {
			output[written] = bmp
			written++
		} else {
			if byte < 0x80 { read-- }
			return SingleByteDecoderResult{
				status:           .malformed
				malformed_length: if byte < 0x80 {
					1
				} else {
					2
				}
			}, read - input_start, written - output_start
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
				output[written] = u16(input[read])
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
		if written >= output.len {
			return SingleByteDecoderResult{ status: .output_full }, read - input_start, written - output_start
		}
		non_ascii := input[read]
		read++
		if non_ascii < 128 {
			// Source Utf16Destination reserves one BMP unit before this ASCII read,
			// then returns to the actual outer ASCII-copy path (punctuation=false).
			output[written] = u16(non_ascii)
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
				output[written] = 0xff61 + u16(non_ascii - 0xa1)
				written++
			} else if non_ascii == 0x80 {
				output[written] = 0x80
				written++
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
			output[written] = bmp
			written++
		} else {
			if byte < 0x80 { read-- }
			return SingleByteDecoderResult{
				status:           .malformed
				malformed_length: if byte < 0x80 {
					1
				} else {
					2
				}
			}, read - input_start, written - output_start
		}
		copy_ascii = false
	}
	return SingleByteDecoderResult{ status: .input_empty }, read - input_start, written - output_start
}
