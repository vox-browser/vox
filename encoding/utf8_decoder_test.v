module encoding

import encoding.hex
import json2
import os

pub struct Utf8DecoderSourceStep {
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
	output_hex       string
	code_point       u32
	bytes_seen       int
	bytes_needed     int
	lower_boundary   u8
	upper_boundary   u8
	neutral          bool
	panic            bool
}

pub struct Utf8DecoderSourceSequence {
pub:
	replacement bool
	steps       []Utf8DecoderSourceStep
}

pub struct Utf8DecoderSourceCapacity {
pub:
	byte_length                  string
	max_utf16                    string
	max_utf8_without_replacement string
	max_utf8                     string
}

pub struct Utf8DecoderSourceStateCapacities {
pub:
	code_point     u32
	bytes_seen     int
	bytes_needed   int
	lower_boundary u8
	upper_boundary u8
	capacities     []Utf8DecoderSourceCapacity
}

fn test_source_utf8_short_eof_replacement_preserves_actual_fatal_boundary() {
	if capacity_text := os.getenv_opt('VOX2_UTF8_SHORT_OUTPUT') {
		mut decoder := SourceUtf8Decoder.new_inner()
		mut prefix_output := []u8{len: 8}
		decoder.decode_to_utf8([u8(0xe1)], mut prefix_output, false)
		mut output := []u8{len: capacity_text.int()}
		decoder.decode_to_utf8([], mut output, true)
		panic('expected Source short EOF output to fail fatally')
	}
	for capacity in 0 .. 3 {
		mut process := os.new_process(os.executable())
		defer { process.close() }
		mut environment := os.environ()
		environment['VOX2_UTF8_SHORT_OUTPUT'] = capacity.str()
		process.set_environment(environment)
		process.set_redirect_stdio()
		process.run()
		process.wait()
		output := process.stdout_slurp() + process.stderr_slurp()
		assert process.code != 0 && output.contains('array.set: index out of range (i,a.len):${capacity}, ${capacity}'), output
	}
}

fn test_source_utf8_five_slots_raw_and_replacement_match_actual_native_sequences() {
	cases := json2.decode[[]Utf8DecoderSourceSequence](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf8_decoder_sequences.json')!)!
	assert cases.len == 11932
	mut fatal_cases := 0
	for item in cases {
		mut decoder := SourceUtf8Decoder.new_inner()
		for step in item.steps {
			input := hex.decode(step.input_hex)!
			mut output := []u8{len: step.capacity}
			if step.panic {
				// Native has no returned counters here. The dedicated actual
				// compiled child test verifies these Source fatal calls.
				assert item.replacement && step.last && input.len == 0 && step.capacity < 3
				assert decoder.bytes_needed != 0
				fatal_cases++
				continue
			}
			if item.replacement {
				result, read, written, errors := decoder.decode_to_utf8(input, mut output, step.last)
				assert result.status.str() == step.status
				assert read == step.read && written == step.written
				assert errors == step.had_errors
				assert output[..written] == hex.decode(step.output_hex)!
			} else {
				result, read, written := decoder.decode_to_utf8_raw(input, mut output, step.last)
				assert result.status.str() == step.status
				assert read == step.read && written == step.written
				assert result.malformed_length == step.malformed_length && result.bytes_after == step.bytes_after
				assert output[..written] == hex.decode(step.output_hex)!
			}
			assert decoder.code_point == step.code_point
			assert decoder.bytes_seen == step.bytes_seen && decoder.bytes_needed == step.bytes_needed
			assert decoder.lower_boundary == step.lower_boundary && decoder.upper_boundary == step.upper_boundary
			assert decoder.in_neutral_state() == step.neutral
		}
	}
	assert fatal_cases == 27
}

fn test_source_utf8_checked_max_capacities_match_actual_observed_native_slots() {
	cases := json2.decode[[]Utf8DecoderSourceStateCapacities](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf8_decoder_capacities.json')!)!
	assert cases.len == 60
	for item in cases {
		decoder := SourceUtf8Decoder{
			code_point:     item.code_point
			bytes_seen:     item.bytes_seen
			bytes_needed:   item.bytes_needed
			lower_boundary: item.lower_boundary
			upper_boundary: item.upper_boundary
		}
		assert item.capacities.len == 8
		for bounds in item.capacities {
			length := bounds.byte_length.u64()
			if actual := decoder.max_utf16_buffer_length(length) {
				assert actual.str() == bounds.max_utf16
			} else {
				assert bounds.max_utf16 == 'none'
			}
			if actual := decoder.max_utf8_buffer_length_without_replacement(length) {
				assert actual.str() == bounds.max_utf8_without_replacement
			} else {
				assert bounds.max_utf8_without_replacement == 'none'
			}
			if actual := decoder.max_utf8_buffer_length(length) {
				assert actual.str() == bounds.max_utf8
			} else {
				assert bounds.max_utf8 == 'none'
			}
		}
	}
}
