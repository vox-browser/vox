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
// Source encoding_rs 0.8.40 SingleByteDecoder::decode_to_utf8_raw and
// handles.rs Utf8Destination/ByteSource scalar copy, BMP and position paths.
module encoding

enum Windows1252DecoderStatus {
	input_empty
	output_full
	malformed
}

struct Windows1252DecoderResult {
	status           Windows1252DecoderStatus
	malformed_length int
	bytes_after      int
}

struct Windows1252Decoder {}

// The flattened positions retain Source's consumed/written ownership. The
// scalar ASCII copy replaces only the upstream SIMD acceleration, with the
// same min-length, OutputFull and three-byte BMP-space checks.
fn (_ Windows1252Decoder) decode_to_utf8_raw(input []u8, mut output []u8, last bool) (Windows1252DecoderResult, int, int) {
	mut read := 0
	mut written := 0
	mut copy_ascii := true
	for {
		if copy_ascii {
			remaining_input := input.len - read
			remaining_output := output.len - written
			pending := if remaining_output < remaining_input {
				Windows1252DecoderStatus.output_full
			} else {
				Windows1252DecoderStatus.input_empty
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
				return Windows1252DecoderResult{ status: pending }, read, written
			}
		} else if read == input.len {
			return Windows1252DecoderResult{ status: .input_empty }, read, written
		}
		// Source check_space_bmp reserves three bytes before consuming the
		// next byte, including ASCII in the inner punctuation loop.
		if written + 2 >= output.len {
			return Windows1252DecoderResult{ status: .output_full }, read, written
		}
		byte := input[read]
		read++
		if byte < 128 {
			output[written] = byte
			written++
			// SingleByteDecoder's b<60 punctuation loop keeps its BMP
			// handle path; markup/text resumes the accelerated ASCII copy.
			copy_ascii = byte >= 60
			continue
		}
		mapped := windows_1252_table[int(byte) - 128]
		if mapped == 0 {
			return Windows1252DecoderResult{ status: .malformed, malformed_length: 1, bytes_after: 0 }, read, written
		}
		// handles.rs::write_bmp_excl_ascii -> write_mid/upper_bmp.
		if mapped < 0x800 {
			output[written] = u8((mapped >> 6) | 0xc0)
			output[written + 1] = u8((mapped & 0x3f) | 0x80)
			written += 2
		} else {
			output[written] = u8((mapped >> 12) | 0xe0)
			output[written + 1] = u8(((mapped & 0xfc0) >> 6) | 0x80)
			output[written + 2] = u8((mapped & 0x3f) | 0x80)
			written += 3
		}
		copy_ascii = false
	}
	return Windows1252DecoderResult{ status: .input_empty }, read, written
}

// SingleByteDecoder's max_utf8_buffer_length is checked byte_length * 3.
// All 128 Windows1252 table entries are defined, so neither fatal nor
// replacement mode encounters a malformed byte. Preserve Source's produced
// byte length at the owning UTF8 string boundary, including every NUL.
fn decode_windows_1252_to_utf8(input []u8) string {
	if input.len > int(0x7fffffff) / 3 {
		panic('Source checked Windows1252 UTF8 output capacity overflow')
	}
	decoder := Windows1252Decoder{}
	mut output := []u8{len: input.len * 3}
	result, read, written := decoder.decode_to_utf8_raw(input, mut output, true)
	if result.status != .input_empty || read != input.len {
		panic('Source VERIFY: Windows1252 maximum UTF8 output capacity')
	}
	return output[..written].bytestr()
}
