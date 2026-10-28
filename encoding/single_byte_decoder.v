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

enum SingleByteDecoderStatus {
	input_empty
	output_full
	malformed
}

struct SingleByteDecoderResult {
	status           SingleByteDecoderStatus
	malformed_length int
	bytes_after      int
}

struct SourceSingleByteDecoder {
	table []u16
}

// The flattened positions retain Source's consumed/written ownership. The
// scalar ASCII copy replaces only the upstream SIMD acceleration, with the
// same min-length, OutputFull and three-byte BMP-space checks.
fn (decoder SourceSingleByteDecoder) decode_to_utf8_raw(input []u8, mut output []u8, last bool) (SingleByteDecoderResult, int, int) {
	return decoder.decode_to_utf8_raw_at(input, 0, mut output, 0, last)
}

// Source's source/destination slices use the original buffer with these base
// offsets. Mutable V slice arguments can copy storage, so retain that actual
// owning destination and lower the slice positions directly into its indices.
fn (decoder SourceSingleByteDecoder) decode_to_utf8_raw_at(input []u8, input_start int, mut output []u8, output_start int, _ bool) (SingleByteDecoderResult, int, int) {
	mut read := input_start
	mut written := output_start
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
		// Source check_space_bmp reserves three bytes before consuming the
		// next byte, including ASCII in the inner punctuation loop.
		if written + 2 >= output.len {
			return SingleByteDecoderResult{ status: .output_full }, read - input_start, written - output_start
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
		mapped := decoder.table[int(byte) - 128]
		if mapped == 0 {
			return SingleByteDecoderResult{ status: .malformed, malformed_length: 1, bytes_after: 0 }, read - input_start, written - output_start
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
	return SingleByteDecoderResult{ status: .input_empty }, read - input_start, written - output_start
}

// encoding_rs::Decoder::decode_to_utf8 replacement wrapper. SingleByte has no
// pending multi-byte state/BOM lifecycle, so its raw variant supplies the same
// Source slices and per-call consumed/written accounting here.
fn (decoder SourceSingleByteDecoder) decode_to_utf8(input []u8, mut output []u8, last bool) (SingleByteDecoderResult, int, int, bool) {
	mut had_errors := false
	mut total_read := 0
	mut total_written := 0
	for {
		result, read, written := decoder.decode_to_utf8_raw_at(input, total_read, mut output, total_written, last)
		total_read += read
		total_written += written
		match result.status {
			.input_empty, .output_full {
				return result, total_read, total_written, had_errors
			}
			.malformed {
				had_errors = true
				// Source raw decoder reserved BMP space before reporting
				// Malformed, so this exact U+FFFD write has three bytes.
				output[total_written] = 0xef
				total_written++
				output[total_written] = 0xbf
				total_written++
				output[total_written] = 0xbd
				total_written++
			}
		}
	}
	return SingleByteDecoderResult{ status: .input_empty }, total_read, total_written, had_errors
}

// Source's SingleByte maximum UTF8 capacity is checked byte_length * 3. Its
// Rust bridge checks fatal after replacement decoding and withholds callback
// output on malformed input. Keep the produced length explicit, including NUL.
fn decode_source_single_byte_to_utf8(input []u8, table []u16, fatal bool) !string {
	// Source uses uint capacity; flattened V owners have narrower int lengths.
	if input.len > int(0x7fffffff) / 3 {
		panic('SingleByte UTF8 output exceeds flattened V int array capacity')
	}
	decoder := SourceSingleByteDecoder{ table: table }
	mut output := []u8{len: input.len * 3}
	result, read, written, had_errors := decoder.decode_to_utf8(input, mut output, true)
	if result.status != .input_empty || read != input.len {
		panic('Source VERIFY: SingleByte maximum UTF8 output capacity')
	}
	if fatal && had_errors {
		return error('TypeError: Decoding failed')
	}
	return output[..written].bytestr()
}
