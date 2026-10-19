module encoding

import encoding.hex
import json2
import os

pub struct Utf8StreamingSourceStep {
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
	life_cycle       string
	code_point       u32
	bytes_seen       int
	bytes_needed     int
	lower_boundary   u8
	upper_boundary   u8
	panic            bool
}

pub struct Utf8StreamingSourceSequence {
pub:
	remove_bom bool
	mode       int
	steps      []Utf8StreamingSourceStep
}

pub struct Utf8StreamingSourceCapacity {
pub:
	byte_length         string
	with_replacement    string
	without_replacement string
}

pub struct Utf8StreamingSourceStateCapacities {
pub:
	life_cycle     string
	code_point     u32
	bytes_seen     int
	bytes_needed   int
	lower_boundary u8
	upper_boundary u8
	capacities     []Utf8StreamingSourceCapacity
}

fn utf8_streaming_source_life_cycle(name string) Utf8DecoderLifeCycle {
	return match name {
		'AtUtf8Start' { Utf8DecoderLifeCycle.at_utf8_start }
		'SeenUtf8First' { Utf8DecoderLifeCycle.seen_utf8_first }
		'SeenUtf8Second' { Utf8DecoderLifeCycle.seen_utf8_second }
		'Converting' { Utf8DecoderLifeCycle.converting }
		'Finished' { Utf8DecoderLifeCycle.finished }
		else { panic('unexpected actual Source UTF8 life cycle ' + name) }
	}
}

fn test_source_utf8_outer_bom_off_remove_and_real_owned_output_match_native_calls() {
	cases := json2.decode[[]Utf8StreamingSourceSequence](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf8_streaming_sequences.json')!)!
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
			mut output := []u8{len: step.capacity}
			if item.mode >= 2 {
				capacity := if item.mode == 3 {
					decoder.max_utf8_buffer_length_without_replacement(u64(input.len))
				} else {
					decoder.max_utf8_buffer_length(u64(input.len))
				}
				assert capacity? == u64(step.capacity)
				ok, produced := decoder.decode_owned_utf8(input, step.last, item.mode == 3)
				assert ok == (step.status == 'input_empty')
				assert produced.bytes() == hex.decode(step.output_hex)!
			} else if item.mode == 1 {
				result, read, written, errors := decoder.decode_to_utf8(input, mut output, step.last)
				assert result.status.str() == step.status
				assert read == step.read && written == step.written
				assert errors == step.had_errors
				assert output[..written] == hex.decode(step.output_hex)!
			} else {
				result, read, written := decoder.decode_to_utf8_without_replacement(input, mut output, step.last)
				assert result.status.str() == step.status
				assert read == step.read && written == step.written
				assert result.malformed_length == step.malformed_length && result.bytes_after == step.bytes_after
				assert output[..written] == hex.decode(step.output_hex)!
			}
			assert decoder.life_cycle == utf8_streaming_source_life_cycle(step.life_cycle)
			assert decoder.variant.code_point == step.code_point
			assert decoder.variant.bytes_seen == step.bytes_seen && decoder.variant.bytes_needed == step.bytes_needed
			assert decoder.variant.lower_boundary == step.lower_boundary && decoder.variant.upper_boundary == step.upper_boundary
		}
	}
	assert fatal_calls == 144
}

fn test_source_utf8_outer_max_capacities_match_actual_lifecycle_and_variant_slots() {
	cases := json2.decode[[]Utf8StreamingSourceStateCapacities](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf8_streaming_capacities.json')!)!
	assert cases.len == 12
	for item in cases {
		decoder := SourceUtf8StreamingDecoder{
			life_cycle: utf8_streaming_source_life_cycle(item.life_cycle)
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
			if cap := decoder.max_utf8_buffer_length(length) {
				assert cap.str() == limits.with_replacement
			} else {
				assert limits.with_replacement == 'none'
			}
			if cap := decoder.max_utf8_buffer_length_without_replacement(length) {
				assert cap.str() == limits.without_replacement
			} else {
				assert limits.without_replacement == 'none'
			}
		}
	}
}

fn test_source_utf8_finished_use_and_short_replayed_bom_preserve_fatal_owner_boundaries() {
	if mode := os.getenv_opt('VOX2_UTF8_STREAM_FATAL') {
		mut decoder := SourceUtf8StreamingDecoder.create(mode == 'bom_replay')
		mut output := []u8{len: 8}
		if mode == 'bom_replay' {
			decoder.decode_to_utf8_without_replacement([u8(0xef)], mut output, false)
			mut short := []u8{}
			decoder.decode_to_utf8_without_replacement([u8(`A`)], mut short, false)
		} else {
			decoder.decode_to_utf8_without_replacement([u8(`A`)], mut output, true)
			if mode == 'finished_capacity' {
				decoder.max_utf8_buffer_length(0)
			} else {
				decoder.decode_to_utf8_without_replacement([], mut output, false)
			}
		}
		panic('Source outer fatal call unexpectedly returned')
	}
	for mode in ['bom_replay', 'finished_capacity', 'finished_decode'] {
		mut process := os.new_process(os.executable())
		defer { process.close() }
		mut environment := os.environ()
		environment['VOX2_UTF8_STREAM_FATAL'] = mode
		process.set_environment(environment)
		process.set_redirect_stdio()
		process.run()
		process.wait()
		output := process.stdout_slurp() + process.stderr_slurp()
		expected := if mode == 'bom_replay' {
			'Output buffer must have been too small.'
		} else {
			'Must not use a decoder that has finished.'
		}
		assert process.code != 0 && output.contains(expected), output
	}
}
