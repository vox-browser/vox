module contentsecuritypolicy

import url

fn csp_url(scheme string, host string, paths []string) url.URL {
	return url.URL{
		scheme: scheme
		host:   url.Host.from_string(host)
		paths:  paths
	}
}

fn csp_fixture(serialized string, disposition Disposition) (&Policy, &PolicyList, GlobalContext) {
	mut policy := parse_a_serialized_csp(serialized, .header, disposition)
	policy.set_self_origin(url.Origin.tuple('https', url.Host.from_string('example.test'), none,
		none))
	list := PolicyList.create([policy])
	global := GlobalContext{
		url:         csp_url('https', 'example.test', ['page'])
		policy_list: list
	}
	return policy, list, global
}

fn test_request_response_blocking_and_reporting() {
	_, list, fixture := csp_fixture("default-src 'self'; report-uri /csp", .enforce)
	mut global := fixture
	mut request := new_request(csp_url('https', 'evil.test', ['image.png']))
	request.destination = .image
	request.policy_list = list
	assert should_request_be_blocked_by_content_security_policy(mut global, request) == .blocked
	assert global.reports.len == 1
	assert global.events.len == 1
	assert global.report_requests.len == 1
	assert global.reports[0].blocked_uri == 'https://evil.test/image.png'
	assert global.report_requests[0].endpoint == 'https://example.test/csp'
	response := Response{
		url: csp_url('https', 'evil.test', ['response.png'])
	}
	assert should_response_to_request_be_blocked_by_content_security_policy(mut global, response,
		request) == .blocked
	assert global.reports.len == 2
}

fn test_report_only_does_not_block() {
	_, list, fixture := csp_fixture("img-src 'none'", .report)
	mut global := fixture
	mut request := new_request(csp_url('https', 'example.test', ['image.png']))
	request.destination = .image
	request.policy_list = list
	assert should_request_be_blocked_by_content_security_policy(mut global, request) == .allowed
	report_content_security_policy_violations_for_request(mut global, request)
	assert global.reports.len == 1
	assert global.reports[0].disposition == .report
}

fn test_violation_accessors_and_disposition_conversion() {
	policy, _, fixture := csp_fixture("default-src 'none'", .report)
	mut violation := Violation.create_a_violation_object_for_global_policy_and_directive(fixture,
		policy, default_src)
	violation.set_status(418)
	violation.set_resource(ViolationResource(ViolationResourceKind.inline))
	violation.set_source_file(csp_url('https', 'example.test', ['script.js']))
	violation.set_line_number(7)
	violation.set_column_number(3)
	violation.set_element(ElementContext{ is_script: true })
	violation.set_sample('sample')
	assert violation.status() == 418
	assert violation.referrer() == fixture.referrer
	assert violation.policy() == policy
	assert violation.disposition() == .report
	assert violation.effective_directive() == default_src
	assert violation.source_file() != none
	assert violation.line_number() == 7
	assert violation.column_number() == 3
	assert violation.element() != none
	assert violation.sample() == 'sample'
	assert original_disposition_to_string(.report) == 'report'
	assert original_disposition_to_bindings_disposition(.enforce) == .enforce
}

fn test_navigation_inline_eval_wasm_and_base_checks() {
	_, list, fixture := csp_fixture("form-action 'none'; script-src 'none' 'report-sample'; style-src 'none'; base-uri 'self'",
		.enforce)
	mut global := fixture
	mut navigation := new_request(csp_url('https', 'evil.test', ['submit']))
	navigation.policy_list = list
	assert should_navigation_request_of_type_be_blocked_by_content_security_policy(mut global,
		navigation, .form_submission) == .blocked
	element := ElementContext{
		is_script: true
	}
	source := '0123456789012345678901234567890123456789extra'
	assert should_elements_inline_type_behavior_be_blocked_by_content_security_policy(mut global,
		element, .script, source) == .blocked
	assert global.reports[global.reports.len - 1].sample.runes().len == 40
	if _ := ensure_csp_does_not_block_string_compilation(mut global, CompilationInput{
		code_string: source
		type_:       .eval
	})
	{
		assert false
	}
	if _ := ensure_csp_does_not_block_wasm_byte_compilation(mut global) {
		assert false
	}
	assert is_base_allowed_for_document(mut global, csp_url('https', 'evil.test', [])) == .blocked
}

fn test_integrity_policy_and_navigation_response() {
	request := Request{
		url:              csp_url('https', 'cdn.test', ['x.js'])
		current_url:      csp_url('https', 'cdn.test', ['x.js'])
		destination:      .script
		mode:             .no_cors
		integrity_policy: IntegrityPolicy{
			sources:              ['inline']
			blocked_destinations: [.script]
		}
	}
	assert should_request_be_blocked_by_integrity_policy(request) == .blocked
	mut with_metadata := request
	with_metadata.integrity_metadata = 'sha256-abc'
	with_metadata.mode = .cors
	assert should_request_be_blocked_by_integrity_policy(with_metadata) == .allowed
	policy, _, fixture := csp_fixture("frame-ancestors 'self'", .enforce)
	response_list := PolicyList.create([policy])
	mut global := fixture
	response := Response{
		url: csp_url('https', 'child.test', [])
	}
	foreign := url.Origin.tuple('https', url.Host.from_string('foreign.test'), none, none)
	assert should_navigation_response_to_navigation_request_of_type_in_target_be_blocked_by_content_security_policy(mut global,
		&with_metadata, response, response_list, .other, NavigableContext{
		ancestor_origins: [
			foreign,
		]
	}) == .blocked
}
