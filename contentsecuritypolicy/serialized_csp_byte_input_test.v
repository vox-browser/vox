module contentsecuritypolicy

fn test_source_csp_byte_input_is_isomorphically_decoded_before_parsing() {
	mut serialized := "img-src '".bytes()
	serialized << [u8(0x80), 0xa0, 0xc3, 0xa9, 0xe9, 0xff]
	serialized << "'; SCRIPT-SRC 'self'; script-src 'none'".bytes()
	policy := parse_a_serialized_csp_bytes(serialized, .header, .report)
	assert policy.pre_parsed_policy_string() == "img-src '\u0080\u00a0\u00c3\u00a9\u00e9\u00ff'; SCRIPT-SRC 'self'; script-src 'none'"
	assert policy.directives().len == 1
	assert policy.directives()[0].name() == script_src
	assert policy.directives()[0].value() == ["'self'"]
	assert policy.source() == .header
	assert policy.disposition() == .report
	assert policy.clone().pre_parsed_policy_string() == policy.pre_parsed_policy_string()
}

fn test_source_csp_string_and_byte_inputs_retain_distinct_decoding_semantics() {
	serialized := "unknown \u00e9; default-src 'none'"
	string_policy := parse_a_serialized_csp(serialized, .meta, .enforce)
	byte_policy := Policy.parse_a_serialized_csp_bytes(serialized.bytes(), .header, .enforce)
	assert string_policy.pre_parsed_policy_string() == serialized
	assert byte_policy.pre_parsed_policy_string() == "unknown \u00c3\u00a9; default-src 'none'"
	assert string_policy.directives().len == 1
	assert byte_policy.directives().len == 1
	assert byte_policy.directives()[0].name() == default_src
	assert byte_policy.directives()[0].value() == string_policy.directives()[0].value()
}

fn test_source_csp_ascii_byte_input_preserves_existing_token_rules() {
	serialized := "\t; SCRIPT-SRC\t'self'\nhttps://cdn.test\r\f; script-src 'none'; ; img-src data:;"
	policy := parse_a_serialized_csp_bytes(serialized.bytes(), .header, .enforce)
	assert policy.pre_parsed_policy_string() == serialized
	assert policy.directives().len == 2
	assert policy.directives()[0].name() == script_src
	assert policy.directives()[0].value() == ["'self'", 'https://cdn.test']
	assert policy.directives()[1].name() == img_src
	assert policy.directives()[1].value() == ['data:']
	assert policy.source() == .header
	assert policy.disposition() == .enforce
}
