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
// Source encoding_rs Utf16Decoder and decoder_functions! UTF16 expansion.
module encoding

// utf_16.rs::Utf16Decoder owns these actual four slots across raw calls.
struct SourceUtf16Decoder {
mut:
	lead_surrogate u16
	lead_byte      ?u8
	be             bool
	pending_bmp    bool
}

fn SourceUtf16Decoder.new_inner(big_endian bool) SourceUtf16Decoder {
	return SourceUtf16Decoder{ be: big_endian }
}

fn (decoder &SourceUtf16Decoder) additional_from_state() u64 {
	has_byte := if _ := decoder.lead_byte { u64(1) } else { u64(0) }
	return 1 + has_byte + if decoder.lead_surrogate == 0 { u64(0) } else { u64(2) }
}

// Source checked uint capacities on the pinned 64-bit native ABI. V array
// allocation limits remain a separate owner boundary.
fn (decoder &SourceUtf16Decoder) max_utf16_buffer_length(byte_length u64) ?u64 {
	extra := decoder.additional_from_state()
	if byte_length > u64(0xffffffffffffffff) - extra { return none }
	return 1 + (byte_length + extra) / 2
}

fn (decoder &SourceUtf16Decoder) max_utf8_buffer_length_without_replacement(byte_length u64) ?u64 {
	return decoder.max_utf8_buffer_length(byte_length)
}

fn (decoder &SourceUtf16Decoder) max_utf8_buffer_length(byte_length u64) ?u64 {
	extra := decoder.additional_from_state()
	if byte_length > u64(0xffffffffffffffff) - extra { return none }
	half := (byte_length + extra) / 2
	if half > (u64(0xffffffffffffffff) - 1) / 3 { return none }
	return 1 + 3 * half
}

fn source_utf16_unit_at(input []u8, at int, big_endian bool) u16 {
	return if big_endian {
		(u16(input[at]) << 8) | u16(input[at + 1])
	} else {
		(u16(input[at + 1]) << 8) | u16(input[at])
	}
}

// handles.rs::Utf16Destination::copy_utf16_from, UnalignedU16Slice's scalar
// copy_bmp_to and explicit Endian swap. Positions refer to original owners.
// The return flag carries Source's Some(read,written) malformed outcome.
fn source_copy_utf16_from_at(input []u8, input_start int, mut output []u16, output_start int, big_endian bool) (bool, int, int) {
	remaining_units := (input.len - input_start) / 2
	remaining_output := output.len - output_start
	mut length := if remaining_units < remaining_output {
		remaining_units
	} else {
		remaining_output
	}
	if length == 0 { return false, 0, 0 }
	last_unit := source_utf16_unit_at(input, input_start + (length - 1) * 2, big_endian)
	if last_unit >= 0xd800 && last_unit < 0xdc00 { length-- }
	mut offset := 0
	for offset < length {
		unit := source_utf16_unit_at(input, input_start + offset * 2, big_endian)
		// Source copy_bmp_to speculatively writes the surrogate, without
		// committing it in the returned written position on malformed input.
		output[output_start + offset] = unit
		if unit >= 0xd800 && unit < 0xe000 {
			second_pos := offset + 1
			if unit > 0xdbff || second_pos == length { return true, second_pos * 2, offset }
			second := source_utf16_unit_at(input, input_start + second_pos * 2, big_endian)
			if !(second >= 0xdc00 && second < 0xe000) { return true, second_pos * 2, offset }
			output[output_start + second_pos] = second
			offset += 2
			continue
		}
		offset++
	}
	return false, length * 2, length
}

fn (mut decoder SourceUtf16Decoder) decode_to_utf16_raw(input []u8, mut output []u16, last bool) (SingleByteDecoderResult, int, int) {
	return decoder.decode_to_utf16_raw_at(input, 0, mut output, 0, last)
}

fn (mut decoder SourceUtf16Decoder) decode_to_utf16_raw_at(input []u8, input_start int, mut output []u16, output_start int, last bool) (SingleByteDecoderResult, int, int) {
	mut read := input_start
	mut written := output_start
	if decoder.pending_bmp {
		if written == output.len { return SingleByteDecoderResult{ status: .output_full }, 0, 0 }
		output[written] = decoder.lead_surrogate
		written++
		decoder.pending_bmp = false
		decoder.lead_surrogate = 0
	}
	for {
		if decoder.lead_byte == none && decoder.lead_surrogate == 0 {
			malformed, copied_read, copied_written := source_copy_utf16_from_at(input, read, mut output, written, decoder.be)
			read += copied_read
			written += copied_written
			if malformed {
				return SingleByteDecoderResult{ status: .malformed, malformed_length: 2 }, read - input_start, written - output_start
			}
		}
		if read == input.len {
			if last && (decoder.lead_surrogate != 0 || decoder.lead_byte != none) {
				// Source EOF checks BMP space before clearing retained slots.
				// Its Full arm returns 0/0 even after a pending BMP preamble.
				if written == output.len {
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
		// decoder_functions! performs its astral check before consuming even
		// a first/partial byte or a BMP unit through the body path.
		if u64(written) + 1 >= u64(output.len) {
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
				output[written] = decoder.lead_surrogate
				output[written + 1] = unit
				written += 2
				decoder.lead_surrogate = 0
				continue
			}
			if decoder.lead_surrogate != 0 {
				decoder.lead_surrogate = unit
				decoder.pending_bmp = true
				return SingleByteDecoderResult{ status: .malformed, malformed_length: 2, bytes_after: 2 }, read - input_start, written - output_start
			}
			output[written] = unit
			written++
		} else {
			decoder.lead_byte = byte
		}
	}
	return SingleByteDecoderResult{ status: .input_empty }, read - input_start, written - output_start
}

// Source Decoder::decode_to_utf16 replacement loop over the actual variant.
fn (mut decoder SourceUtf16Decoder) decode_to_utf16(input []u8, mut output []u16, last bool) (SingleByteDecoderResult, int, int, bool) {
	return decoder.decode_to_utf16_at(input, 0, mut output, 0, last)
}

fn (mut decoder SourceUtf16Decoder) decode_to_utf16_at(input []u8, input_start int, mut output []u16, output_start int, last bool) (SingleByteDecoderResult, int, int, bool) {
	mut had_errors := false
	mut read := input_start
	mut written := output_start
	for {
		result, consumed, produced := decoder.decode_to_utf16_raw_at(input, read, mut output, written, last)
		read += consumed
		written += produced
		match result.status {
			.input_empty, .output_full {
				return result, read - input_start, written - output_start, had_errors
			}
			.malformed {
				had_errors = true
				output[written] = 0xfffd
				written++
			}
		}
	}
	return SingleByteDecoderResult{ status: .input_empty }, read - input_start, written - output_start, had_errors
}
