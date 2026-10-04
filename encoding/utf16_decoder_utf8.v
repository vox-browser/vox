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
// Source UTF16 variant decoder_functions! UTF8 destination expansion.
module encoding

// handles.rs::Utf8Destination writes the actual BMP/pair bytes. Callers own
// Source destination-space checks before these indexed writes.
fn source_write_utf16_bmp_as_utf8_at(unit u16, mut output []u8, at int) int {
	if unit < 0x80 {
		output[at] = u8(unit)
		return 1
	}
	if unit < 0x800 {
		output[at] = u8((unit >> 6) | 0xc0)
		output[at + 1] = u8((unit & 0x3f) | 0x80)
		return 2
	}
	output[at] = u8((unit >> 12) | 0xe0)
	output[at + 1] = u8(((unit & 0xfc0) >> 6) | 0x80)
	output[at + 2] = u8((unit & 0x3f) | 0x80)
	return 3
}

fn source_write_utf16_pair_as_utf8_at(high u16, low u16, mut output []u8, at int) {
	point := (u32(high) << 10) + u32(low) - (((u32(0xd800) << 10) - 0x10000) + 0xdc00)
	output[at] = u8((point >> 18) | 0xf0)
	output[at + 1] = u8(((point & 0x3f000) >> 12) | 0x80)
	output[at + 2] = u8(((point & 0xfc0) >> 6) | 0x80)
	output[at + 3] = u8((point & 0x3f) | 0x80)
}

// handles.rs::Utf8Destination::copy_utf16_from and the actual scalar
// convert_unaligned_utf16_to_utf8/copy_unaligned_basic_latin_to_ascii_alu.
// Fold Source UnalignedU16Slice tail offsets onto the original byte owner.
fn source_copy_utf16_to_utf8_at(input []u8, input_start int, mut output []u8, output_start int, big_endian bool) (bool, int, int) {
	mut length := (input.len - input_start) / 2
	if length == 0 { return false, 0, 0 }
	last_unit := source_utf16_unit_at(input, input_start + (length - 1) * 2, big_endian)
	if last_unit >= 0xd800 && last_unit < 0xdc00 { length-- }
	// Source convert_unaligned_utf16_to_utf8 requires four bytes even when
	// the first input unit is ASCII and the last high surrogate was trimmed.
	if output.len - output_start < 4 { return false, 0, 0 }
	mut read_units := 0
	mut written := output_start
	output_limit_minus_three := output.len - 3
	for {
		remaining_units := length - read_units
		remaining_output := output.len - written
		copy_length := if remaining_units < remaining_output {
			remaining_units
		} else {
			remaining_output
		}
		mut copied := 0
		for copied < copy_length {
			unit := source_utf16_unit_at(input, input_start + (read_units + copied) * 2, big_endian)
			if unit > 0x7f { break }
			output[written + copied] = u8(unit)
			copied++
		}
		read_units += copied
		written += copied
		if copied == copy_length { return false, read_units * 2, written - output_start }
		mut non_ascii := source_utf16_unit_at(input, input_start + read_units * 2, big_endian)
		if written >= output_limit_minus_three { break }
		read_units++
		for {
			// Source wrapping_sub distinguishes BMP, high and low ranges.
			if !(non_ascii >= 0xd800 && non_ascii <= 0xdfff) {
				written += source_write_utf16_bmp_as_utf8_at(non_ascii, mut output, written)
			} else if non_ascii <= 0xdbff {
				if read_units < length {
					second := source_utf16_unit_at(input, input_start + read_units * 2, big_endian)
					if second >= 0xdc00 && second <= 0xdfff {
						read_units++
						source_write_utf16_pair_as_utf8_at(non_ascii, second, mut output, written)
						written += 4
					} else {
						return true, read_units * 2, written - output_start
					}
				} else {
					return true, read_units * 2, written - output_start
				}
			} else {
				return true, read_units * 2, written - output_start
			}
			if written >= output_limit_minus_three || read_units == length {
				return false, read_units * 2, written - output_start
			}
			unit := source_utf16_unit_at(input, input_start + read_units * 2, big_endian)
			read_units++
			if unit > 0x7f {
				non_ascii = unit
				continue
			}
			output[written] = u8(unit)
			written++
			break
		}
	}
	return false, read_units * 2, written - output_start
}

fn (mut decoder SourceUtf16Decoder) decode_to_utf8_raw(input []u8, mut output []u8, last bool) (SingleByteDecoderResult, int, int) {
	return decoder.decode_to_utf8_raw_at(input, 0, mut output, 0, last)
}

