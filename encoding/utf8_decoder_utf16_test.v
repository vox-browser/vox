module encoding

import encoding.hex
import json2
import os

pub struct Utf8Utf16SourcePrefix {
pub:
	input_hex string
	capacity  int
	read      int
	written   int
	units     []u16
}

pub struct Utf8Utf16SourceStep {
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
	code_point       u32
	bytes_seen       int
	bytes_needed     int
	lower_boundary   u8
	upper_boundary   u8
	neutral          bool
	panic            bool
}

pub struct Utf8Utf16SourceSequence {
pub:
	replacement bool
	steps       []Utf8Utf16SourceStep
}

fn test_source_utf8_utf16_prefix_matches_all_native_byte_pairs_and_edges() {
	pairs := os.read_bytes('${os.dir(@DIR)}/encoding/fixtures/utf8_utf16_prefix_pairs.bin')!
	assert pairs.len == 655360
	mut at := 0
	for first in 0 .. 256 {
		for second in 0 .. 256 {
			for capacity in [1, 2] {
				mut output := []u16{len: capacity}
				read, written := source_convert_utf8_to_utf16_up_to_invalid([
					u8(first),
					u8(second),
				], mut output)
				assert read == int(pairs[at]) && written == int(pairs[at + 1])
				at += 2
				for index in 0 .. capacity {
					native_unit := u16(pairs[at]) | (u16(pairs[at + 1]) << 8)
					if index < written {
						assert output[index] == native_unit
					}
					at += 2
				}
			}
		}
	}
	assert at == pairs.len
	cases := json2.decode[[]Utf8Utf16SourcePrefix](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf8_utf16_prefix_edges.json')!)!
	assert cases.len == 3024
	for item in cases {
		mut output := []u16{len: item.capacity}
		read, written := source_convert_utf8_to_utf16_up_to_invalid(hex.decode(item.input_hex)!, mut output)
		assert read == item.read && written == item.written
		assert output[..written] == item.units
		// Source passes remaining slices of the actual owners. Keep
		// those owners here with explicit positions, preserving guards.
		mut positioned_input := [u8(0xff), 0xff]
		positioned_input << hex.decode(item.input_hex)!
		mut positioned_output := []u16{len: item.capacity + 2}
		positioned_output[0] = 0xabcd
		positioned_output[1] = 0x1234
		positioned_read, positioned_written := source_convert_utf8_to_utf16_up_to_invalid_at(positioned_input, 2, mut positioned_output, 2)
		assert positioned_read == item.read && positioned_written == item.written
		assert positioned_output[..2] == [u16(0xabcd), 0x1234]
		assert positioned_output[2..2 + positioned_written] == item.units
	}
}

fn test_source_utf8_raw_utf16_matches_actual_native_counters_output_and_five_slots() {
	cases := json2.decode[[]Utf8Utf16SourceSequence](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf8_utf16_decoder_sequences.json')!)!
	assert cases.len == 11932
	mut fatal_cases := 0
	for item in cases {
		mut decoder := SourceUtf8Decoder.new_inner()
		for step in item.steps {
			input := hex.decode(step.input_hex)!
			mut output := []u16{len: step.capacity}
			if step.panic {
				// Actual Source panics without return counters. The child
				// below executes its genuine zero-capacity EOF write.
				assert item.replacement && step.last && input.len == 0 && step.capacity == 0
				assert decoder.bytes_needed != 0
				fatal_cases++
				continue
			}
			if item.replacement {
				result, read, written, errors := decoder.decode_to_utf16(input, mut output, step.last)
				assert result.status.str() == step.status
				assert read == step.read && written == step.written
				assert errors == step.had_errors
				assert output[..written] == step.units
			} else {
				result, read, written := decoder.decode_to_utf16_raw(input, mut output, step.last)
				assert result.status.str() == step.status
				assert read == step.read && written == step.written
				assert result.malformed_length == step.malformed_length && result.bytes_after == step.bytes_after
				assert output[..written] == step.units
			}
			assert decoder.code_point == step.code_point
			assert decoder.bytes_seen == step.bytes_seen && decoder.bytes_needed == step.bytes_needed
			assert decoder.lower_boundary == step.lower_boundary && decoder.upper_boundary == step.upper_boundary
			assert decoder.in_neutral_state() == step.neutral
		}
	}
	assert fatal_cases == 9
}

fn test_source_utf8_utf16_eof_replacement_preserves_native_fatal_write() {
	if os.getenv('VOX2_UTF8_UTF16_ZERO_OUTPUT') == '1' {
		mut decoder := SourceUtf8Decoder.new_inner()
		mut prefix_output := []u16{len: 8}
		decoder.decode_to_utf16([u8(0xe1)], mut prefix_output, false)
		mut output := []u16{}
		decoder.decode_to_utf16([], mut output, true)
		panic('expected Source zero-capacity UTF16 EOF output to fail fatally')
	}
	mut process := os.new_process(os.executable())
	defer { process.close() }
	mut environment := os.environ()
	environment['VOX2_UTF8_UTF16_ZERO_OUTPUT'] = '1'
	process.set_environment(environment)
	process.set_redirect_stdio()
	process.run()
	process.wait()
	output := process.stdout_slurp() + process.stderr_slurp()
	assert process.code != 0 && output.contains('array.set: index out of range (i,a.len):0, 0'), output
}
