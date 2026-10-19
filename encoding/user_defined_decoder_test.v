module encoding

import encoding.hex
import json2
import os

pub struct UserDefinedSourceGolden {
pub:
	utf8_hex   string
	code_units []u16
}

pub struct UserDefinedRawSourceGolden {
pub:
	input_hex  string
	capacity   int
	status     string
	read       int
	written    int
	output_hex string
}

fn test_source_user_defined_matches_actual_bridge_all_bytes_and_owned_null_output() {
	gold := json2.decode[UserDefinedSourceGolden](os.read_file('${os.dir(@DIR)}/encoding/fixtures/user_defined_all-bytes.json')!)!
	input := []u8{len: 256, init: u8(index)}
	expected := hex.decode(gold.utf8_hex)!
	assert decode_x_user_defined(input).bytes() == expected
	assert gold.code_units.len == 256
	assert gold.code_units[127] == 127 && gold.code_units[128] == 0xf780
	assert gold.code_units[255] == 0xf7ff
	for fatal in [false, true] {
		for ignore_bom in [false, true] {
			mut decoder := TextDecoder.construct('x-user-defined', TextDecoderOptions{ fatal: fatal, ignore_bom: ignore_bom })!
			assert decoder.decode(input, TextDecodeOptions{})!.bytes() == expected
			assert decoder.decode([u8(0), 0x80, 0, 0xff, 0], TextDecodeOptions{})!.bytes() == [
				u8(0),
				0xef,
				0x9e,
				0x80,
				0,
				0xef,
				0x9f,
				0xbf,
				0,
			]
			assert decoder.decode([], TextDecodeOptions{})! == ''
		}
	}
	mut stream := TextDecoder.construct('x-user-defined', TextDecoderOptions{})!
	first := stream.decode(input[..131], TextDecodeOptions{ stream: true })!
	last := stream.decode(input[131..], TextDecodeOptions{})!
	assert (first + last).bytes() == expected
}

fn test_source_user_defined_macro_control_order_matches_native_raw_capacity_goldens() {
	cases := json2.decode[[]UserDefinedRawSourceGolden](os.read_file('${os.dir(@DIR)}/encoding/fixtures/user_defined_raw-capacities.json')!)!
	assert cases.len == 114
	decoder := UserDefinedDecoder{}
	for item in cases {
		input := hex.decode(item.input_hex)!
		for last in [false, true] {
			mut output := []u8{len: item.capacity}
			result, read, written := decoder.decode_to_utf8_raw(input, mut output, last)
			assert result.status.str() == item.status
			assert read == item.read && written == item.written
			assert result.malformed_length == 0 && result.bytes_after == 0
			assert output[..written] == hex.decode(item.output_hex)!
		}
	}
	mut short := []u8{len: 2}
	result, read, written := decoder.decode_to_utf8_raw('A'.bytes(), mut short, true)
	assert result.status == .output_full && read == 0 && written == 0
}
