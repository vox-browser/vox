module encoding

import os
import encoding.hex
import json2

fn assert_source_shift_jis_native_raw_record(mut decoder SourceShiftJisDecoder, input []u8, capacity int, last bool, fixture []u8, at int) int {
	record := fixture[at..at + 15]
	mut positioned := decoder
	mut output := []u8{len: capacity}
	result, read, written := decoder.decode_to_utf8_raw(input, mut output, last)
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
	assert output[..written] == record[7..7 + written]
	mut original_input := [u8(0x55), 0xaa]
	original_input << input
	mut original_output := []u8{len: capacity + 2, init: 0x99}
	positioned_result, positioned_read, positioned_written := positioned.decode_to_utf8_raw_at(original_input, 2, mut original_output, 2, last)
	assert positioned_result == result && positioned_read == read && positioned_written == written
	assert positioned.lead == decoder.lead
	assert original_output[..2] == [u8(0x99), 0x99]
	assert original_output[2..2 + written] == record[7..7 + written]
	return at + 15
}

fn test_source_shift_jis_raw_all_byte_pairs_whole_and_retained_split_calls_match_native_body() {
	fixture := os.read_bytes('${os.dir(@DIR)}/encoding/fixtures/shift_jis_raw_pairs.bin')!
	assert fixture.len == 524288 * 15
	mut at := 0
	for first in 0 .. 256 {
		for second in 0 .. 256 {
			for capacity in [3, 8] {
				mut whole := SourceShiftJisDecoder.new_inner()
				at = assert_source_shift_jis_native_raw_record(mut whole, [u8(first), u8(second)], capacity, true, fixture, at)
				mut split := SourceShiftJisDecoder.new_inner()
				at = assert_source_shift_jis_native_raw_record(mut split, [u8(first)], capacity, false, fixture, at)
				at = assert_source_shift_jis_native_raw_record(mut split, [u8(second)], capacity, false, fixture, at)
				at = assert_source_shift_jis_native_raw_record(mut split, [], capacity, true, fixture, at)
			}
		}
	}
	assert at == fixture.len
}

pub struct ShiftJisRawSourceCapacity {
pub:
	byte_length              string
	utf16                    string
	utf8                     string
	utf8_without_replacement string
}

pub struct ShiftJisRawSourceStateCapacities {
pub:
	has_lead   bool
	lead       u8
	neutral    bool
	capacities []ShiftJisRawSourceCapacity
}

fn test_source_shift_jis_actual_normalized_lead_and_checked_max_capacities() {
	cases := json2.decode[[]ShiftJisRawSourceStateCapacities](os.read_file('${os.dir(@DIR)}/encoding/fixtures/shift_jis_raw_capacities.json')!)!
	assert cases.len == 3
	for item in cases {
		decoder := SourceShiftJisDecoder{ lead: if item.has_lead { ?u8(item.lead) } else { none } }
		assert decoder.in_neutral_state() == item.neutral
		assert item.capacities.len == 9
		for capacity in item.capacities {
			length := capacity.byte_length.u64()
			if actual := decoder.max_utf16_buffer_length(length) {
				assert actual.str() == capacity.utf16
			} else {
				assert capacity.utf16 == 'none'
			}
			if actual := decoder.max_utf8_buffer_length(length) {
				assert actual.str() == capacity.utf8
			} else {
				assert capacity.utf8 == 'none'
			}
			if actual := decoder.max_utf8_buffer_length_without_replacement(length) {
				assert actual.str() == capacity.utf8_without_replacement
			} else {
				assert capacity.utf8_without_replacement == 'none'
			}
		}
	}
}

pub struct ShiftJisRawSourceEdgeStep {
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
	bytes     []u8
}

pub struct ShiftJisRawSourceEdgeSequence {
pub:
	steps []ShiftJisRawSourceEdgeStep
}

fn test_source_shift_jis_raw_short_output_pending_lead_ascii_unread_and_eof_order() {
	cases := json2.decode[[]ShiftJisRawSourceEdgeSequence](os.read_file('${os.dir(@DIR)}/encoding/fixtures/shift_jis_raw_edges.json')!)!
	assert cases.len > 500
	mut checked := 0
	for item in cases {
		mut decoder := SourceShiftJisDecoder.new_inner()
		assert item.steps.len == 3
		for step in item.steps {
			mut output := []u8{len: step.capacity}
			result, read, written := decoder.decode_to_utf8_raw(hex.decode(step.input_hex)!, mut output, step.last)
			assert result.status.str() == step.status && read == step.read && written == step.written
			assert result.malformed_length == step.bad && result.bytes_after == step.after
			assert output[..written] == step.bytes
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
