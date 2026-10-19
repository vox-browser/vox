module encoding

import encoding.hex
import json2
import os

pub struct ShiftJisWholeSourceEvent {
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

pub struct ShiftJisWholeSourceCase {
pub:
	remove_bom   bool
	input_hex    string
	utf8_hex     string
	ascii_prefix int
	borrowed     bool
	had_errors   bool
	fatal_ok     bool
	events       []ShiftJisWholeSourceEvent
}

fn shift_jis_whole_source_cases() ![]ShiftJisWholeSourceCase {
	return json2.decode[[]ShiftJisWholeSourceCase](os.read_file('${os.dir(@DIR)}/encoding/fixtures/shift_jis_whole_input.json')!)!
}

fn test_source_shift_jis_whole_original_ffi_outputs_errors_and_entire_fatal_withholding() {
	cases := shift_jis_whole_source_cases()!
	assert cases.len == 4140
	mut withheld := 0
	for item in cases {
		input := hex.decode(item.input_hex)!
		// Both matching-BOM flags select this same span for the pinned non-Unicode
		// Encoding. Native FFI records prove this rather than Unicode sniffing it.
		assert decode_source_shift_jis_whole_to_utf8(input, false)!.bytes() == hex.decode(item.utf8_hex)!
		if decoded := decode_source_shift_jis_whole_to_utf8(input, true) {
			assert item.fatal_ok && !item.had_errors
			assert decoded.bytes() == hex.decode(item.utf8_hex)!
		} else {
			assert !item.fatal_ok && item.had_errors
			assert err.msg() == 'TypeError: Decoding failed'
			withheld++
		}
	}
	assert withheld == 1780
}

fn test_source_shift_jis_whole_ascii_borrow_prefix_and_actual_owned_capacity_calls() {
	cases := shift_jis_whole_source_cases()!
	mut borrows := 0
	mut natural_reserves := 0
	for item in cases {
		input := hex.decode(item.input_hex)!
		assert source_shift_jis_ascii_valid_up_to(input) == item.ascii_prefix
		decoded, errors := decode_source_shift_jis_without_bom_handling(input)
		assert decoded.bytes() == hex.decode(item.utf8_hex)! && errors == item.had_errors
		if item.borrowed {
			assert item.ascii_prefix == input.len && !item.had_errors
			assert item.events.len == 0
			borrows++
			continue
		}
		assert item.ascii_prefix < input.len && item.events.len == 1
		mut owner := SourceShiftJisStreamingDecoder.create()
		assert owner.life_cycle == .converting
		remaining := u64(input.len - item.ascii_prefix)
		maximum := owner.max_utf8_buffer_length(remaining)?
		assert owner.max_utf8_buffer_length_without_replacement(remaining)? == maximum
		for event in item.events {
			assert event.input_start == item.ascii_prefix && event.output_start == item.ascii_prefix
			// Source's identical maxima make min(nextPow2(prefix+max),prefix+max)
			// the exact initial maximum. Keep its reserve arm without manufacturing
			// a naturally unreachable reserve call.
			assert u64(event.capacity) == u64(item.ascii_prefix) + maximum
			assert event.capacity_after == event.capacity
			mut positioned_input := [u8(0x55), 0xaa]
			positioned_input << input
			mut output := []u8{len: 2 + event.capacity, init: 0x99}
			for index in 0 .. item.ascii_prefix { output[2 + index] = input[index] }
			result, read, written, had_errors := owner.decode_to_utf8_at(positioned_input, 2 + item.ascii_prefix, mut output, 2 + item.ascii_prefix, true)
			assert result.status == if event.full {
				SingleByteDecoderStatus.output_full
			} else {
				SingleByteDecoderStatus.input_empty
			}
			assert read == event.read && written == event.written && had_errors == event.had_errors
			assert output[..2] == [u8(0x99), 0x99]
			assert output[2..2 + item.ascii_prefix + written] == hex.decode(item.utf8_hex)!
			assert owner.life_cycle == .finished
			if event.full { natural_reserves++ }
			assert event.needed == none
		}
	}
	assert borrows == 938 && natural_reserves == 0
}
