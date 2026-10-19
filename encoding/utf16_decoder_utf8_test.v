module encoding

import encoding.hex
import json2
import os

pub struct Utf16Utf8SourceRawStep {
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
	bytes            []u8
	units            []u16
	utf16            bool
	lead_surrogate   u16
	has_lead_byte    bool
	lead_byte        u8
	be               bool
	pending_bmp      bool
}

pub struct Utf16Utf8SourceRawSequence {
pub:
	be          bool
	replacement bool
	steps       []Utf16Utf8SourceRawStep
}

pub struct Utf16Utf8SourceCapacityValue {
pub:
	length                   u64
	utf16                    ?u64
	utf8                     ?u64
	utf8_without_replacement ?u64
}

pub struct Utf16Utf8SourceCapacityState {
pub:
	prefix_hex     string
	lead_surrogate u16
	has_lead_byte  bool
	lead_byte      u8
	be             bool
	pending_bmp    bool
	values         []Utf16Utf8SourceCapacityValue
}

fn assert_utf16_utf8_variant_slots(decoder SourceUtf16Decoder, lead_surrogate u16, has_lead_byte bool, lead_byte u8, be bool, pending_bmp bool) {
	assert decoder.lead_surrogate == lead_surrogate
	assert decoder.be == be && decoder.pending_bmp == pending_bmp
	if byte := decoder.lead_byte {
		assert has_lead_byte && byte == lead_byte
	} else {
		assert !has_lead_byte
	}
}

fn test_source_utf16_utf8_raw_matches_all_native_units_at_three_and_four_byte_destinations() {
	gold := os.read_bytes('${os.dir(@DIR)}/encoding/fixtures/utf16_utf8_raw_units.bin')!
	assert gold.len == 3407872
	mut at := 0
	for be in [false, true] {
		for unit in 0 .. 65536 {
			input := if be { [u8(unit >> 8), u8(unit)] } else { [u8(unit), u8(unit >> 8)] }
			for capacity in [3, 4] {
				mut decoder := SourceUtf16Decoder.new_inner(be)
				mut output := []u8{len: capacity}
				result, read, written := decoder.decode_to_utf8_raw(input, mut output, true)
				assert int(result.status) == int(gold[at])
				assert read == int(gold[at + 1]) && written == int(gold[at + 2])
				assert result.malformed_length == int(gold[at + 3]) && result.bytes_after == int(gold[at + 4])
				lead := u16(gold[at + 5]) | (u16(gold[at + 6]) << 8)
				assert_utf16_utf8_variant_slots(decoder, lead, gold[at + 7] != 0, gold[at + 8], be, gold[at + 9] != 0)
				assert output[..written] == gold[at + 10..at + 10 + written]
				at += 13
			}
		}
	}
	assert at == gold.len
}

