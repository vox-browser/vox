module encoding

import os
import encoding.hex
import json2

fn assert_source_shift_jis_native_utf16_raw_record(mut decoder SourceShiftJisDecoder, input []u8, capacity int, last bool, fixture []u8, at int) int {
	record := fixture[at..at + 15]
	mut positioned := decoder
	mut output := []u16{len: capacity}
	result, read, written := decoder.decode_to_utf16_raw(input, mut output, last)
	status := match record[0] {
		0 { SingleByteDecoderStatus.input_empty }
		1 { SingleByteDecoderStatus.output_full }
		2 { SingleByteDecoderStatus.malformed }
		else { panic('unexpected Source raw status') }
	}
	assert result.status == status
	assert read == int(record[1]) && written == int(record[2])
	assert result.malformed_length == int(record[3]) && result.bytes_after == int(record[4])
	if lead := decoder.lead {
		assert record[5] == 1 && lead == record[6]
	} else {
		assert record[5] == 0
	}
	mut units := []u16{}
	for index in 0 .. written {
		units << u16(record[7 + 2 * index]) | (u16(record[8 + 2 * index]) << 8)
	}
	assert output[..written] == units
	mut original_input := [u8(0x55), 0xaa]
	original_input << input
	mut original_output := []u16{len: capacity + 2, init: 0x99}
	positioned_result, positioned_read, positioned_written := positioned.decode_to_utf16_raw_at(original_input, 2, mut original_output, 2, last)
	assert positioned_result == result && positioned_read == read && positioned_written == written
	assert positioned.lead == decoder.lead
	assert original_output[..2] == [u16(0x99), 0x99]
	assert original_output[2..2 + written] == units
	return at + 15
}

fn test_source_shift_jis_raw_utf16_all_byte_pairs_whole_and_retained_split_calls_match_native_body() {
	fixture := os.read_bytes('${os.dir(@DIR)}/encoding/fixtures/shift_jis_utf16_raw_pairs.bin')!
	assert fixture.len == 524288 * 15
	mut at := 0
	for first in 0 .. 256 {
		for second in 0 .. 256 {
			for capacity in [1, 4] {
				mut whole := SourceShiftJisDecoder.new_inner()
				at = assert_source_shift_jis_native_utf16_raw_record(mut whole, [
					u8(first),
					u8(second),
				], capacity, true, fixture, at)
				mut split := SourceShiftJisDecoder.new_inner()
				at = assert_source_shift_jis_native_utf16_raw_record(mut split, [u8(first)], capacity, false, fixture, at)
				at = assert_source_shift_jis_native_utf16_raw_record(mut split, [u8(second)], capacity, false, fixture, at)
				at = assert_source_shift_jis_native_utf16_raw_record(mut split, [], capacity, true, fixture, at)
			}
		}
	}
	assert at == fixture.len
}

pub struct ShiftJisUtf16RawSourceEdgeStep {
pub:
	input_hex string
	last      bool
	capacity  int
	status    string
	read      int
	written   int
	bad       int
	after     int
	has_lead  bool
	lead      u8
	units     []u16
}

pub struct ShiftJisUtf16RawSourceEdgeSequence {
pub:
	steps []ShiftJisUtf16RawSourceEdgeStep
}

fn test_source_shift_jis_raw_utf16_short_output_pending_lead_ascii_unread_and_eof_order() {
	cases := json2.decode[[]ShiftJisUtf16RawSourceEdgeSequence](os.read_file('${os.dir(@DIR)}/encoding/fixtures/shift_jis_utf16_raw_edges.json')!)!
	assert cases.len == 290
	mut checked := 0
	for item in cases {
		mut decoder := SourceShiftJisDecoder.new_inner()
		assert item.steps.len == 3
		for step in item.steps {
			mut output := []u16{len: step.capacity}
			result, read, written := decoder.decode_to_utf16_raw(hex.decode(step.input_hex)!, mut output, step.last)
			assert result.status.str() == step.status && read == step.read && written == step.written
			assert result.malformed_length == step.bad && result.bytes_after == step.after
			assert output[..written] == step.units
			if lead := decoder.lead {
				assert step.has_lead && lead == step.lead
			} else {
				assert !step.has_lead
			}
			checked++
		}
	}
	assert checked == cases.len * 3
}

pub struct ShiftJisRawSourceMixedStep {
pub:
	input_hex string
	last      bool
	utf16     bool
	capacity  int
	status    string
	read      int
	written   int
	bad       int
	after     int
	has_lead  bool
	lead      u8
	units     []u16
	bytes     []u8
}

pub struct ShiftJisRawSourceMixedSequence {
pub:
	steps []ShiftJisRawSourceMixedStep
}

fn test_source_shift_jis_mixed_raw_destinations_retain_same_actual_lead_owner() {
	cases := json2.decode[[]ShiftJisRawSourceMixedSequence](os.read_file('${os.dir(@DIR)}/encoding/fixtures/shift_jis_raw_mixed_destinations.json')!)!
	assert cases.len == 232
	mut checked := 0
	for item in cases {
		mut decoder := SourceShiftJisDecoder.new_inner()
		assert item.steps.len == 3
		for step in item.steps {
			input := hex.decode(step.input_hex)!
			if step.utf16 {
				mut output := []u16{len: step.capacity}
				result, read, written := decoder.decode_to_utf16_raw(input, mut output, step.last)
				assert result.status.str() == step.status && read == step.read && written == step.written
				assert result.malformed_length == step.bad && result.bytes_after == step.after
				assert output[..written] == step.units
			} else {
				mut output := []u8{len: step.capacity}
				result, read, written := decoder.decode_to_utf8_raw(input, mut output, step.last)
				assert result.status.str() == step.status && read == step.read && written == step.written
				assert result.malformed_length == step.bad && result.bytes_after == step.after
				assert output[..written] == step.bytes
			}
			if lead := decoder.lead {
				assert step.has_lead && lead == step.lead
			} else {
				assert !step.has_lead
			}
			checked++
		}
	}
	assert checked == 696
}
