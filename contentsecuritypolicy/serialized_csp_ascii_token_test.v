module contentsecuritypolicy

fn test_source_csp_ascii_whitespace_does_not_discard_a_directive() {
	policy := parse_a_serialized_csp(" SCRIPT-SRC\t'self'\nhttps://cdn.test\rhttps://other.test\fdata: ; script-src 'none'",
		.header, .enforce)
	assert policy.directives().len == 1
	assert policy.directives()[0].name() == script_src
	assert policy.directives()[0].value() == ["'self'", 'https://cdn.test', 'https://other.test',
		'data:']
}

fn test_source_csp_carriage_return_and_form_feed_are_value_separators() {
	policy := parse_a_serialized_csp('img-src https:\rdata:\fblob:', .meta, .report)
	assert policy.directives().len == 1
	assert policy.directives()[0].value() == ['https:', 'data:', 'blob:']
}

fn test_source_csp_ascii_controls_are_preserved_without_becoming_whitespace() {
	policy := parse_a_serialized_csp('unknown a\x00b\x0bc\x7fd; img-src data:', .header, .enforce)
	assert policy.directives().len == 2
	assert policy.directives()[0].name() == 'unknown'
	assert policy.directives()[0].value() == ['a\x00b\x0bc\x7fd']
	assert policy.directives()[1].name() == img_src
}

fn test_source_csp_non_ascii_tokens_remain_ignored() {
	policy := parse_a_serialized_csp("unknown \u0080; script-src 'self'; unknown \u00a0; script-src 'none'",
		.header, .enforce)
	assert policy.directives().len == 1
	assert policy.directives()[0].name() == script_src
	assert policy.directives()[0].value() == ["'self'"]
}
