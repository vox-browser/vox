module html

import dom

fn test_response_csp_string_adapter_preserves_first_duplicate_directive() {
	origin := dom.URL{'https://string-policy.test:8443/page'}.origin()
	policy := parse_response_csp_policy(" SCRIPT-SRC 'self'; script-src 'none'; img-src data:",
		.enforce, origin)
	assert policy.directives.len == 2
	assert policy.directives[0].name == 'script-src'
	assert policy.directives[0].value == ["'self'"]
	assert policy.directives[1].name == 'img-src'
}

fn test_response_csp_string_adapter_uses_all_source_ascii_whitespace() {
	origin := dom.URL{'https://string-policy.test/page'}.origin()
	policy := parse_response_csp_policy('img-src https:\rdata:\fblob:', .enforce, origin)
	assert policy.directives.len == 1
	assert policy.directives[0].value == ['https:', 'data:', 'blob:']
}

fn test_response_csp_string_adapter_ignores_non_ascii_directive_tokens() {
	origin := dom.URL{'https://string-policy.test/page'}.origin()
	policy := parse_response_csp_policy("\u00a0img-src data:; unknown \u00e9; script-src 'self'",
		.enforce, origin)
	assert policy.directives.len == 1
	assert policy.directives[0].name == 'script-src'
}

fn test_response_csp_string_adapter_retains_its_supplied_actual_origin_and_text() {
	origin := dom.origin_create_opaque_file()
	input := " script-src 'self' ; unknown \u00e9"
	policy := parse_response_csp_policy(input, .report, origin)
	assert policy.self_origin.is_same_origin(origin)
	assert policy.self_origin.is_opaque_file_origin()
	assert policy.self_origin.liburl_origin()?.opaque_data()?.nonce == origin.liburl_origin()?.opaque_data()?.nonce
	assert policy.pre_parsed_policy_string == input
	assert policy.disposition == .report
	assert policy.source == .header
}
