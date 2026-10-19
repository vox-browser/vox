module encoding

import encoding.hex
import json2
import os

pub struct Windows1252SourceGolden {
pub:
	utf8_hex   string
	code_units []u16
}

pub struct Windows1252RawSourceGolden {
pub:
	input_hex  string
	capacity   int
	status     string
	read       int
	written    int
	output_hex string
}

fn test_source_windows_1252_matches_real_rust_bridge_for_all_bytes_and_fatal_aliases() {
	gold := json2.decode[Windows1252SourceGolden](os.read_file('${os.dir(@DIR)}/encoding/fixtures/windows_1252_all-bytes.json')!)!
	input := []u8{len: 256, init: u8(index)}
	expected := hex.decode(gold.utf8_hex)!
	assert decode_windows_1252_to_utf8(input).bytes() == expected
	for label in ['windows-1252', 'latin1', 'iso-8859-1', 'ascii'] {
		for fatal in [false, true] {
			for ignore_bom in [false, true] {
				mut decoder := TextDecoder.construct(label, TextDecoderOptions{ fatal: fatal, ignore_bom: ignore_bom })!
				assert decoder.decode(input, TextDecodeOptions{})!.bytes() == expected
			}
		}
	}
	assert gold.code_units.len == 256
	assert gold.code_units[0] == 0 && gold.code_units[128] == 0x20ac
	assert gold.code_units[129] == 0x81 && gold.code_units[255] == 0xff
	for label in ['windows-1252', 'latin1', 'iso-8859-1', 'ascii'] {
		assert convert_input_to_utf8_using_given_decoder_unless_there_is_a_byte_order_mark(label, [
			u8(0),
			0x80,
			0,
			255,
			0,
		])!.bytes() == [u8(0), 0xe2, 0x82, 0xac, 0, 0xc3, 0xbf, 0]
	}
}

fn test_source_windows_1252_raw_positions_capacity_and_bytes_match_65_actual_source_cases() {
	cases := json2.decode[[]Windows1252RawSourceGolden](os.read_file('${os.dir(@DIR)}/encoding/fixtures/windows_1252_raw-capacities.json')!)!
	assert cases.len == 65
	decoder := Windows1252Decoder{}
	for item in cases {
		input := hex.decode(item.input_hex)!
		mut output := []u8{len: item.capacity}
		result, read, written := decoder.decode_to_utf8_raw(input, mut output, true)
		assert result.status.str() == item.status
		assert read == item.read && written == item.written
		assert output[..written] == hex.decode(item.output_hex)!
		assert result.malformed_length == 0 && result.bytes_after == 0
	}
}

fn test_source_windows_1252_empty_stream_segments_bom_bytes_and_null_are_length_aware() {
	assert decode_windows_1252_to_utf8(''.bytes()) == ''
	assert decode_windows_1252_to_utf8([u8(0), 0, 0]).bytes() == [u8(0), 0, 0]
	mut decoder := TextDecoder.construct('windows-1252', TextDecoderOptions{ fatal: true })!
	assert decoder.decode([u8(0x80), 0], TextDecodeOptions{ stream: true })!.bytes() == [
		u8(0xe2),
		0x82,
		0xac,
		0,
	]
	assert decoder.decode([u8(255), 0], TextDecodeOptions{})!.bytes() == [u8(0xc3), 0xbf, 0]
	// This direct decoder keeps UTF8-looking bytes in its selected legacy
	// encoding; FileReader's separate BOM override chooses UTF8 beforehand.
	assert decoder.decode([u8(0xef), 0xbb, 0xbf], TextDecodeOptions{})!.bytes() == [
		u8(0xc3),
		0xaf,
		0xc2,
		0xbb,
		0xc2,
		0xbf,
	]
}
