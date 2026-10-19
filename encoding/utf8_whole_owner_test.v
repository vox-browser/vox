module encoding

import encoding.hex
import json2
import os

pub struct Utf8WholeOwnerSourceEvent {
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
	life_before    string
	life_after     string
}

pub struct Utf8WholeOwnerSourceCase {
pub:
	remove_bom   bool
	input_hex    string
	utf8_hex     string
	valid_prefix int
	borrowed     bool
	had_errors   bool
	fatal_ok     bool
	events       []Utf8WholeOwnerSourceEvent
}

fn utf8_whole_owner_source_cases() ![]Utf8WholeOwnerSourceCase {
	return json2.decode[[]Utf8WholeOwnerSourceCase](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf8_whole_owner.json')!)!
}

fn utf8_whole_owner_source_span(item Utf8WholeOwnerSourceCase) ![]u8 {
	input := hex.decode(item.input_hex)!
	if item.remove_bom && input.len >= 3 && input[..3] == [u8(0xef), 0xbb, 0xbf] {
		return input[3..].clone()
	}
	return input
}

fn test_source_utf8_whole_off_owner_outputs_and_fatal_withholding_match_original_ffi() {
	cases := utf8_whole_owner_source_cases()!
	assert cases.len == 2170
	mut withheld := 0
	for item in cases {
		// Source whole matching-BOM removal selects this span before creating
		// the actual Off owner; this does not sniff another encoding.
		span := utf8_whole_owner_source_span(item)!
		decoded, had_errors := decode_source_utf8_without_bom_handling(span)
		assert decoded.bytes() == hex.decode(item.utf8_hex)!
		assert had_errors == item.had_errors
		if fatal := decode_utf8(span, true) {
			assert item.fatal_ok && fatal == decoded
		} else {
			assert !item.fatal_ok && err.msg() == 'TypeError: Decoding failed'
			withheld++
		}
	}
	assert withheld == 1888
}

fn test_source_utf8_whole_valid_prefix_and_off_lifecycle_match_actual_capacity_events() {
	cases := utf8_whole_owner_source_cases()!
	mut borrowed := 0
	mut natural_reserves := 0
	for item in cases {
		span := utf8_whole_owner_source_span(item)!
		expected := hex.decode(item.utf8_hex)!
		assert source_utf8_valid_up_to(span) == item.valid_prefix
		if item.borrowed {
			assert item.valid_prefix == span.len && !item.had_errors
			assert item.events.len == 0
			borrowed++
			continue
		}
		mut owner := SourceUtf8StreamingDecoder.create(false)
		assert owner.life_cycle == .converting
		remaining := u64(span.len - item.valid_prefix)
		without := u64(item.valid_prefix) + owner.max_utf8_buffer_length_without_replacement(remaining)?
		mut rounded := u64(1)
		for rounded < without { rounded *= 2 }
		with := u64(item.valid_prefix) + owner.max_utf8_buffer_length(remaining)?
		initial_capacity := if rounded < with { rounded } else { with }
		assert u64(item.events[0].capacity) == initial_capacity
		mut input := [u8(0x55), 0xaa]
		input << span
		mut output := []u8{len: 3 + int(initial_capacity), init: 0x99}
		for index in 0 .. item.valid_prefix { output[3 + index] = span[index] }
		for event in item.events {
			assert output.len == 3 + event.capacity
			assert event.life_before == 'Converting' && owner.life_cycle == .converting
			result, read, written, had_errors := owner.decode_to_utf8_at(input, 2 + event.input_start, mut output, 3 + event.output_start, true)
			assert result.status == if event.full {
				SingleByteDecoderStatus.output_full
			} else {
				SingleByteDecoderStatus.input_empty
			}
			assert read == event.read && written == event.written && had_errors == event.had_errors
			assert event.life_after == if event.full { 'Converting' } else { 'Finished' }
			assert owner.life_cycle == if event.full {
				Utf8DecoderLifeCycle.converting
			} else {
				Utf8DecoderLifeCycle.finished
			}
			assert output[..3] == [u8(0x99), 0x99, 0x99]
			produced := event.output_start + written
			assert output[3..3 + produced] == expected[..produced]
			if event.full {
				needed := owner.max_utf8_buffer_length(u64(span.len - event.input_start - read))?
				assert int(needed) == event.needed?
				// Native physical Vec reserve may exceed the additional request.
				// Replay its measured capacity for the next genuine owner call;
				// the production flattened V allocation boundary stays separate.
				assert event.capacity_after >= produced + int(needed)
				output << []u8{len: event.capacity_after - event.capacity, init: 0x99}
				natural_reserves++
			} else {
				assert event.needed == none && event.capacity_after == event.capacity
				assert produced == expected.len
			}
		}
		assert owner.life_cycle == .finished
	}
	assert borrowed == 282 && natural_reserves == 620
}
