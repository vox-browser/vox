module encoding

import encoding.hex
import json2
import libjs
import os

pub struct TextDecoderUtf16ResetSourceStep {
pub:
	input_hex string
	last      bool
	ok        bool
	units     []u16
}

pub struct TextDecoderUtf16ResetSourceCase {
pub:
	remove_bom bool
	fatal      bool
	steps      []TextDecoderUtf16ResetSourceStep
}

fn test_source_nonstreaming_error_resets_before_return_and_matches_real_utf16_bridge_units() {
	cases := json2.decode[[]TextDecoderUtf16ResetSourceCase](os.read_file('${os.dir(@DIR)}/encoding/fixtures/text_decoder_utf16_reset.json')!)!
	assert cases.len == 16
	for item in cases {
		decoder := TextDecoder.construct('utf-8', TextDecoderOptions{ fatal: item.fatal, ignore_bom: !item.remove_bom })!
		for step in item.steps {
			input := hex.decode(step.input_hex)!
			if value := decoder.decode(input, TextDecodeOptions{ stream: !step.last }) {
				assert step.ok
				owned_units := libjs.utf16_string_from_utf8_without_validation(value)
				assert owned_units.code_units() == step.units
			} else {
				assert !step.ok && err.msg() == 'TypeError: Decoding failed'
			}
			if step.last {
				assert decoder.utf8_decoder_.life_cycle == if item.remove_bom {
					Utf8DecoderLifeCycle.at_utf8_start
				} else {
					Utf8DecoderLifeCycle.converting
				}
				assert decoder.utf8_decoder_.variant.code_point == 0
				assert decoder.utf8_decoder_.variant.bytes_seen == 0 && decoder.utf8_decoder_.variant.bytes_needed == 0
				assert decoder.utf8_decoder_.variant.lower_boundary == 0x80 && decoder.utf8_decoder_.variant.upper_boundary == 0xbf
			}
		}
	}
}

fn test_source_streaming_error_retains_owner_until_explicit_nonstreaming_reset() {
	decoder := TextDecoder.construct('utf-8', TextDecoderOptions{ fatal: true })!
	assert decoder.decode([u8(0xef), 0xbb, 0xbf, `A`], TextDecodeOptions{ stream: true })! == 'A'
	if _ := decoder.decode([u8(0xff)], TextDecodeOptions{ stream: true }) {
		assert false
	} else {
		assert err.msg() == 'TypeError: Decoding failed'
	}
	assert decoder.utf8_decoder_.life_cycle == .converting
	// Source streaming errors retain the prior consumed-BOM state.
	assert decoder.decode([u8(0xef), 0xbb, 0xbf, `B`], TextDecodeOptions{ stream: true })! == '\ufeffB'
	assert decoder.decode(none, TextDecodeOptions{})! == ''
	assert decoder.utf8_decoder_.life_cycle == .at_utf8_start
	assert decoder.decode([u8(0xef), 0xbb, 0xbf, `C`], TextDecodeOptions{})! == 'C'
}
