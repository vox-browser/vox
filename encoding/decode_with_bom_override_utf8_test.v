module encoding

import encoding.hex
import json2
import os

pub struct Utf8GivenWholeSourceCase {
pub:
	remove_bom bool
	input_hex  string
	utf8_hex   string
	fatal_ok   bool
}

fn utf8_given_whole_source_cases() ![]Utf8GivenWholeSourceCase {
	return json2.decode[[]Utf8GivenWholeSourceCase](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf8_whole_owner.json')!)!
}

fn test_source_utf8_whole_matching_bom_flags_and_fatal_withholding_match_original_ffi() {
	cases := utf8_given_whole_source_cases()!
	assert cases.len == 2170
	for item in cases {
		input := hex.decode(item.input_hex)!
		expected := hex.decode(item.utf8_hex)!
		assert decode_source_utf8_whole_to_utf8(input, item.remove_bom, false)!.bytes() == expected
		if fatal := decode_source_utf8_whole_to_utf8(input, item.remove_bom, true) {
			assert item.fatal_ok && fatal.bytes() == expected
		} else {
			assert !item.fatal_ok && err.msg() == 'TypeError: Decoding failed'
		}
	}
}

fn test_source_given_utf8_decoder_whole_output_preserves_selected_non_bom_span() {
	cases := utf8_given_whole_source_cases()!
	mut checked := 0
	for item in cases {
		if !item.remove_bom { continue }
		input := hex.decode(item.input_hex)!
		if _ := bom_sniff(input) { continue }
		for label in ['UTF-8', 'utf8', 'unicode11utf8'] {
			assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark(label, input)!.bytes() == hex.decode(item.utf8_hex)!
		}
		checked++
	}
	assert checked == 1082
}

fn test_source_sniffed_utf8_bom_selects_whole_owner_then_removes_one_more_matching_bom() {
	cases := utf8_given_whole_source_cases()!
	mut checked := 0
	for item in cases {
		if !item.remove_bom { continue }
		mut input := [u8(0xef), 0xbb, 0xbf]
		input << hex.decode(item.input_hex)!
		// The first sniffed BOM selects UTF8 over the fallback. The remaining
		// span is exactly the native whole FFI case with its removal flag.
		for fallback in ['UTF-8', 'Shift_JIS', 'windows-1252'] {
			assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark(fallback, input)!.bytes() == hex.decode(item.utf8_hex)!
		}
		checked++
	}
	assert checked == 1085
}
