// Copyright Mozilla Foundation
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

// Translation of the pinned LibTextCodec dependency encoding_rs 0.8.40:
// src/replacement.rs::ReplacementDecoder::decode_to_utf8_raw and
// src/lib.rs::Decoder::decode_to_utf8's replacement wrapper. This is the
// internal decoder; Source's public TextDecoder rejects its encoding labels.
module encoding

enum ReplacementDecoderStatus {
	input_empty
	output_full
	malformed
}

struct ReplacementDecoderResult {
	status           ReplacementDecoderStatus
	malformed_length int
	bytes_after      int
}

struct ReplacementDecoder {
mut:
	emitted bool
}

fn (mut decoder ReplacementDecoder) decode_to_utf8_raw(src []u8, dst []u8, _ bool) (ReplacementDecoderResult, int, int) {
	if decoder.emitted || src.len == 0 {
		return ReplacementDecoderResult{ status: .input_empty }, src.len, 0
	} else if dst.len < 3 {
		return ReplacementDecoderResult{ status: .output_full }, 0, 0
	} else {
		decoder.emitted = true
		return ReplacementDecoderResult{ status: .malformed, malformed_length: 1, bytes_after: 0 }, 1, 0
	}
}

fn (mut decoder ReplacementDecoder) decode_to_utf8(src []u8, mut dst []u8, last bool) (ReplacementDecoderStatus, int, int, bool) {
	mut had_errors := false
	mut total_read := 0
	mut total_written := 0
	for {
		result, read, written := decoder.decode_to_utf8_raw(src[total_read..], dst[total_written..],
			last)
		total_read += read
		total_written += written
		match result.status {
			.input_empty, .output_full {
				return result.status, total_read, total_written, had_errors
			}
			.malformed {
				had_errors = true
				dst[total_written] = 0xef
				total_written++
				dst[total_written] = 0xbf
				total_written++
				dst[total_written] = 0xbd
				total_written++
			}
		}
	}
	return ReplacementDecoderStatus.input_empty, total_read, total_written, had_errors
}

// The replacement decoder's max_utf8_buffer_length is always Some(3).
// LibTextCodec invokes the whole-input, replacement-mode path. For replacement
// encoding, decode_with_bom_removal passes its input unchanged.
fn decode_replacement_to_utf8(input []u8) string {
	mut decoder := ReplacementDecoder{}
	mut output := []u8{len: 3}
	status, read, written, _ := decoder.decode_to_utf8(input, mut output, true)
	assert status == .input_empty && read == input.len
	return output[..written].bytestr()
}
