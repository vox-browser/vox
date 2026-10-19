module encoding

import encoding.hex
import json2
import libjs
import os

pub struct ShiftJisTextDecoderSourceState {
pub:
	has_lead   bool
	lead       u8
	life_cycle string
}

pub struct ShiftJisTextDecoderSourceStep {
pub:
	input_hex        string
	stream           bool
	capacity         int
	ok               bool
	callback_present bool
	units            []u16
	before_reset     ShiftJisTextDecoderSourceState
	after_reset      ShiftJisTextDecoderSourceState
}

pub struct ShiftJisTextDecoderSourceSequence {
pub:
	remove_bom bool
	fatal      bool
	pattern    int
	steps      []ShiftJisTextDecoderSourceStep
}

fn assert_shift_jis_text_decoder_actual_state(decoder &TextDecoder, state ShiftJisTextDecoderSourceState) {
	assert decoder.shift_jis_decoder_present_
	assert decoder.shift_jis_decoder_.life_cycle.str() == state.life_cycle.to_lower()
	if lead := decoder.shift_jis_decoder_.variant.lead {
		assert state.has_lead && lead == state.lead
	} else {
		assert !state.has_lead
	}
	assert decoder.pending_input.len == 0 && !decoder.bom_seen
}

fn test_source_text_decoder_shift_jis_direct_utf16_owner_matches_original_ffi_and_caller_schedules() {
	cases := json2.decode[[]ShiftJisTextDecoderSourceSequence](os.read_file('${os.dir(@DIR)}/encoding/fixtures/text_decoder_shift_jis_schedules.json')!)!
	assert cases.len == 852
	mut checked := 0
	mut failed_partial := 0
	for item in cases {
		decoder := TextDecoder.construct('Shift_JIS', TextDecoderOptions{ fatal: item.fatal, ignore_bom: !item.remove_bom })!
		assert decoder.encoding() == 'shift_jis' && decoder.fatal() == item.fatal && decoder.ignore_bom() == !item.remove_bom
		assert decoder.shift_jis_decoder_present_
		for index, step in item.steps {
			input := hex.decode(step.input_hex)!
			assert decoder.shift_jis_decoder_.max_utf16_buffer_length(u64(input.len))? == u64(step.capacity)
			// The actual ReadonlyBytes overload selects an empty span for absent
			// input. Exercise absence and explicitly supplied emptiness equally.
			supplied := if input.len == 0 && index % 2 == 0 { ?[]u8(none) } else { ?[]u8(input) }
			if decoded := decoder.decode(supplied, TextDecodeOptions{ stream: step.stream }) {
				assert step.ok
				assert libjs.utf16_string_from_utf8_without_validation(decoded).code_units() == step.units
			} else {
				assert !step.ok && item.fatal
				assert err.msg() == 'TypeError: Decoding failed'
				if step.units.len > 0 { failed_partial++ }
			}
			assert step.callback_present == (step.units.len > 0)
			assert_shift_jis_text_decoder_actual_state(decoder, step.after_reset)
			if step.stream {
				assert step.before_reset == step.after_reset
			} else {
				// Source replaces a flushed owner before exposing success or error.
				assert step.after_reset.life_cycle == 'Converting' && !step.after_reset.has_lead
			}
			checked++
		}
	}
	assert checked == 3124 && failed_partial > 0
}

fn test_source_text_decoder_shift_jis_requires_actual_owner_before_direct_destination_in_production() {
	if _ := os.getenv_opt('VOX2_SHIFT_JIS_TEXT_DECODER_UNINITIALIZED') {
		decoder := TextDecoder{ TextDecoderCommonMixin: new_text_decoder_common('shift_jis', TextDecoderOptions{}) }
		decoder.decode([u8(0x82)], TextDecodeOptions{}) or { panic(err) }
		panic('Source missing TextDecoder owner boundary unexpectedly returned')
	}
	mut process := os.new_process(os.executable())
	defer { process.close() }
	mut environment := os.environ()
	environment['VOX2_SHIFT_JIS_TEXT_DECODER_UNINITIALIZED'] = 'yes'
	process.set_environment(environment)
	process.set_redirect_stdio()
	process.run()
	process.wait()
	output := process.stdout_slurp() + process.stderr_slurp()
	assert process.code != 0 && output.contains('Source VERIFY: TextDecoderCommon owns its StreamingDecoder'), output
}
