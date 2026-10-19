module encoding

import encoding.hex
import json2
import os

pub struct ShiftJisStreamingUtf16SourceStep {
pub:
	input_hex        string
	last             bool
	capacity         int
	status           string
	read             int
	written          int
	bad              int
	after            int
	had_errors       bool
	ok               bool
	callback_present bool
	units            []u16
	has_lead         bool
	lead             u8
	life_cycle       string
	panic            bool
}

pub struct ShiftJisStreamingUtf16SourceFatal {
pub:
	mode       string
	units      []u16
	has_lead   bool
	lead       u8
	life_cycle string
}

pub struct ShiftJisStreamingUtf16SourceSequence {
pub:
	remove_bom bool
	mode       int
	steps      []ShiftJisStreamingUtf16SourceStep
}

fn test_source_shift_jis_actual_utf16_outer_lifecycle_and_original_ffi_match_native_records() {
	cases := json2.decode[[]ShiftJisStreamingUtf16SourceSequence](os.read_file('${os.dir(@DIR)}/encoding/fixtures/shift_jis_streaming_utf16_sequences.json')!)!
	assert cases.len == 1704
	mut actual_fatal_calls := 0
	mut failed_partial_callbacks := 0
	for item in cases {
		// Source Off/Remove constructors have identical Converting state
		// for Shift_JIS; ignoreBOM's actual flag remains in the Common owner.
		mut decoder := SourceShiftJisStreamingDecoder.create()
		mut offset_decoder := SourceShiftJisStreamingDecoder.create()
		assert decoder.life_cycle == .converting
		for step in item.steps {
			if step.panic {
				actual_fatal_calls++
				// Native panics have no returned counters. Compiled children
				// below preserve the actual fatal category under -prod.
				break
			}
			input := hex.decode(step.input_hex)!
			if item.mode >= 2 {
				assert decoder.max_utf16_buffer_length(u64(input.len))? == u64(step.capacity)
				ok, decoded := decoder.decode_owned_utf16(input, step.last, item.mode == 3)
				assert ok == step.ok && decoded == step.units
				assert step.callback_present == (step.units.len > 0)
				if !ok && step.units.len > 0 { failed_partial_callbacks++ }
			} else {
				mut output := []u16{len: step.capacity}
				mut original_input := [u8(0x55), 0x66]
				original_input << input
				mut original_output := []u16{len: step.capacity + 3}
				original_output[0] = 0x11
				original_output[1] = 0x22
				original_output[2] = 0x33
				if item.mode == 1 {
					result, read, written, errors := decoder.decode_to_utf16(input, mut output, step.last)
					assert result.status.str() == step.status
					assert read == step.read && written == step.written && errors == step.had_errors
					assert output[..written] == step.units
					offset_result, offset_read, offset_written, offset_errors := offset_decoder.decode_to_utf16_at(original_input, 2, mut original_output, 3, step.last)
					assert offset_result == result && offset_read == read && offset_written == written && offset_errors == errors
				} else {
					result, read, written := decoder.decode_to_utf16_without_replacement(input, mut output, step.last)
					assert result.status.str() == step.status
					assert read == step.read && written == step.written
					assert result.malformed_length == step.bad && result.bytes_after == step.after
					assert output[..written] == step.units
					offset_result, offset_read, offset_written := offset_decoder.decode_to_utf16_without_replacement_at(original_input, 2, mut original_output, 3, step.last)
					assert offset_result == result && offset_read == read && offset_written == written
				}
				assert original_output[..3] == [u16(0x11), 0x22, 0x33]
				assert original_output[3..3 + step.written] == step.units
				assert offset_decoder.life_cycle == decoder.life_cycle
				assert offset_decoder.variant.lead == decoder.variant.lead
			}
			assert decoder.life_cycle.str() == step.life_cycle.to_lower()
			if lead := decoder.variant.lead {
				assert step.has_lead && lead == step.lead
			} else {
				assert !step.has_lead
			}
		}
	}
	assert actual_fatal_calls == 0 && failed_partial_callbacks > 0
}

