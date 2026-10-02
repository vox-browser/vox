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
	assert strip_and_collapse_whitespace('\t hello\n\fworld \r') == 'hello world'
	assert is_code_unit_prefix('😀', '😀x')
	assert !is_code_unit_prefix('😀x', '😀')
	assert code_unit_less_than('a', '😀')
	assert !code_unit_less_than('😀', 'a')
	// UTF-16 compares the leading surrogate D800 before E000, even though the
	// scalar value U+10000 is numerically greater than U+E000.
	assert code_unit_less_than('𐀀', '')
	assert normalize_newlines('\r\r\n') == '\n\n'
	assert strip_and_collapse_whitespace('  café\t世界  ') == 'café 世界'
}

fn test_json_algorithms() {
	value := parse_json_string_to_javascript_value('{"ok":true,"items":[1,2]}') or { panic(err) }
	serialized := serialize_javascript_value_to_json_string(value) or { panic(err) }
	reparsed := parse_json_string_to_javascript_value(serialized) or { panic(err) }
	compatible := convert_an_infra_value_to_a_json_compatible_javascript_value(value)
	assert compatible.json_str() == serialized
	assert reparsed.as_map()['ok']!.bool()
	assert reparsed.as_map()['items']!.as_array().len == 2
	assert parse_json_bytes_to_javascript_value('null'.bytes()) or { panic(err) } is json2.Null
	assert serialize_javascript_value_to_json_bytes(value)!.bytestr() == serialized
	// UTF-8 decode replaces the malformed byte inside the JSON string.
	replacement := parse_json_bytes_to_javascript_value([u8(`"`), 0xff, u8(`"`)])!
	assert replacement.str() == '�'
}

fn test_scalar_value_and_character_types() {
	assert is_ascii_whitespace(u32(`\x0c`))
	assert !is_ascii_whitespace(0x00a0)
	assert convert_to_scalar_value_string('valid 😀') == 'valid 😀'
	assert ascii_whitespace_code_points == [u32(9), 10, 12, 13, 32]!
}

fn test_scalar_conversion_retains_pairs_and_replaces_each_lone_utf16_unit_once() {
	assert convert_utf16_to_scalar_value_string([u16(0xd800)]) == '�'
	assert convert_utf16_to_scalar_value_string([u16(0xdc00)]) == '�'
	assert convert_utf16_to_scalar_value_string([u16(0xd83d), 0xde00]) == '😀'
	assert convert_utf16_to_scalar_value_string([u16(0xd800), 0xd800, 0x61, 0xdc00]) == '��a�'
	assert convert_to_scalar_value_string([u8(0xed), 0xa0, 0x80].bytestr()) == '�'
	assert convert_to_scalar_value_string([u8(0xed), 0xa0, 0xbd, 0xed, 0xb8, 0x80].bytestr()) == '😀'
	assert convert_to_scalar_value_string('A😀Z') == 'A😀Z'
	assert code_unit_less_than([u8(0xed), 0xa0, 0x80].bytestr(), [u8(0xed), 0xb0, 0x80].bytestr())
	assert is_code_unit_prefix([u8(0xed), 0xa0, 0x80].bytestr(), [u8(0xed), 0xa0, 0x80, 0x61].bytestr())
}

fn test_unsigned_128_bit_integer_preserves_both_limbs() {
	maximum := Unsigned128BitInteger{
		high: u64(0xffff_ffff_ffff_ffff)
		low: u64(0xffff_ffff_ffff_ffff)
	}
	assert maximum.high == u64(0xffff_ffff_ffff_ffff)
	assert maximum.low == u64(0xffff_ffff_ffff_ffff)
}

fn test_serialized_url_ascii_helpers() {
	assert utf16_string_from_url_ascii('xn--fa-hia.de') == 'xn--fa-hia.de'
	assert utf16_string_from_url_ascii_with_prefix(u8(`/`), 'path') == '/path'
	assert utf16_string_from_url_ascii_host_and_port('[2001:db8::1]', u16(8443)) ==
		'[2001:db8::1]:8443'
}
