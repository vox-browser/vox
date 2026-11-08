module trustedtypes

import webidl

fn navigation_callback(input string, _ []webidl.Value) !PolicyResult {
	return PolicyResult{
		value: 'safe:${input}'
	}
}

fn test_csp_policy_creation_name_duplicate_and_report_only() {
	mut factory := TrustedTypePolicyFactory.create()
	factory.csp_policies << TrustedTypesCSPPolicy{
		disposition: .enforce
		trusted_types: ['safe']
	}
	factory.create_a_trusted_type_policy('safe', TrustedTypePolicyOptions{})!
	if _ := factory.create_policy('safe', TrustedTypePolicyOptions{}) {
		assert false
	} else {
		assert err.msg().starts_with('TypeError:')
	}
	if _ := factory.create_policy('other', TrustedTypePolicyOptions{}) {
		assert false
	} else {
		assert err.msg().starts_with('TypeError:')
	}
	assert factory.violations.len == 2

	mut report_factory := TrustedTypePolicyFactory.create()
	report_factory.csp_policies << TrustedTypesCSPPolicy{
		disposition: .report_only
		trusted_types: ["'none'"]
	}
	report_factory.create_policy('allowed', TrustedTypePolicyOptions{})!
	assert report_factory.violations.len == 1
}

fn test_exact_csp_algorithm_entry_points() {
	mut factory := TrustedTypePolicyFactory.create()
	factory.csp_policies << TrustedTypesCSPPolicy{
		disposition: .enforce
		trusted_types: ['safe']
		require_trusted_types_for: ["'script'"]
	}
	assert factory.should_trusted_type_policy_be_blocked_by_content_security_policy('other', []string{})
	assert should_sink_type_mismatch_violation_be_blocked_by_content_security_policy(mut factory, .eval, "'script'", 'source')
	directive := &RequireTrustedTypesForDirective{}
	assert directive.pre_navigation_check(mut factory, 'https://example.test/')! == 'https://example.test/'
}

fn test_sink_requirement_violation_sample_and_blocking() {
	mut factory := TrustedTypePolicyFactory.create()
	factory.csp_policies << TrustedTypesCSPPolicy{
		disposition: .enforce
		require_trusted_types_for: ["'SCRIPT'"]
	}
	assert factory.does_sink_require_trusted_types("'script'", false)
	assert factory.does_sink_require_trusted_types('script', false)
	assert factory.does_sink_require_trusted_types('"ScRiPt"', false)
	assert factory.should_sink_type_mismatch_violation_be_blocked(.function_, "'script'", 'function anonymousabcdefghijklmnopqrstuvwxyz0123456789extra')
	assert factory.violations.last().resource == 'trusted-types-sink'
	assert factory.violations.last().sample.starts_with('Function|abcdefghijklmnopqrstuvwxyz')
	assert factory.violations.last().sample.runes().len <= 'Function|'.len + 40
}

fn test_factory_relevant_global_realm_and_default_policy_offset() {
	mut global_value := u8(1)
	mut realm_value := u8(2)
	global := &global_value
	realm := &realm_value
	context := &TrustedTypesGlobalContext{
		global: voidptr(global)
		realm: voidptr(realm)
	}
	factory := TrustedTypePolicyFactory.create_for_global(context)
	assert factory.relevant_global_impl() == voidptr(global)
	assert factory.relevant_realm() == voidptr(realm)
	assert TrustedTypePolicyFactory.default_policy_offset() > 0
	assert TrustedTypePolicyFactory.create().relevant_global_impl() == unsafe { nil }
}

fn test_attribute_and_property_type_tables() {
	factory := TrustedTypePolicyFactory.create()
	assert factory.get_attribute_type('SCRIPT', 'SRC', none, none)? == 'TrustedScriptURL'
	assert factory.get_attribute_type('script', 'href', svg_namespace, '')? == 'TrustedScriptURL'
	assert factory.get_attribute_type('script', 'href', svg_namespace, xlink_namespace)? == 'TrustedScriptURL'
	assert factory.get_attribute_type('div', 'onclick', mathml_namespace, none)? == 'TrustedScript'
	assert factory.get_attribute_type('div', 'title', none, none) == none
	assert factory.get_property_type('iframe', 'srcdoc', none)? == 'TrustedHTML'
	assert factory.get_property_type('script', 'textContent', none)? == 'TrustedScript'
	assert factory.get_property_type('div', 'innerHTML', none)? == 'TrustedHTML'
}

fn test_policy_violation_name_is_limited_to_forty_unicode_characters() {
	mut factory := TrustedTypePolicyFactory.create()
	factory.csp_policies << TrustedTypesCSPPolicy{
		disposition: .report_only
		trusted_types: ["'none'"]
	}
	factory.create_policy('абвгдежзийклмнопрстуфхцчшщъыьэюя-abcdefghijk', TrustedTypePolicyOptions{})!
	assert factory.violations[0].sample.runes().len == 40
}

fn test_compliant_attribute_value_uses_event_handler_and_xlink_tables() {
	mut factory := TrustedTypePolicyFactory.create()
	factory.csp_policies << TrustedTypesCSPPolicy{
		disposition: .enforce
		require_trusted_types_for: ["'script'"]
	}
	element := element_interface('div', html_namespace)
	if _ := get_trusted_types_compliant_attribute_value(mut factory, 'onclick', none, element, 'alert(1)') {
		assert false
	} else {
		assert err.msg().starts_with('TypeError:')
	}
	assert factory.violations.last().sample == 'Element onclick|alert(1)'
	assert get_trusted_types_compliant_attribute_value(mut factory, 'title', none, element, 'plain')! == 'plain'
}

fn test_navigation_javascript_default_policy_conversion() {
	mut factory := TrustedTypePolicyFactory.create()
	assert factory.pre_navigation_check('https://example.test/')! == 'https://example.test/'
	if _ := factory.pre_navigation_check('javascript:bad()') {
		assert false
	} else {
		assert err.msg() == 'Blocked'
	}
	factory.create_policy('default', TrustedTypePolicyOptions{ create_script: navigation_callback })!
	assert factory.pre_navigation_check('javascript:go()')! == 'javascript:safe:go()'
}
