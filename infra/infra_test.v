module infra

import x.json2

fn test_byte_sequence_algorithms() {
	mut lower := 'AbC-09'.bytes()
	byte_lowercase(mut lower)
	assert lower.bytestr() == 'abc-09'
	byte_uppercase(mut lower)
	assert lower.bytestr() == 'ABC-09'
	assert is_prefix_of('ab'.bytes(), 'abc'.bytes())
	assert !is_prefix_of('abcd'.bytes(), 'abc'.bytes())
	assert is_byte_less_than('ab'.bytes(), 'abc'.bytes())
	assert is_byte_less_than('abc'.bytes(), 'abd'.bytes())
	assert !is_byte_less_than('abd'.bytes(), 'abc'.bytes())
	assert !is_byte_less_than('abc'.bytes(), 'abc'.bytes())
	assert is_prefix_of([]u8{}, 'abc'.bytes())
}

fn test_string_algorithms() {
	assert normalize_newlines('a\r\nb\rc') == 'a\nb\nc'
	assert strip_and_collapse_whitespace('\t hello\n\x0cworld \r') == 'hello world'
	assert is_code_unit_prefix('😀', '😀x')
	assert !is_code_unit_prefix('😀x', '😀')
	assert code_unit_less_than('a', '😀')
	assert !code_unit_less_than('😀', 'a')
	// UTF-16 compares the leading surrogate D800 before E000, even though the
	// scalar value U+10000 is numerically greater than U+E000.
	assert code_unit_less_than('\U00010000', '\ue000')
	assert normalize_newlines('\r\r\n') == '\n\n'
	assert strip_and_collapse_whitespace('  café\t世界  ') == 'café 世界'
}

fn test_json_algorithms() {
	value := parse_json_string_to_javascript_value('{"ok":true,"items":[1,2]}') or { panic(err) }
	serialized := serialize_javascript_value_to_json_string(value) or { panic(err) }
	reparsed := parse_json_string_to_javascript_value(serialized) or { panic(err) }
	assert reparsed.as_map()['ok']!.bool()
	assert reparsed.as_map()['items']!.as_array().len == 2
	assert parse_json_bytes_to_javascript_value('null'.bytes()) or { panic(err) } is json2.Null
	assert serialize_javascript_value_to_json_bytes(value)!.bytestr() == serialized
	// UTF-8 decode replaces the malformed byte inside the JSON string.
	replacement := parse_json_bytes_to_javascript_value([u8(`"`), 0xff, u8(`"`)])!
	assert replacement.str() == '\ufffd'
}

fn test_scalar_value_and_character_types() {
	assert is_ascii_whitespace(`\x0c`)
	assert !is_ascii_whitespace(0x00a0)
	assert convert_to_scalar_value_string('valid 😀') == 'valid 😀'
	assert ascii_whitespace_code_points == [u32(9), 10, 12, 13, 32]
}

fn test_unsigned_128_bit_integer_preserves_both_limbs() {
	maximum := Unsigned128BitInteger{
		high: u64(0xffff_ffff_ffff_ffff)
		low:  u64(0xffff_ffff_ffff_ffff)
	}
	assert maximum.high == u64(0xffff_ffff_ffff_ffff)
	assert maximum.low == u64(0xffff_ffff_ffff_ffff)
}
