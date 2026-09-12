module contentsecuritypolicy

import url

fn test_policy_parser_duplicate_case_and_clone() {
	mut policy := parse_a_serialized_csp(" SCRIPT-SRC 'self' https://cdn.test ; img-src data:; script-src 'none'; ; \u0100bad x",
		.header, .enforce)
	assert policy.directives().len == 2
	assert policy.directives()[0].name() == script_src
	assert policy.directives()[0].value() == ["'self'", 'https://cdn.test']
	assert policy.directives()[0].kind == .script_source
	assert policy.directives()[1].kind == .image_source
	assert policy.contains_directive_with_name(img_src)
	policy.set_self_origin(url.Origin.tuple('https', url.Host.from_string('example.test'), none,
		none))
	cloned := policy.clone()
	policy.remove_directive(img_src)
	assert policy.directives().len == 1
	assert cloned.directives().len == 2
	assert cloned.pre_parsed_policy_string() == policy.pre_parsed_policy_string()
}

fn test_factory_maps_all_known_directives() {
	names := [base_uri, child_src, connect_src, default_src, font_src, form_action, frame_ancestors,
		frame_src, img_src, manifest_src, media_src, object_src, report_to, report_uri,
		require_trusted_types_for, sandbox, script_src, script_src_elem, script_src_attr, style_src,
		style_src_elem, style_src_attr, trusted_types, webrtc, worker_src]
	for name in names {
		assert create_directive(name, []).kind != .unknown
	}
	assert create_directive('future-src', ['x']).kind == .unknown
}

fn test_fallback_execution_and_effective_directives() {
	policy := parse_a_serialized_csp("script-src 'self'; default-src 'none'", .header, .enforce)
	assert get_fetch_directive_fallback_list(script_src_elem) == [script_src_elem, script_src,
		default_src]
	assert should_fetch_directive_execute(script_src_elem, script_src_elem, policy) == .yes
	assert should_fetch_directive_execute(script_src_elem, script_src, policy) == .yes
	assert should_fetch_directive_execute(script_src_elem, default_src, policy) == .no
	mut request := new_request(url.URL{})
	request.destination = .worker
	assert (get_the_effective_directive_for_request(request) or { '' }) == worker_src
	request.destination = .document
	assert get_the_effective_directive_for_request(request) == none
	request.initiator = .prefetch
	assert (get_the_effective_directive_for_request(request) or { '' }) == default_src
	assert get_the_effective_directive_for_inline_checks(.style_attribute) == style_src_attr
}

fn test_policy_list_header_and_sandbox_algorithms() {
	mut enforce := parse_a_serialized_csp('sandbox allow-scripts allow-same-origin', .header,
		.enforce)
	enforce.set_self_origin(url.Origin.tuple('https', url.Host.from_string('a.test'), none, none))
	report := parse_a_serialized_csp('sandbox', .meta, .report)
	list := PolicyList.create([enforce, report])
	assert list.contains_header_delivered_policy()
	flags := list.csp_derived_sandboxing_flags()
	assert !flags.contains(.sandboxed_scripts)
	assert !flags.contains(.sandboxed_origin)
	directive := enforce.get_directive_by_name(sandbox) or { panic('sandbox') }
	assert directive.initialization(true, enforce) == .allowed
}

fn test_response_policy_parsing() {
	response := Response{
		url:     url.URL{
			scheme: 'https'
			host:   url.Host.from_string('example.test')
		}
		headers: {
			'Content-Security-Policy':             ["default-src 'self'"]
			'content-security-policy-report-only': ['img-src https:']
		}
	}
	list := parse_a_responses_content_security_policies(response)
	assert list.policies.len == 2
	assert list.policies[0].disposition() == .enforce
	assert list.policies[1].disposition() == .report
	assert list.policies[0].self_origin_value().serialize() == 'https://example.test'
}

fn test_concrete_directives_delegate_to_shared_algorithms() {
	mut policy := Policy.parse_a_serialized_csp("img-src 'none'; script-src 'self'; sandbox",
		.header, .enforce)
	policy.set_self_origin(url.Origin.tuple('https', url.Host.from_string('example.test'), none,
		none))
	mut request := new_request(url.URL{
		scheme: 'https'
		host:   url.Host.from_string('evil.test')
	})
	request.destination = .image
	image := ImageSourceDirective(create_directive(img_src, ["'none'"]))
	assert image.pre_request_check(request, policy) == .blocked
	script := ScriptSourceDirective(create_directive(script_src, ["'self'"]))
	assert script.inline_check(none, .script, policy, 'alert(1)') == .blocked
	sandboxed := SandboxDirective(create_directive(sandbox, []))
	assert sandboxed.initialization(true, policy) == .blocked
	assert policy.directives().len == 3
	assert policy.disposition() == .enforce
	assert policy.source() == .header
	global := GlobalContext{
		policy_list: PolicyList.create([policy])
	}
	assert PolicyList.from_object(global) != none
}
