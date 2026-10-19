module encoding

import encoding.hex
import json2
import libjs
import os

pub struct TextDecoderUtf16VariantSourceStep {
pub:
	be             bool
	remove_bom     bool
	input_hex      string
	last           bool
	ok             bool
	units          []u16
	life_cycle     string
	lead_surrogate u16
	has_lead_byte  bool
	lead_byte      u8
	pending_bmp    bool
	panic          bool
}

pub struct TextDecoderUtf16VariantSourceSequence {
pub:
	be         bool
	remove_bom bool
	mode       int
	steps      []TextDecoderUtf16VariantSourceStep
}

pub struct TextDecoderUtf16EofSourceSequence {
pub:
	label      string
	remove_bom bool
	fatal      bool
	steps      []TextDecoderUtf16VariantSourceStep
}

fn text_decoder_utf16_variant_life_cycle(name string) Utf16DecoderLifeCycle {
	return match name {
		'AtUtf16BeStart' { Utf16DecoderLifeCycle.at_utf16_be_start }
		'AtUtf16LeStart' { Utf16DecoderLifeCycle.at_utf16_le_start }
		'SeenUtf16BeFirst' { Utf16DecoderLifeCycle.seen_utf16_be_first }
		'SeenUtf16LeFirst' { Utf16DecoderLifeCycle.seen_utf16_le_first }
		'Converting' { Utf16DecoderLifeCycle.converting }
		'Finished' { Utf16DecoderLifeCycle.finished }
		else { panic('unexpected actual Source UTF16 lifecycle ' + name) }
	}
}

fn assert_text_decoder_utf16_variant_after_call(decoder &TextDecoder, step TextDecoderUtf16VariantSourceStep, remove_bom bool) {
	assert decoder.utf16_decoder_present_
	assert decoder.pending_input.len == 0 && !decoder.bom_seen
	assert decoder.utf16_decoder_.variant.be == step.be
	if step.last {
		fresh := SourceUtf16StreamingDecoder.create(step.be, remove_bom)
		assert decoder.utf16_decoder_.life_cycle == fresh.life_cycle
		assert decoder.utf16_decoder_.variant.lead_surrogate == 0
		assert decoder.utf16_decoder_.variant.lead_byte == none && !decoder.utf16_decoder_.variant.pending_bmp
	} else {
		assert decoder.utf16_decoder_.life_cycle == text_decoder_utf16_variant_life_cycle(step.life_cycle)
		assert decoder.utf16_decoder_.variant.lead_surrogate == step.lead_surrogate
		assert decoder.utf16_decoder_.variant.pending_bmp == step.pending_bmp
		if byte := decoder.utf16_decoder_.variant.lead_byte {
			assert step.has_lead_byte && byte == step.lead_byte
		} else {
			assert !step.has_lead_byte
		}
	}
}

fn test_source_text_decoder_utf16_variants_project_actual_owned_ffi_units_and_keep_slots() {
	cases := json2.decode[[]TextDecoderUtf16VariantSourceSequence](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf16_streaming_sequences.json')!)!
	assert cases.len == 13840
	mut observed_calls := 0
	for item in cases {
		if item.mode < 2 { continue }
		label := if item.be { 'utf-16be' } else { 'utf-16le' }
		decoder := TextDecoder.construct(label, TextDecoderOptions{ fatal: item.mode == 3, ignore_bom: !item.remove_bom })!
		for step in item.steps {
			// Source public TextDecoder resets before returning a flushed
			// result; deliberate post-Finished decoder calls are internal.
			if step.panic { break }
			observed_calls++
			if result := decoder.decode(hex.decode(step.input_hex)!, TextDecodeOptions{ stream: !step.last }) {
				assert step.ok
				actual_owned := libjs.utf16_string_from_utf8_without_validation(result)
				assert actual_owned.code_units() == step.units
			} else {
				assert !step.ok && err.msg() == 'TypeError: Decoding failed'
			}
			assert_text_decoder_utf16_variant_after_call(decoder, step, item.remove_bom)
		}
	}
	assert observed_calls == 5192
}

fn test_source_text_decoder_utf16_variants_withhold_fatal_partial_callback_units() {
	cases := json2.decode[[]TextDecoderUtf16VariantSourceStep](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf16_partial_callbacks.json')!)!
	assert cases.len == 32
	for item in cases {
		assert !item.ok && item.units.len > 0
		label := if item.be { 'utf-16be' } else { 'utf-16le' }
		decoder := TextDecoder.construct(label, TextDecoderOptions{ fatal: true, ignore_bom: !item.remove_bom })!
		if _ := decoder.decode(hex.decode(item.input_hex)!, TextDecodeOptions{ stream: !item.last }) {
			assert false
		} else {
			assert err.msg() == 'TypeError: Decoding failed'
		}
		assert_text_decoder_utf16_variant_after_call(decoder, item, item.remove_bom)
	}
}

fn test_source_text_decoder_utf16_three_byte_eof_matches_original_ffi_at_each_split() {
	cases := json2.decode[[]TextDecoderUtf16EofSourceSequence](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf16_eof.json')!)!
	assert cases.len == 32
	for item in cases {
		decoder := TextDecoder.construct(item.label, TextDecoderOptions{ fatal: item.fatal, ignore_bom: !item.remove_bom })!
		for step in item.steps {
			if result := decoder.decode(hex.decode(step.input_hex)!, TextDecodeOptions{ stream: !step.last }) {
				assert step.ok
				actual_owned := libjs.utf16_string_from_utf8_without_validation(result)
				assert actual_owned.code_units() == step.units
			} else {
				assert !step.ok && err.msg() == 'TypeError: Decoding failed'
			}
		}
		// Even the fatal EOF path has reset the owner before exposing its
		// error, and the supplied absent-input path remains reusable.
		assert decoder.decode(none, TextDecodeOptions{})! == ''
		assert decoder.utf16_decoder_.variant.lead_byte == none
		assert decoder.utf16_decoder_.variant.lead_surrogate == 0
	}
}

fn test_source_text_decoder_utf16_variant_owner_guard_survives_production() {
	if label := os.getenv_opt('VOX2_TEXT_DECODER_UTF16_VARIANT_COLD') {
		decoder := TextDecoder{ TextDecoderCommonMixin: new_text_decoder_common(label, TextDecoderOptions{}) }
		decoder.decode([], TextDecodeOptions{}) or { panic(err) }
		panic('Source owner guard unexpectedly returned')
	}
	for label in ['utf-16le', 'utf-16be'] {
		mut process := os.new_process(os.executable())
		defer { process.close() }
		mut environment := os.environ()
		environment['VOX2_TEXT_DECODER_UTF16_VARIANT_COLD'] = label
		process.set_environment(environment)
		process.set_redirect_stdio()
		process.run()
		process.wait()
		output := process.stdout_slurp() + process.stderr_slurp()
		assert process.code != 0 && output.contains('Source VERIFY: TextDecoderCommon owns its StreamingDecoder'), output
	}
}
