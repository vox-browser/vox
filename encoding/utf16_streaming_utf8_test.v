module encoding

import encoding.hex
import json2
import os

pub struct Utf16Utf8StreamingSourceStep {
pub:
	be               bool
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
	bytes            []u8
	units            []u16
	utf16            bool
	ok               bool
	life_cycle       string
	lead_surrogate   u16
	has_lead_byte    bool
	lead_byte        u8
	pending_bmp      bool
	panic            bool
}

pub struct Utf16Utf8StreamingSourceSequence {
pub:
	be         bool
	remove_bom bool
	mode       int
	steps      []Utf16Utf8StreamingSourceStep
}

pub struct Utf16Utf8StreamingSourceCapacity {
pub:
	byte_length                  string
	max_utf8                     string
	max_utf8_without_replacement string
}

pub struct Utf16Utf8StreamingSourceStateCapacities {
pub:
	life_cycle     string
	lead_surrogate u16
	has_lead_byte  bool
	lead_byte      u8
	be             bool
	pending_bmp    bool
	capacities     []Utf16Utf8StreamingSourceCapacity
}

fn assert_utf16_utf8_streaming_variant_slots(decoder SourceUtf16Decoder, lead_surrogate u16, has_lead_byte bool, lead_byte u8, be bool, pending_bmp bool) {
	assert decoder.lead_surrogate == lead_surrogate
	assert decoder.be == be && decoder.pending_bmp == pending_bmp
	if byte := decoder.lead_byte {
		assert has_lead_byte && byte == lead_byte
	} else {
		assert !has_lead_byte
	}
}

fn utf16_utf8_streaming_source_life_cycle(name string) Utf16DecoderLifeCycle {
	return match name {
		'AtUtf16BeStart' { Utf16DecoderLifeCycle.at_utf16_be_start }
		'AtUtf16LeStart' { Utf16DecoderLifeCycle.at_utf16_le_start }
		'SeenUtf16BeFirst' { Utf16DecoderLifeCycle.seen_utf16_be_first }
		'SeenUtf16LeFirst' { Utf16DecoderLifeCycle.seen_utf16_le_first }
		'Converting' { Utf16DecoderLifeCycle.converting }
		'Finished' { Utf16DecoderLifeCycle.finished }
		else { panic('unexpected actual Source UTF16 life cycle ' + name) }
	}
}

fn test_source_utf16_utf8_outer_bom_off_remove_and_real_owned_output_match_native_calls() {
	cases := json2.decode[[]Utf16Utf8StreamingSourceSequence](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf16_utf8_streaming_sequences.json')!)!
	assert cases.len == 13840
	mut fatal_calls := 0
	for item in cases {
		mut decoder := SourceUtf16StreamingDecoder.create(item.be, item.remove_bom)
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
				assert decoder.max_utf8_buffer_length(u64(input.len))? == u64(step.capacity)
				ok, produced := decoder.decode_owned_utf8(input, step.last, item.mode == 3)
				assert ok == step.ok
				assert produced.bytes() == step.bytes
			} else if item.mode == 1 {
				result, read, written, errors := decoder.decode_to_utf8(input, mut output, step.last)
				assert result.status.str() == step.status
				assert read == step.read && written == step.written
				assert errors == step.had_errors
				assert output[..written] == step.bytes
			} else {
				result, read, written := decoder.decode_to_utf8_without_replacement(input, mut output, step.last)
				assert result.status.str() == step.status
				assert read == step.read && written == step.written
				assert result.malformed_length == step.malformed_length && result.bytes_after == step.bytes_after
				assert output[..written] == step.bytes
			}
			assert decoder.life_cycle == utf16_utf8_streaming_source_life_cycle(step.life_cycle)
			assert_utf16_utf8_streaming_variant_slots(decoder.variant, step.lead_surrogate, step.has_lead_byte, step.lead_byte, step.be, step.pending_bmp)
		}
	}
	assert fatal_calls == 48
}

