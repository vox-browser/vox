module encoding

import encoding.hex
import json2
import os

pub struct Utf16WholeSourceEvent {
pub:
	input_start    int
	output_start   int
	capacity       int
	read           int
	written        int
	had_errors     bool
	full           bool
	needed         ?int
	capacity_after int
}

pub struct Utf16WholeSourceCase {
pub:
	be         bool
	remove_bom bool
	input_hex  string
	utf8_hex   string
	had_errors bool
	fatal_ok   bool
	events     []Utf16WholeSourceEvent
}

fn test_source_utf16_whole_input_original_ffi_outputs_errors_and_fatal_withholding() {
	cases := json2.decode[[]Utf16WholeSourceCase](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf16_whole_input.json')!)!
	assert cases.len == 1504
	mut fatal_withheld := 0
	for item in cases {
		input := hex.decode(item.input_hex)!
		expected := hex.decode(item.utf8_hex)!
		assert decode_source_utf16_whole_to_utf8(input, item.be, item.remove_bom, false)!.bytes() == expected
		if decoded := decode_source_utf16_whole_to_utf8(input, item.be, item.remove_bom, true) {
			assert item.fatal_ok && !item.had_errors
			assert decoded.bytes() == expected
		} else {
			assert !item.fatal_ok && item.had_errors
			assert err.msg() == 'TypeError: Decoding failed'
			fatal_withheld++
		}
	}
	assert fatal_withheld == 984
}

fn test_source_utf16_whole_initial_capacity_and_actual_decode_to_string_calls_match_native_body() {
	cases := json2.decode[[]Utf16WholeSourceCase](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf16_whole_input.json')!)!
	mut natural_reserve_calls := 0
	for item in cases {
		input := hex.decode(item.input_hex)!
		bom := if item.be { [u8(0xfe), 0xff] } else { [u8(0xff), 0xfe] }
		bytes := if item.remove_bom && input.len >= 2 && input[..2] == bom {
			input[2..]
		} else {
			input
		}
		mut owner := SourceUtf16StreamingDecoder.create(item.be, false)
		assert owner.life_cycle == .converting
		without_replacement := owner.max_utf8_buffer_length_without_replacement(u64(bytes.len))?
		with_replacement := owner.max_utf8_buffer_length(u64(bytes.len))?
		assert with_replacement == without_replacement
		// Source UTF16 is never potentially borrowable. Identical maximums
		// mean min(next_power_of_two(max),max) chooses max, leaving no
		// naturally reachable whole-input OutputFull reserve in this scope.
		assert item.events.len == 1
		decoded, errors := decode_source_utf16_without_bom_handling(bytes, item.be)
		assert decoded.bytes() == hex.decode(item.utf8_hex)! && errors == item.had_errors
		for event in item.events {
			assert event.input_start == 0 && event.output_start == 0
			assert u64(event.capacity) == with_replacement
			assert event.capacity_after == event.capacity
			mut positioned_input := [u8(0x55), 0xaa]
			positioned_input << bytes
			mut output := []u8{len: 2 + event.capacity, init: 0x99}
			result, read, written, had_errors := owner.decode_to_utf8_at(positioned_input, 2, mut output, 2, true)
			assert result.status == if event.full {
				SingleByteDecoderStatus.output_full
			} else {
				SingleByteDecoderStatus.input_empty
			}
			assert read == event.read && written == event.written && had_errors == event.had_errors
			assert output[..2] == [u8(0x99), 0x99]
			assert output[2..2 + written] == hex.decode(item.utf8_hex)!
			assert owner.life_cycle == .finished
			if event.full { natural_reserve_calls++ }
			assert event.needed == none
		}
	}
	assert natural_reserve_calls == 0
}