fn test_source_shift_jis_utf16_finished_and_held_lead_short_replacement_keep_native_fatal_boundaries() {
	fatal := json2.decode[[]ShiftJisStreamingUtf16SourceFatal](os.read_file('${os.dir(@DIR)}/encoding/fixtures/shift_jis_streaming_utf16_fatal.json')!)!
	assert fatal.len == 4
	for item in fatal {
		assert !item.has_lead
		if item.mode.starts_with('short') {
			assert item.units == []u16{}
			assert item.life_cycle == 'Converting'
		} else {
			assert item.units == []u16{len: 8}
			assert item.life_cycle == 'Finished'
		}
	}
	if mode := os.getenv_opt('VOX2_SHIFT_JIS_UTF16_OWNER_FATAL') {
		mut decoder := SourceShiftJisStreamingDecoder.create()
		mut output := []u16{len: 8}
		if mode.starts_with('short') {
			decoder.decode_to_utf16_without_replacement([u8(0x82)], mut output, false)
			mut short := []u16{len: mode[5..].int()}
			decoder.decode_to_utf16([], mut short, true)
		} else {
			decoder.decode_to_utf16_without_replacement([], mut output, true)
			if mode == 'finished_capacity' {
				decoder.max_utf16_buffer_length(0)
			} else if mode == 'finished_owned' {
				decoder.decode_owned_utf16([], false, false)
			} else if mode == 'finished_replace' {
				decoder.decode_to_utf16([], mut output, false)
			} else {
				decoder.decode_to_utf16_without_replacement([], mut output, false)
			}
		}
		panic('Source Shift_JIS owner fatal boundary unexpectedly returned')
	}
	for mode in ['short0', 'finished_capacity', 'finished_raw', 'finished_owned', 'finished_replace'] {
		mut process := os.new_process(os.executable())
		defer { process.close() }
		mut environment := os.environ()
		environment['VOX2_SHIFT_JIS_UTF16_OWNER_FATAL'] = mode
		process.set_environment(environment)
		process.set_redirect_stdio()
		process.run()
		process.wait()
		output := process.stdout_slurp() + process.stderr_slurp()
		expected := if mode.starts_with('short') {
			'Source UTF16 replacement output index out of bounds'
		} else {
			'Must not use a decoder that has finished.'
		}
		assert process.code != 0 && output.contains(expected), output
	}
}

pub struct ShiftJisMixedOwnedSourceStep {
pub:
	input_hex        string
	last             bool
	utf16            bool
	capacity         int
	ok               bool
	callback_present bool
	units            []u16
	bytes            []u8
	has_lead         bool
	lead             u8
	life_cycle       string
}

pub struct ShiftJisMixedOwnedSourceSequence {
pub:
	remove_bom bool
	fatal      bool
	steps      []ShiftJisMixedOwnedSourceStep
}

fn test_source_shift_jis_both_owned_destinations_retain_one_actual_variant_and_lifecycle() {
	cases := json2.decode[[]ShiftJisMixedOwnedSourceSequence](os.read_file('${os.dir(@DIR)}/encoding/fixtures/shift_jis_mixed_owned_destinations.json')!)!
	assert cases.len == 568
	mut calls := 0
	mut failed_partial := 0
	for item in cases {
		mut decoder := SourceShiftJisStreamingDecoder.create()
		assert item.steps.len == 3
		for step in item.steps {
			input := hex.decode(step.input_hex)!
			if step.utf16 {
				assert decoder.max_utf16_buffer_length(u64(input.len))? == u64(step.capacity)
				ok, units := decoder.decode_owned_utf16(input, step.last, item.fatal)
				assert ok == step.ok && units == step.units
				assert step.callback_present == (units.len > 0)
				if !ok && units.len > 0 { failed_partial++ }
			} else {
				capacity := if item.fatal {
					decoder.max_utf8_buffer_length_without_replacement(u64(input.len))
				} else {
					decoder.max_utf8_buffer_length(u64(input.len))
				}
				assert capacity? == u64(step.capacity)
				ok, decoded := decoder.decode_owned_utf8(input, step.last, item.fatal)
				assert ok == step.ok && decoded.bytes() == step.bytes
				assert step.callback_present == (step.bytes.len > 0)
				if !ok && step.bytes.len > 0 { failed_partial++ }
			}
			assert decoder.life_cycle.str() == step.life_cycle.to_lower()
			if lead := decoder.variant.lead {
				assert step.has_lead && lead == step.lead
			} else {
				assert !step.has_lead
			}
			calls++
		}
	}
	assert calls == 1704 && failed_partial > 0
}
