module encoding

import encoding.hex
import json2
import os

pub struct SingleByteSourceGolden {
pub:
	label           string
	utf8_hex        string
	undefined_bytes []u8
}

pub struct SingleByteRawSourceGolden {
pub:
	label            string
	input_hex        string
	capacity         int
	replacement      bool
	status           string
	read             int
	written          int
	malformed_length int
	bytes_after      int
	had_errors       bool
	output_hex       string
}

fn test_source_all_27_single_byte_tables_match_native_bridge_bytes_and_fatal_outcomes() {
	cases := json2.decode[[]SingleByteSourceGolden](os.read_file('${os.dir(@DIR)}/encoding/fixtures/single_byte_all-bytes.json')!)!
	assert cases.len == 28 // ISO8859-8-I uses the same actual table as ISO8859-8.
	input := []u8{len: 256, init: u8(index)}
	for item in cases {
		expected := hex.decode(item.utf8_hex)!
		for ignore_bom in [false, true] {
			mut decoder := TextDecoder.construct(item.label, TextDecoderOptions{ ignore_bom: ignore_bom })!
			assert decoder.decode(input, TextDecodeOptions{})!.bytes() == expected
		}
		for byte in 128 .. 256 {
			mut fatal := TextDecoder.construct(item.label, TextDecoderOptions{ fatal: true })!
			if actual := fatal.decode([u8(byte)], TextDecodeOptions{}) {
				assert u8(byte) !in item.undefined_bytes
				assert actual != ''
			} else {
				assert u8(byte) in item.undefined_bytes
				assert err.msg() == 'TypeError: Decoding failed'
			}
		}
		mut fatal := TextDecoder.construct(item.label, TextDecoderOptions{ fatal: true })!
		if actual := fatal.decode(input, TextDecodeOptions{}) {
			assert item.undefined_bytes.len == 0
			assert actual.bytes() == expected
		} else {
			assert item.undefined_bytes.len > 0
			assert err.msg() == 'TypeError: Decoding failed'
		}
		mut stream := TextDecoder.construct(item.label, TextDecoderOptions{})!
		prefix := stream.decode(input[..128], TextDecodeOptions{ stream: true })!
		suffix := stream.decode(input[128..], TextDecodeOptions{})!
		assert (prefix + suffix).bytes() == expected
		assert stream.decode([u8(0), 0x41, 0], TextDecodeOptions{})!.bytes() == [
			u8(0),
			0x41,
			0,
		]
		assert stream.decode([], TextDecodeOptions{})! == ''
	}
	assert source_single_byte_table('iso-8859-8-i')? == source_single_byte_table('iso-8859-8')?
	assert source_single_byte_table('shift_jis') == none
}

fn test_source_single_byte_raw_and_replacement_loop_match_all_native_capacity_records() {
	cases := json2.decode[[]SingleByteRawSourceGolden](os.read_file('${os.dir(@DIR)}/encoding/fixtures/single_byte_raw-capacities.json')!)!
	assert cases.len == 7540
	mut malformed_cases := 0
	mut replacement_error_cases := 0
	for item in cases {
		table := source_single_byte_table(encoding_ascii_lowercase(item.label))?
		assert table.len == 128
		decoder := SourceSingleByteDecoder{ table: table }
		input := hex.decode(item.input_hex)!
		mut output := []u8{len: item.capacity}
		if item.replacement {
			result, read, written, had_errors := decoder.decode_to_utf8(input, mut output, true)
			assert result.status.str() == item.status
			assert read == item.read && written == item.written
			assert had_errors == item.had_errors
			assert output[..written] == hex.decode(item.output_hex)!
			if had_errors {
				replacement_error_cases++
			}
		} else {
			result, read, written := decoder.decode_to_utf8_raw(input, mut output, true)
			assert result.status.str() == item.status
			assert read == item.read && written == item.written
			assert result.malformed_length == item.malformed_length
			assert result.bytes_after == item.bytes_after
			assert output[..written] == hex.decode(item.output_hex)!
			if result.status == .malformed {
				malformed_cases++
			}
		}
	}
	assert malformed_cases > 0 && replacement_error_cases > 0
}
