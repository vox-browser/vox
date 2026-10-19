module encoding

import encoding.hex
import json2
import libjs
import os

pub struct TextDecoderUtf16OwnerSourceStep {
pub:
	remove_bom     bool
	input_hex      string
	last           bool
	ok             bool
	units          []u16
	life_cycle     string
	code_point     u32
	bytes_seen     int
	bytes_needed   int
	lower_boundary u8
	upper_boundary u8
	panic          bool
}

pub struct TextDecoderUtf16OwnerSourceSequence {
pub:
	remove_bom bool
	mode       int
	steps      []TextDecoderUtf16OwnerSourceStep
}

fn text_decoder_utf16_owner_life_cycle(name string) Utf8DecoderLifeCycle {
	return match name {
		'AtUtf8Start' { Utf8DecoderLifeCycle.at_utf8_start }
		'SeenUtf8First' { Utf8DecoderLifeCycle.seen_utf8_first }
		'SeenUtf8Second' { Utf8DecoderLifeCycle.seen_utf8_second }
		'Converting' { Utf8DecoderLifeCycle.converting }
		'Finished' { Utf8DecoderLifeCycle.finished }
		else { panic('unexpected actual Source UTF8 life cycle ' + name) }
	}
}

fn assert_text_decoder_utf16_owner_after_call(decoder &TextDecoder, step TextDecoderUtf16OwnerSourceStep, remove_bom bool) {
	assert decoder.utf8_decoder_present_
	assert decoder.pending_input.len == 0 && !decoder.bom_seen
	if step.last {
		assert decoder.utf8_decoder_.life_cycle == if remove_bom {
			Utf8DecoderLifeCycle.at_utf8_start
		} else {
			Utf8DecoderLifeCycle.converting
		}
		assert decoder.utf8_decoder_.variant.code_point == 0
		assert decoder.utf8_decoder_.variant.bytes_seen == 0 && decoder.utf8_decoder_.variant.bytes_needed == 0
		assert decoder.utf8_decoder_.variant.lower_boundary == 0x80 && decoder.utf8_decoder_.variant.upper_boundary == 0xbf
	} else {
		assert decoder.utf8_decoder_.life_cycle == text_decoder_utf16_owner_life_cycle(step.life_cycle)
		assert decoder.utf8_decoder_.variant.code_point == step.code_point
		assert decoder.utf8_decoder_.variant.bytes_seen == step.bytes_seen && decoder.utf8_decoder_.variant.bytes_needed == step.bytes_needed
		assert decoder.utf8_decoder_.variant.lower_boundary == step.lower_boundary && decoder.utf8_decoder_.variant.upper_boundary == step.upper_boundary
	}
}

fn test_source_text_decoder_calls_actual_utf16_owner_and_projects_native_ffi_units() {
	cases := json2.decode[[]TextDecoderUtf16OwnerSourceSequence](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf8_utf16_streaming_sequences.json')!)!
	assert cases.len == 5000
	mut observed_calls := 0
	for item in cases {
		if item.mode < 2 { continue }
		decoder := TextDecoder.construct('utf-8', TextDecoderOptions{ fatal: item.mode == 3, ignore_bom: !item.remove_bom })!
		for step in item.steps {
			// These deliberate post-Finished native owner calls cannot
			// occur through Source TextDecoder, which resets before return.
			if step.panic { break }
			observed_calls++
			if result := decoder.decode(hex.decode(step.input_hex)!, TextDecodeOptions{ stream: !step.last }) {
				assert step.ok
				actual_owned := libjs.utf16_string_from_utf8_without_validation(result)
				assert actual_owned.code_units() == step.units
			} else {
				assert !step.ok && err.msg() == 'TypeError: Decoding failed'
			}
			assert_text_decoder_utf16_owner_after_call(decoder, step, item.remove_bom)
		}
	}
	assert observed_calls == 1876
}

fn test_source_text_decoder_withholds_actual_fatal_partial_utf16_callbacks() {
	cases := json2.decode[[]TextDecoderUtf16OwnerSourceStep](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf8_utf16_partial_callbacks.json')!)!
	assert cases.len == 16
	for item in cases {
		assert !item.ok && item.units.len > 0
		decoder := TextDecoder.construct('utf-8', TextDecoderOptions{ fatal: true, ignore_bom: !item.remove_bom })!
		if _ := decoder.decode(hex.decode(item.input_hex)!, TextDecodeOptions{ stream: !item.last }) {
			assert false
		} else {
			assert err.msg() == 'TypeError: Decoding failed'
		}
		assert_text_decoder_utf16_owner_after_call(decoder, item, item.remove_bom)
		// The earlier native fresh/retained witnesses establish this BOM
		// distinction after an error. Streaming retains consumed start;
		// flushed calls install the configured fresh owner before throwing.
		expected := if item.last && item.remove_bom { 'C\x00' } else { '\ufeffC\x00' }
		assert decoder.decode([u8(0xef), 0xbb, 0xbf, `C`, 0], TextDecodeOptions{})! == expected
	}
}

fn test_source_text_decoder_utf16_owner_guard_survives_production() {
	if os.getenv('VOX2_TEXT_DECODER_UTF16_COLD') == '1' {
		decoder := TextDecoder{ TextDecoderCommonMixin: new_text_decoder_common('utf-8', TextDecoderOptions{}) }
		decoder.decode([], TextDecodeOptions{}) or { panic(err) }
		panic('Source owner guard unexpectedly returned')
	}
	mut process := os.new_process(os.executable())
	defer { process.close() }
	mut environment := os.environ()
	environment['VOX2_TEXT_DECODER_UTF16_COLD'] = '1'
	process.set_environment(environment)
	process.set_redirect_stdio()
	process.run()
	process.wait()
	output := process.stdout_slurp() + process.stderr_slurp()
	assert process.code != 0 && output.contains('Source VERIFY: TextDecoderCommon owns its StreamingDecoder'), output
}
