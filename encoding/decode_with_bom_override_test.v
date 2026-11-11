module encoding

import encoding.hex
import json2
import os

fn test_source_bom_override_selects_utf8_utf16_and_keeps_fallback_replacement_behavior() {
	assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark('UTF-8', 'héllo'.bytes())! == 'héllo'
	assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark('UTF-8', [
		u8(0xFF),
		0x61,
	])! == '\ufffda'
	assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark('UTF-16LE', [
		u8(0x61),
		0,
	])! == 'a'
	assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark('UTF-16LE', [
		u8(0xEF),
		0xBB,
		0xBF,
		0x61,
	])! == 'a'
	assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark('UTF-8', [
		u8(0xFF),
		0xFE,
		0x61,
		0,
	])! == 'a'
	assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark('UTF-8', [
		u8(0xFE),
		0xFF,
		0,
		0x61,
	])! == 'a'
	assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark('UTF-8', [
		u8(0xFE),
		0xFF,
		0xD8,
		0,
		0x61,
	])! == '\ufffd'
}

fn test_bom_override_removes_only_the_sniffed_bom_and_preserves_remaining_content() {
	for bom in [[u8(0xEF), 0xBB, 0xBF], [u8(0xFF), 0xFE], [u8(0xFE), 0xFF]] {
		mut two := bom.clone()
		two << bom
		assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark('UTF-8', two)! == '\ufeff'
		mut three := two.clone()
		three << bom
		assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark('UTF-8', three)! == '\ufeff\ufeff'
	}
	assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark('UTF-8', [
		u8(0xFF),
		0xFE,
		0xFE,
		0xFF,
	])! == '\ufffe'
	assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark('UTF-8', [
		u8(0xFE),
		0xFF,
		0xFF,
		0xFE,
	])! == '\ufffe'
}

pub struct BomOverrideUtf16NativeSourceCase {
pub:
	label      string
	input_hex  string
	remove_bom bool
	fatal      bool
	ok         bool
	utf8_hex   string
}

fn test_source_bom_override_utf16_odd_byte_eof_matches_original_utf8_ffi() {
	cases := json2.decode[[]BomOverrideUtf16NativeSourceCase](os.read_file('${os.dir(@DIR)}/encoding/fixtures/post_sniff_utf16_utf8.json')!)!
	assert cases.len == 8
	mut observed := 0
	for item in cases {
		// The actual given-decoder helper invokes IgnoreBOM::Yes/Replacement
		// after discarding the selected BOM. Other original-FFI flags remain
		// recorded independently by the native probe.
		if item.remove_bom || item.fatal { continue }
		assert item.ok
		mut input := if item.label == 'UTF-16BE' {
			[u8(0xfe), 0xff]
		} else {
			[u8(0xff), 0xfe]
		}
		input << hex.decode(item.input_hex)!
		expected := hex.decode(item.utf8_hex)!.bytestr()
		assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark('UTF-8', input)! == expected
		observed++
	}
	assert observed == 2
}

pub struct BomOverrideWholeUtf16SourceCase {
pub:
	be         bool
	remove_bom bool
	input_hex  string
	utf8_hex   string
}

fn test_selected_utf16_bom_override_reaches_actual_source_whole_utf8_owner() {
	cases := json2.decode[[]BomOverrideWholeUtf16SourceCase](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf16_whole_input.json')!)!
	assert cases.len == 1504
	mut checked := 0
	for item in cases {
		if item.remove_bom { continue }
		mut input := if item.be { [u8(0xfe), 0xff] } else { [u8(0xff), 0xfe] }
		input << hex.decode(item.input_hex)!
		expected := hex.decode(item.utf8_hex)!
		// The prepended BOM is consumed by Source sniffing. The original
		// whole-input FFI golden then witnesses exactly the remaining
		// selected UTF16 call with further BOM removal disabled.
		for fallback in ['UTF-8', 'replacement', 'UTF-16LE', 'UTF-16BE'] {
			assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark(fallback, input)!.bytes() == expected
		}
		checked++
	}
	assert checked == 752
}
