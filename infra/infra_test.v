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
}

fn test_string_algorithms() {
	assert normalize_newlines('a\r\nb\rc') == 'a\nb\nc'
	assert strip_and_collapse_whitespace('\t hello\n\x0cworld \r') == 'hello world'
	assert is_code_unit_prefix('😀', '😀x')
	assert !is_code_unit_prefix('😀x', '😀')
	assert code_unit_less_than('a', '😀')
	assert !code_unit_less_than('😀', 'a')
}

fn test_json_algorithms() {
	value := parse_json_string_to_javascript_value('{"ok":true,"items":[1,2]}') or { panic(err) }
	serialized := serialize_javascript_value_to_json_string(value) or { panic(err) }
	reparsed := parse_json_string_to_javascript_value(serialized) or { panic(err) }
	assert reparsed.as_map()['ok']!.bool()
	assert reparsed.as_map()['items']!.as_array().len == 2
	assert parse_json_bytes_to_javascript_value('null'.bytes()) or { panic(err) } is json2.Null
}
