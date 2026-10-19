module encoding

import encoding.hex
import json2
import os

pub struct Utf8WholeInputSourceCase {
pub:
	input_hex  string
	utf8_hex   string
	had_errors bool
	fatal_ok   bool
}

fn test_source_utf8_whole_input_consumer_matches_actual_bridge_and_withholds_fatal_output() {
	cases := json2.decode[[]Utf8WholeInputSourceCase](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf8_whole_input.json')!)!
	assert cases.len == 903
	for item in cases {
		input := hex.decode(item.input_hex)!
		expected := hex.decode(item.utf8_hex)!
		actual, errors := decode_source_utf8_without_bom_handling(input)
		assert actual.bytes() == expected
		assert errors == item.had_errors
		assert decode_utf8(input, false)!.bytes() == expected
		if fatal_result := decode_utf8(input, true) {
			assert item.fatal_ok
			assert fatal_result.bytes() == expected
		} else {
			assert !item.fatal_ok && err.msg() == 'TypeError: Decoding failed'
		}
		decoder := TextDecoder.construct('utf-8', TextDecoderOptions{ ignore_bom: true })!
		assert decoder.decode(input, TextDecodeOptions{})!.bytes() == expected
	}
}

fn test_source_utf8_whole_consumer_preserves_existing_bom_ownership_and_ascii_reprocessing() {
	assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark('windows-1252', [
		u8(0xef),
		0xbb,
		0xbf,
		0xe1,
		`A`,
	])! == '\ufffdA'
	assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark('utf-8', [
		u8(0xe1),
		0x80,
		`A`,
		0,
	])!.bytes() == [u8(0xef), 0xbf, 0xbd, `A`, 0]
	preserve := TextDecoder.construct('utf-8', TextDecoderOptions{ ignore_bom: true })!
	assert preserve.decode([u8(0xef), 0xbb, 0xbf, `Z`], TextDecodeOptions{})!.bytes() == [
		u8(0xef),
		0xbb,
		0xbf,
		`Z`,
	]
	remove := TextDecoder.create()
	assert remove.decode([u8(0xef), 0xbb, 0xbf, `Z`], TextDecodeOptions{})! == 'Z'
}
