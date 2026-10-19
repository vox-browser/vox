module encoding

import encoding.hex
import json2
import os

pub struct Utf16SourceRawStep {
pub:
	input_hex        string
	capacity         int
	last             bool
	status           string
	read             int
	written          int
	malformed_length int
	bytes_after      int
	had_errors       bool
	units            []u16
	lead_surrogate   u16
	has_lead_byte    bool
	lead_byte        u8
	be               bool
	pending_bmp      bool
}

pub struct Utf16SourceRawSequence {
pub:
	be          bool
	replacement bool
	steps       []Utf16SourceRawStep
}

pub struct Utf16SourceCapacityValue {
pub:
	length                   u64
	utf16                    ?u64
	utf8                     ?u64
	utf8_without_replacement ?u64
}

pub struct Utf16SourceCapacityState {
pub:
	prefix_hex     string
	lead_surrogate u16
	has_lead_byte  bool
	lead_byte      u8
	be             bool
	pending_bmp    bool
	values         []Utf16SourceCapacityValue
}

fn assert_utf16_raw_slots(decoder SourceUtf16Decoder, lead_surrogate u16, has_lead_byte bool, lead_byte u8, be bool, pending_bmp bool) {
	assert decoder.lead_surrogate == lead_surrogate
	assert decoder.be == be && decoder.pending_bmp == pending_bmp
	if byte := decoder.lead_byte {
		assert has_lead_byte && byte == lead_byte
	} else {
		assert !has_lead_byte
	}
}

fn test_source_utf16_raw_matches_all_native_units_at_one_and_two_unit_destinations() {
	gold := os.read_bytes('${os.dir(@DIR)}/encoding/fixtures/utf16_raw_units.bin')!
	assert gold.len == 3670016
	mut at := 0
	for be in [false, true] {
		for unit in 0 .. 65536 {
			input := if be { [u8(unit >> 8), u8(unit)] } else { [u8(unit), u8(unit >> 8)] }
			for capacity in [1, 2] {
				mut decoder := SourceUtf16Decoder.new_inner(be)
				mut output := []u16{len: capacity}
				result, read, written := decoder.decode_to_utf16_raw(input, mut output, true)
				assert int(result.status) == int(gold[at])
				assert read == int(gold[at + 1]) && written == int(gold[at + 2])
				assert result.malformed_length == int(gold[at + 3]) && result.bytes_after == int(gold[at + 4])
				lead := u16(gold[at + 5]) | (u16(gold[at + 6]) << 8)
				assert_utf16_raw_slots(decoder, lead, gold[at + 7] != 0, gold[at + 8], be, gold[at + 9] != 0)
				for index in 0 .. written {
					slot := at + 10 + index * 2
					assert output[index] == u16(gold[slot]) | (u16(gold[slot + 1]) << 8)
				}
				at += 14
			}
		}
	}
	assert at == gold.len
}

fn test_source_utf16_raw_and_replacement_match_native_retained_slots_and_counters() {
	cases := json2.decode[[]Utf16SourceRawSequence](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf16_raw_sequences.json')!)!
	assert cases.len == 15248
	for item in cases {
		mut decoder := SourceUtf16Decoder.new_inner(item.be)
		// Repeat with Source remaining slices represented as positions on the
		// same original destination owner; writes must keep both guard units.
		mut positioned_decoder := SourceUtf16Decoder.new_inner(item.be)
		for step in item.steps {
			input := hex.decode(step.input_hex)!
			mut output := []u16{len: step.capacity}
			mut positioned_input := [u8(0xab), 0xcd]
			positioned_input << input
			mut positioned_output := []u16{len: step.capacity + 2}
			positioned_output[0] = 0xabcd
			positioned_output[1] = 0x1234
			if item.replacement {
				result, read, written, errors := decoder.decode_to_utf16(input, mut output, step.last)
				assert result.status.str() == step.status
				assert read == step.read && written == step.written && errors == step.had_errors
				assert output[..written] == step.units
				positioned_result, positioned_read, positioned_written, positioned_errors := positioned_decoder.decode_to_utf16_at(positioned_input, 2, mut positioned_output, 2, step.last)
				assert positioned_result.status.str() == step.status
				assert positioned_read == step.read && positioned_written == step.written && positioned_errors == step.had_errors
				assert positioned_output[2..2 + positioned_written] == step.units
			} else {
				result, read, written := decoder.decode_to_utf16_raw(input, mut output, step.last)
				assert result.status.str() == step.status
				assert read == step.read && written == step.written
				assert result.malformed_length == step.malformed_length && result.bytes_after == step.bytes_after
				assert output[..written] == step.units
				positioned_result, positioned_read, positioned_written := positioned_decoder.decode_to_utf16_raw_at(positioned_input, 2, mut positioned_output, 2, step.last)
				assert positioned_result.status.str() == step.status
				assert positioned_result.malformed_length == step.malformed_length && positioned_result.bytes_after == step.bytes_after
				assert positioned_read == step.read && positioned_written == step.written
				assert positioned_output[2..2 + positioned_written] == step.units
			}
			assert positioned_output[..2] == [u16(0xabcd), 0x1234]
			assert_utf16_raw_slots(decoder, step.lead_surrogate, step.has_lead_byte, step.lead_byte, step.be, step.pending_bmp)
			assert_utf16_raw_slots(positioned_decoder, step.lead_surrogate, step.has_lead_byte, step.lead_byte, step.be, step.pending_bmp)
		}
	}
}

fn test_source_utf16_checked_capacity_matches_native_four_slot_state() {
	cases := json2.decode[[]Utf16SourceCapacityState](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf16_raw_capacities.json')!)!
	assert cases.len == 14
	for item in cases {
		mut decoder := SourceUtf16Decoder.new_inner(item.be)
		mut output := []u16{len: 32}
		decoder.decode_to_utf16_raw(hex.decode(item.prefix_hex)!, mut output, false)
		assert_utf16_raw_slots(decoder, item.lead_surrogate, item.has_lead_byte, item.lead_byte, item.be, item.pending_bmp)
		for value in item.values {
			assert decoder.max_utf16_buffer_length(value.length) == value.utf16
			assert decoder.max_utf8_buffer_length(value.length) == value.utf8
			assert decoder.max_utf8_buffer_length_without_replacement(value.length) == value.utf8_without_replacement
		}
	}
}

fn test_source_utf16_high_surrogate_and_odd_byte_eof_is_one_three_byte_error() {
	for be in [false, true] {
		input := if be { [u8(0xd8), 0, 0] } else { [u8(0), 0xd8, 0] }
		mut raw := SourceUtf16Decoder.new_inner(be)
		mut output := []u16{len: 4}
		result, read, written := raw.decode_to_utf16_raw(input, mut output, true)
		assert result.status == .malformed && result.malformed_length == 3 && result.bytes_after == 0
		assert read == 3 && written == 0
		assert raw.lead_surrogate == 0 && raw.lead_byte == none && !raw.pending_bmp
		mut decoder := SourceUtf16Decoder.new_inner(be)
		replaced, replaced_read, replaced_written, errors := decoder.decode_to_utf16(input, mut output, true)
		assert replaced.status == .input_empty && replaced_read == 3 && replaced_written == 1 && errors
		assert output[..replaced_written] == [u16(0xfffd)]
	}
}