fn test_source_utf16_utf8_outer_max_capacities_match_actual_lifecycle_and_variant_slots() {
	cases := json2.decode[[]Utf16Utf8StreamingSourceStateCapacities](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf16_utf8_streaming_capacities.json')!)!
	assert cases.len == 28
	for item in cases {
		assert item.capacities.len == 10
		decoder := SourceUtf16StreamingDecoder{
			life_cycle: utf16_utf8_streaming_source_life_cycle(item.life_cycle)
			variant:    SourceUtf16Decoder{
				lead_surrogate: item.lead_surrogate
				lead_byte:      if item.has_lead_byte { ?u8(item.lead_byte) } else { none }
				be:             item.be
				pending_bmp:    item.pending_bmp
			}
		}
		for limits in item.capacities {
			length := limits.byte_length.u64()
			if cap := decoder.max_utf8_buffer_length(length) {
				assert cap.str() == limits.max_utf8
			} else {
				assert limits.max_utf8 == 'none'
			}
			if cap := decoder.max_utf8_buffer_length_without_replacement(length) {
				assert cap.str() == limits.max_utf8_without_replacement
			} else {
				assert limits.max_utf8_without_replacement == 'none'
			}
		}
	}
}

fn test_source_utf16_utf8_owned_fatal_output_matches_real_partial_ffi_callbacks() {
	cases := json2.decode[[]Utf16Utf8StreamingSourceStep](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf16_utf8_partial_callbacks.json')!)!
	assert cases.len == 32
	for item in cases {
		mut decoder := SourceUtf16StreamingDecoder.create(item.be, item.remove_bom)
		input := hex.decode(item.input_hex)!
		assert decoder.max_utf8_buffer_length(u64(input.len))? == u64(item.capacity)
		ok, bytes := decoder.decode_owned_utf8(input, item.last, true)
		assert !ok && !item.ok && bytes.len > 0
		assert bytes.bytes() == item.bytes
		assert decoder.life_cycle == utf16_utf8_streaming_source_life_cycle(item.life_cycle)
		assert_utf16_utf8_streaming_variant_slots(decoder.variant, item.lead_surrogate, item.has_lead_byte, item.lead_byte, item.be, item.pending_bmp)
	}
}

fn test_source_utf16_utf8_finished_use_and_short_replayed_bom_preserve_fatal_owner_boundaries() {
	if mode := os.getenv_opt('VOX2_UTF16_UTF8_STREAM_FATAL') {
		be := mode.ends_with('_be')
		mut decoder := SourceUtf16StreamingDecoder.create(be, mode.starts_with('bom_replay'))
		mut output := []u8{len: 8}
		if mode.starts_with('bom_replay') {
			decoder.decode_to_utf8_without_replacement([if be { u8(0xfe) } else { u8(0xff) }], mut output, false)
			mut short := []u8{len: if mode.starts_with('bom_replay_one') { 1 } else { 0 }}
			decoder.decode_to_utf8_without_replacement([u8(`A`)], mut short, false)
		} else {
			decoder.decode_to_utf8_without_replacement(if be {
				[u8(0), `A`]
			} else {
				[u8(`A`), 0]
			}, mut output, true)
			if mode.starts_with('finished_capacity') {
				decoder.max_utf8_buffer_length(0)
			} else if mode.starts_with('finished_owned') {
				decoder.decode_owned_utf8([], false, false)
			} else {
				decoder.decode_to_utf8_without_replacement([], mut output, false)
			}
		}
		panic('Source outer fatal call unexpectedly returned')
	}
	for mode in ['bom_replay_zero', 'bom_replay_one', 'finished_capacity', 'finished_decode',
		'finished_owned', 'bom_replay_zero_be', 'bom_replay_one_be', 'finished_capacity_be',
		'finished_decode_be', 'finished_owned_be'] {
		mut process := os.new_process(os.executable())
		defer { process.close() }
		mut environment := os.environ()
		environment['VOX2_UTF16_UTF8_STREAM_FATAL'] = mode
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

pub struct Utf16Utf8StreamingSourceMixedSequence {
pub:
	be         bool
	remove_bom bool
	fatal      bool
	steps      []Utf16Utf8StreamingSourceStep
}

fn test_source_utf16_same_owning_record_mixed_utf8_utf16_destinations_match_original_ffi() {
	cases := json2.decode[[]Utf16Utf8StreamingSourceMixedSequence](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf16_utf8_mixed_owners.json')!)!
	assert cases.len == 768
	for item in cases {
		mut decoder := SourceUtf16StreamingDecoder.create(item.be, item.remove_bom)
		for step in item.steps {
			input := hex.decode(step.input_hex)!
			if step.utf16 {
				assert decoder.max_utf16_buffer_length(u64(input.len))? == u64(step.capacity)
				ok, units := decoder.decode_owned_utf16(input, step.last, item.fatal)
				assert ok == step.ok && units == step.units
			} else {
				actual_capacity := if item.fatal {
					decoder.max_utf8_buffer_length_without_replacement(u64(input.len))
				} else {
					decoder.max_utf8_buffer_length(u64(input.len))
				}
				assert actual_capacity? == u64(step.capacity)
				ok, bytes := decoder.decode_owned_utf8(input, step.last, item.fatal)
				assert ok == step.ok && bytes.bytes() == step.bytes
			}
			assert decoder.life_cycle == utf16_utf8_streaming_source_life_cycle(step.life_cycle)
			assert_utf16_utf8_streaming_variant_slots(decoder.variant, step.lead_surrogate, step.has_lead_byte, step.lead_byte, step.be, step.pending_bmp)
		}
	}
}
