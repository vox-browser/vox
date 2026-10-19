module encoding

import encoding.hex
import json2
import os

pub struct Utf8Utf16StreamingSourceStep {
pub:
	remove_bom       bool
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
	ok               bool
	life_cycle       string
	code_point       u32
	bytes_seen       int
	bytes_needed     int
	lower_boundary   u8
	upper_boundary   u8
	panic            bool
}

pub struct Utf8Utf16StreamingSourceSequence {
pub:
	remove_bom bool
	mode       int
	steps      []Utf8Utf16StreamingSourceStep
}

pub struct Utf8Utf16StreamingSourceCapacity {
pub:
	byte_length string
	max_utf16   string
}

pub struct Utf8Utf16StreamingSourceStateCapacities {
pub:
	life_cycle     string
	code_point     u32
	bytes_seen     int
	bytes_needed   int
	lower_boundary u8
	upper_boundary u8
	capacities     []Utf8Utf16StreamingSourceCapacity
}

fn utf8_utf16_streaming_source_life_cycle(name string) Utf8DecoderLifeCycle {
	return match name {
		'AtUtf8Start' { Utf8DecoderLifeCycle.at_utf8_start }
		'SeenUtf8First' { Utf8DecoderLifeCycle.seen_utf8_first }
		'SeenUtf8Second' { Utf8DecoderLifeCycle.seen_utf8_second }
		'Converting' { Utf8DecoderLifeCycle.converting }
		'Finished' { Utf8DecoderLifeCycle.finished }
		else { panic('unexpected actual Source UTF8 life cycle ' + name) }
	}
}

fn test_source_utf8_utf16_outer_bom_off_remove_and_real_owned_output_match_native_calls() {
	cases := json2.decode[[]Utf8Utf16StreamingSourceSequence](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf8_utf16_streaming_sequences.json')!)!
	assert cases.len == 5000
	mut fatal_calls := 0
	for item in cases {
		mut decoder := SourceUtf8StreamingDecoder.create(item.remove_bom)
		for step in item.steps {
			if step.panic {
				// Actual native panic has no returned Source counters; dedicated
				// compiled children exercise both owner fatal boundaries below.
				fatal_calls++
				break
			}
			input := hex.decode(step.input_hex)!
			mut output := []u16{len: step.capacity}
			if item.mode >= 2 {
				assert decoder.max_utf16_buffer_length(u64(input.len))? == u64(step.capacity)
				ok, produced := decoder.decode_owned_utf16(input, step.last, item.mode == 3)
				assert ok == step.ok
				assert produced == step.units
			} else if item.mode == 1 {
				result, read, written, errors := decoder.decode_to_utf16(input, mut output, step.last)
				assert result.status.str() == step.status
				assert read == step.read && written == step.written
				assert errors == step.had_errors
				assert output[..written] == step.units
			} else {
				result, read, written := decoder.decode_to_utf16_without_replacement(input, mut output, step.last)
				assert result.status.str() == step.status
				assert read == step.read && written == step.written
				assert result.malformed_length == step.malformed_length && result.bytes_after == step.bytes_after
				assert output[..written] == step.units
			}
			assert decoder.life_cycle == utf8_utf16_streaming_source_life_cycle(step.life_cycle)
			assert decoder.variant.code_point == step.code_point
			assert decoder.variant.bytes_seen == step.bytes_seen && decoder.variant.bytes_needed == step.bytes_needed
			assert decoder.variant.lower_boundary == step.lower_boundary && decoder.variant.upper_boundary == step.upper_boundary
		}
	}
	assert fatal_calls == 76
}

fn test_source_utf8_utf16_outer_max_capacities_match_actual_lifecycle_and_variant_slots() {
	cases := json2.decode[[]Utf8Utf16StreamingSourceStateCapacities](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf8_utf16_streaming_capacities.json')!)!
	assert cases.len == 12
	for item in cases {
		assert item.capacities.len == 10
		decoder := SourceUtf8StreamingDecoder{
			life_cycle: utf8_utf16_streaming_source_life_cycle(item.life_cycle)
			variant:    SourceUtf8Decoder{
				code_point:     item.code_point
				bytes_seen:     item.bytes_seen
				bytes_needed:   item.bytes_needed
				lower_boundary: item.lower_boundary
				upper_boundary: item.upper_boundary
			}
		}
		for limits in item.capacities {
			length := limits.byte_length.u64()
			if cap := decoder.max_utf16_buffer_length(length) {
				assert cap.str() == limits.max_utf16
			} else {
				assert limits.max_utf16 == 'none'
			}
		}
	}
}

fn test_source_utf8_utf16_owned_fatal_output_matches_real_partial_ffi_callbacks() {
	cases := json2.decode[[]Utf8Utf16StreamingSourceStep](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf8_utf16_partial_callbacks.json')!)!
	assert cases.len == 16
	for item in cases {
		mut decoder := SourceUtf8StreamingDecoder.create(item.remove_bom)
		input := hex.decode(item.input_hex)!
		assert decoder.max_utf16_buffer_length(u64(input.len))? == u64(item.capacity)
		ok, units := decoder.decode_owned_utf16(input, item.last, true)
		assert !ok && !item.ok && units.len > 0
		assert units == item.units
		assert decoder.life_cycle == utf8_utf16_streaming_source_life_cycle(item.life_cycle)
		assert decoder.variant.code_point == item.code_point
		assert decoder.variant.bytes_seen == item.bytes_seen && decoder.variant.bytes_needed == item.bytes_needed
		assert decoder.variant.lower_boundary == item.lower_boundary && decoder.variant.upper_boundary == item.upper_boundary
	}
}

fn test_source_utf8_utf16_finished_use_and_short_replayed_bom_preserve_fatal_owner_boundaries() {
	if mode := os.getenv_opt('VOX2_UTF8_UTF16_STREAM_FATAL') {
		mut decoder := SourceUtf8StreamingDecoder.create(mode.starts_with('bom_replay'))
		mut output := []u16{len: 8}
		if mode.starts_with('bom_replay') {
			decoder.decode_to_utf16_without_replacement([u8(0xef)], mut output, false)
			mut short := []u16{len: if mode == 'bom_replay_one' { 1 } else { 0 }}
			decoder.decode_to_utf16_without_replacement([u8(`A`)], mut short, false)
		} else {
			decoder.decode_to_utf16_without_replacement([u8(`A`)], mut output, true)
			if mode == 'finished_capacity' {
				decoder.max_utf16_buffer_length(0)
			} else if mode == 'finished_owned' {
				decoder.decode_owned_utf16([], false, false)
			} else {
				decoder.decode_to_utf16_without_replacement([], mut output, false)
			}
		}
		panic('Source outer fatal call unexpectedly returned')
	}
	for mode in ['bom_replay_zero', 'bom_replay_one', 'finished_capacity', 'finished_decode',
		'finished_owned'] {
		mut process := os.new_process(os.executable())
		defer { process.close() }
		mut environment := os.environ()
		environment['VOX2_UTF8_UTF16_STREAM_FATAL'] = mode
		process.set_environment(environment)
		process.set_redirect_stdio()
		process.run()
		process.wait()
		output := process.stdout_slurp() + process.stderr_slurp()
		expected := if mode.starts_with('bom_replay') {
			'Output buffer must have been too small.'
		} else {
			'Must not use a decoder that has finished.'
		}
		assert process.code != 0 && output.contains(expected), output
	}
}