fn test_source_utf16_utf8_raw_and_replacement_match_native_retained_slots_and_counters() {
	cases := json2.decode[[]Utf16Utf8SourceRawSequence](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf16_utf8_raw_sequences.json')!)!
	assert cases.len == 15248
	for item in cases {
		mut decoder := SourceUtf16Decoder.new_inner(item.be)
		// Repeat with Source remaining slices represented as positions on the
		// same original destination owner; writes must keep both guard units.
		mut positioned_decoder := SourceUtf16Decoder.new_inner(item.be)
		for step in item.steps {
			input := hex.decode(step.input_hex)!
			mut output := []u8{len: step.capacity}
			mut positioned_input := [u8(0xab), 0xcd]
			positioned_input << input
			mut positioned_output := []u8{len: step.capacity + 2}
			positioned_output[0] = 0xab
			positioned_output[1] = 0xcd
			if item.replacement {
				result, read, written, errors := decoder.decode_to_utf8(input, mut output, step.last)
				assert result.status.str() == step.status
				assert read == step.read && written == step.written && errors == step.had_errors
				assert output[..written] == step.bytes
				positioned_result, positioned_read, positioned_written, positioned_errors := positioned_decoder.decode_to_utf8_at(positioned_input, 2, mut positioned_output, 2, step.last)
				assert positioned_result.status.str() == step.status
				assert positioned_read == step.read && positioned_written == step.written && positioned_errors == step.had_errors
				assert positioned_output[2..2 + positioned_written] == step.bytes
			} else {
				result, read, written := decoder.decode_to_utf8_raw(input, mut output, step.last)
				assert result.status.str() == step.status
				assert read == step.read && written == step.written
				assert result.malformed_length == step.malformed_length && result.bytes_after == step.bytes_after
				assert output[..written] == step.bytes
				positioned_result, positioned_read, positioned_written := positioned_decoder.decode_to_utf8_raw_at(positioned_input, 2, mut positioned_output, 2, step.last)
				assert positioned_result.status.str() == step.status
				assert positioned_result.malformed_length == step.malformed_length && positioned_result.bytes_after == step.bytes_after
				assert positioned_read == step.read && positioned_written == step.written
				assert positioned_output[2..2 + positioned_written] == step.bytes
			}
			assert positioned_output[..2] == [u8(0xab), 0xcd]
			assert_utf16_utf8_variant_slots(decoder, step.lead_surrogate, step.has_lead_byte, step.lead_byte, step.be, step.pending_bmp)
			assert_utf16_utf8_variant_slots(positioned_decoder, step.lead_surrogate, step.has_lead_byte, step.lead_byte, step.be, step.pending_bmp)
		}
	}
}

fn test_source_utf16_utf8_checked_capacity_matches_native_four_slot_state() {
	cases := json2.decode[[]Utf16Utf8SourceCapacityState](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf16_utf8_raw_capacities.json')!)!
	assert cases.len == 14
	for item in cases {
		mut decoder := SourceUtf16Decoder.new_inner(item.be)
		mut output := []u8{len: 32}
		decoder.decode_to_utf8_raw(hex.decode(item.prefix_hex)!, mut output, false)
		assert_utf16_utf8_variant_slots(decoder, item.lead_surrogate, item.has_lead_byte, item.lead_byte, item.be, item.pending_bmp)
		for value in item.values {
			assert decoder.max_utf16_buffer_length(value.length) == value.utf16
			assert decoder.max_utf8_buffer_length(value.length) == value.utf8
			assert decoder.max_utf8_buffer_length_without_replacement(value.length) == value.utf8_without_replacement
		}
	}
}

fn test_source_utf16_utf8_high_surrogate_and_odd_byte_eof_is_one_three_byte_error() {
	for be in [false, true] {
		input := if be { [u8(0xd8), 0, 0] } else { [u8(0), 0xd8, 0] }
		mut raw := SourceUtf16Decoder.new_inner(be)
		mut output := []u8{len: 4}
		result, read, written := raw.decode_to_utf8_raw(input, mut output, true)
		assert result.status == .malformed && result.malformed_length == 3 && result.bytes_after == 0
		assert read == 3 && written == 0
		assert raw.lead_surrogate == 0 && raw.lead_byte == none && !raw.pending_bmp
		mut decoder := SourceUtf16Decoder.new_inner(be)
		replaced, replaced_read, replaced_written, errors := decoder.decode_to_utf8(input, mut output, true)
		assert replaced.status == .input_empty && replaced_read == 3 && replaced_written == 3 && errors
		assert output[..replaced_written] == [u8(0xef), 0xbf, 0xbd]
	}
}

pub struct Utf16Utf8SourcePrefixCase {
pub:
	be        bool
	input_hex string
	capacity  int
	malformed bool
	read      int
	written   int
	bytes     []u8
}

pub struct Utf16Utf8SourceMixedSequence {
pub:
	be    bool
	steps []Utf16Utf8SourceRawStep
}

fn test_source_utf16_utf8_prefix_matches_actual_native_scalar_ascii_and_surrogate_edges() {
	cases := json2.decode[[]Utf16Utf8SourcePrefixCase](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf16_utf8_prefix_edges.json')!)!
	assert cases.len == 3168
	for item in cases {
		input := hex.decode(item.input_hex)!
		mut output := []u8{len: item.capacity}
		malformed, read, written := source_copy_utf16_to_utf8_at(input, 0, mut output, 0, item.be)
		assert malformed == item.malformed && read == item.read && written == item.written
		assert output[..written] == item.bytes
		mut positioned_input := [u8(0xab), 0xcd]
		positioned_input << input
		mut positioned_output := []u8{len: item.capacity + 2}
		positioned_output[0] = 0xab
		positioned_output[1] = 0xcd
		positioned_malformed, positioned_read, positioned_written := source_copy_utf16_to_utf8_at(positioned_input, 2, mut positioned_output, 2, item.be)
		assert positioned_malformed == item.malformed && positioned_read == item.read && positioned_written == item.written
		assert positioned_output[..2] == [u8(0xab), 0xcd]
		assert positioned_output[2..2 + positioned_written] == item.bytes
	}
}

fn test_source_utf16_variant_retains_same_native_slots_across_mixed_utf8_utf16_destinations() {
	cases := json2.decode[[]Utf16Utf8SourceMixedSequence](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf16_utf8_mixed_sequences.json')!)!
	assert cases.len == 672
	for item in cases {
		mut decoder := SourceUtf16Decoder.new_inner(item.be)
		for step in item.steps {
			input := hex.decode(step.input_hex)!
			if step.utf16 {
				mut output := []u16{len: step.capacity}
				result, read, written := decoder.decode_to_utf16_raw(input, mut output, step.last)
				assert result.status.str() == step.status && read == step.read && written == step.written
				assert result.malformed_length == step.malformed_length && result.bytes_after == step.bytes_after
				assert output[..written] == step.units
			} else {
				mut output := []u8{len: step.capacity}
				result, read, written := decoder.decode_to_utf8_raw(input, mut output, step.last)
				assert result.status.str() == step.status && read == step.read && written == step.written
				assert result.malformed_length == step.malformed_length && result.bytes_after == step.bytes_after
				assert output[..written] == step.bytes
			}
			assert_utf16_utf8_variant_slots(decoder, step.lead_surrogate, step.has_lead_byte, step.lead_byte, step.be, step.pending_bmp)
		}
	}
}
