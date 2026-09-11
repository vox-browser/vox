module trustedtypes

import webidl

fn prefix_callback(input string, arguments []webidl.Value) !PolicyResult {
	assert arguments.len >= 1
	return PolicyResult{
		value: 'safe:${input}'
	}
}

fn null_callback(_ string, _ []webidl.Value) !PolicyResult {
	return PolicyResult{}
}

fn test_trusted_values_policy_callbacks_and_missing_callback() {
	policy := TrustedTypePolicy.create('p', TrustedTypePolicyOptions{
		create_html: prefix_callback
		create_script_url: null_callback
	})
	assert policy.name() == 'p'
	html := policy.create_html('<b>x</b>', [webidl.number_value(1)])!
	assert html.to_string() == 'safe:<b>x</b>'
	assert html.to_json() == html.to_string()
	url := policy.create_script_url('x', []webidl.Value{})!
	assert url.data == ''
	if _ := policy.create_script('x', []webidl.Value{}) {
		assert false
	} else {
		assert err.msg().starts_with('TypeError:')
	}
}

fn test_factory_default_uniqueness_type_checks_and_empty_singletons() {
	mut factory := TrustedTypePolicyFactory.create()
	default_policy := factory.create_policy('default', TrustedTypePolicyOptions{
		create_script: prefix_callback
	})!
	assert factory.default_policy()? == default_policy
	if _ := factory.create_policy('default', TrustedTypePolicyOptions{}) {
		assert false
	} else {
		assert err.msg().contains('already has a default')
	}
	assert factory.is_html(TrustedHTML{ data: 'x' })
	assert !factory.is_html('x')
	assert factory.is_script(TrustedScript{ data: 'x' })
	assert factory.is_script_url(TrustedScriptURL{ data: 'x' })
	assert factory.empty_html().data == ''
	assert factory.empty_script().data == ''
}

fn test_default_policy_processing_and_compliant_string() {
	mut factory := TrustedTypePolicyFactory.create()
	factory.csp_policies << TrustedTypesCSPPolicy{
		disposition: .enforce
		require_trusted_types_for: ["'script'"]
	}
	factory.create_policy('default', TrustedTypePolicyOptions{ create_script: prefix_callback })!
	converted := get_trusted_type_compliant_string(mut factory, .trusted_script, 'alert(1)', .eval, "'script'", true)!
	assert converted == 'safe:alert(1)'
	assert get_trusted_type_compliant_string(mut factory, .trusted_script, TrustedScript{
		data: 'already'
	}, .eval, "'script'", true)! == 'already'
}

fn test_binding_value_helpers_and_policy_callback_invocation() {
	html := TrustedHTML{ data: '<p>safe</p>' }
	script := TrustedScript{ data: 'safe()' }
	url := TrustedScriptURL{ data: 'https://example.test/app.js' }
	assert trusted_html_from_value(html)?.data == html.data
	assert trusted_html_from_value('plain') == none
	assert trusted_script_from_value(script)?.data == script.data
	assert trusted_script_url_from_value(url)?.data == url.data
	assert is_trusted_html_value(html)
	assert is_trusted_script_value(script)
	assert is_trusted_script_url_value(url)
	assert trusted_script_value_matches(script, 'safe()')
	assert !trusted_script_value_matches('safe()', 'safe()')
	assert trusted_script_values_match([TrustedTypeOrString(script),
		TrustedTypeOrString(TrustedScript{ data: 'second()' })], [
		'safe()',
		'second()',
	])
	assert !trusted_script_values_match([TrustedTypeOrString(script)], ['safe()', 'extra'])

	result := invoke_trusted_type_policy_callback(prefix_callback, [
		webidl.string_value('input'),
	])!
	assert result.value? == 'safe:input'
}