fn (mut decoder SourceUtf16Decoder) decode_to_utf8_raw_at(input []u8, input_start int, mut output []u8, output_start int, last bool) (SingleByteDecoderResult, int, int) {
	mut read := input_start
	mut written := output_start
	if decoder.pending_bmp {
		if u64(written) + 2 >= u64(output.len) {
			return SingleByteDecoderResult{ status: .output_full }, 0, 0
		}
		written += source_write_utf16_bmp_as_utf8_at(decoder.lead_surrogate, mut output, written)
		decoder.pending_bmp = false
		decoder.lead_surrogate = 0
	}
	for {
		if decoder.lead_byte == none && decoder.lead_surrogate == 0 {
			malformed, copied_read, copied_written := source_copy_utf16_to_utf8_at(input, read, mut output, written, decoder.be)
			read += copied_read
			written += copied_written
			if malformed {
				return SingleByteDecoderResult{ status: .malformed, malformed_length: 2 }, read - input_start, written - output_start
			}
		}
		if read == input.len {
			if last && (decoder.lead_surrogate != 0 || decoder.lead_byte != none) {
				if u64(written) + 2 >= u64(output.len) {
					return SingleByteDecoderResult{ status: .output_full }, 0, 0
				}
				if decoder.lead_surrogate != 0 {
					decoder.lead_surrogate = 0
					if decoder.lead_byte == none {
						return SingleByteDecoderResult{ status: .malformed, malformed_length: 2 }, read - input_start, written - output_start
					}
					decoder.lead_byte = none
					return SingleByteDecoderResult{ status: .malformed, malformed_length: 3 }, read - input_start, written - output_start
				}
				decoder.lead_byte = none
				return SingleByteDecoderResult{ status: .malformed, malformed_length: 1 }, read - input_start, written - output_start
			}
			return SingleByteDecoderResult{ status: .input_empty }, read - input_start, written - output_start
		}
		if u64(written) + 3 >= u64(output.len) {
			return SingleByteDecoderResult{ status: .output_full }, read - input_start, written - output_start
		}
		byte := input[read]
		read++
		if lead := decoder.lead_byte {
			decoder.lead_byte = none
			unit := if decoder.be {
				(u16(lead) << 8) | u16(byte)
			} else {
				(u16(byte) << 8) | u16(lead)
			}
			high_bits := unit & 0xfc00
			if high_bits == 0xd800 {
				if decoder.lead_surrogate != 0 {
					decoder.lead_surrogate = unit
					return SingleByteDecoderResult{ status: .malformed, malformed_length: 2, bytes_after: 2 }, read - input_start, written - output_start
				}
				decoder.lead_surrogate = unit
				continue
			}
			if high_bits == 0xdc00 {
				if decoder.lead_surrogate == 0 {
					return SingleByteDecoderResult{ status: .malformed, malformed_length: 2 }, read - input_start, written - output_start
				}
				source_write_utf16_pair_as_utf8_at(decoder.lead_surrogate, unit, mut output, written)
				written += 4
				decoder.lead_surrogate = 0
				continue
			}
			if decoder.lead_surrogate != 0 {
				decoder.lead_surrogate = unit
				decoder.pending_bmp = true
				return SingleByteDecoderResult{ status: .malformed, malformed_length: 2, bytes_after: 2 }, read - input_start, written - output_start
			}
			written += source_write_utf16_bmp_as_utf8_at(unit, mut output, written)
		} else {
			decoder.lead_byte = byte
		}
	}
	return SingleByteDecoderResult{ status: .input_empty }, read - input_start, written - output_start
}

fn (mut decoder SourceUtf16Decoder) decode_to_utf8(input []u8, mut output []u8, last bool) (SingleByteDecoderResult, int, int, bool) {
	return decoder.decode_to_utf8_at(input, 0, mut output, 0, last)
}

fn (mut decoder SourceUtf16Decoder) decode_to_utf8_at(input []u8, input_start int, mut output []u8, output_start int, last bool) (SingleByteDecoderResult, int, int, bool) {
	mut had_errors := false
	mut read := input_start
	mut written := output_start
	for {
		result, consumed, produced := decoder.decode_to_utf8_raw_at(input, read, mut output, written, last)
		read += consumed
		written += produced
		match result.status {
			.input_empty, .output_full {
				return result, read - input_start, written - output_start, had_errors
			}
			.malformed {
				had_errors = true
				output[written] = 0xef
				output[written + 1] = 0xbf
				output[written + 2] = 0xbd
				written += 3
			}
		}
	}
	return SingleByteDecoderResult{ status: .input_empty }, read - input_start, written - output_start, had_errors
}
