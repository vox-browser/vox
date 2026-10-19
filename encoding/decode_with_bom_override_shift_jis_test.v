module encoding

import encoding.hex
import json2
import os

pub struct ShiftJisGivenDecoderSourceCase {
pub:
	remove_bom bool
	input_hex  string
	utf8_hex   string
	had_errors bool
}

fn test_source_given_decoder_selected_shift_jis_whole_utf8_matches_original_ffi() {
	cases := json2.decode[[]ShiftJisGivenDecoderSourceCase](os.read_file('${os.dir(@DIR)}/encoding/fixtures/shift_jis_whole_input.json')!)!
	assert cases.len == 4140
	mut selected := 0
	mut replacements := 0
	for item in cases {
		input := hex.decode(item.input_hex)!
		// Genuine BOM sniffing replaces the fallback with Unicode. The selected
		// Shift_JIS branch is reachable only for this existing non-BOM span.
		if _ := bom_sniff(input) { continue }
		expected := hex.decode(item.utf8_hex)!
		for label in ['Shift_JIS', 'sjis', 'windows-31j'] {
			assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark(label, input)!.bytes() == expected
		}
		selected++
		if item.had_errors { replacements++ }
	}
	assert selected == 4130 && replacements > 0
}

pub struct ShiftJisFallbackUnicodeWholeSourceCase {
pub:
	be         bool
	remove_bom bool
	input_hex  string
	utf8_hex   string
}

fn test_source_given_shift_jis_fallback_still_yields_to_actual_unicode_bom_decoder() {
	cases := json2.decode[[]ShiftJisFallbackUnicodeWholeSourceCase](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf16_whole_input.json')!)!
	mut checked := 0
	for item in cases {
		if !item.remove_bom { continue }
		mut input := if item.be { [u8(0xfe), 0xff] } else { [u8(0xff), 0xfe] }
		input << hex.decode(item.input_hex)!
		// The first Source sniffed BOM is discarded, then the selected Unicode
		// whole decoder removes one further matching BOM exactly as native FFI.
		assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark('Shift_JIS', input)!.bytes() == hex.decode(item.utf8_hex)!
		checked++
	}
	assert checked == 752
}
