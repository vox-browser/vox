module trustedtypes

import webidl

@[heap]
struct AttributeSinkCalls {
mut:
	names []string
}

fn test_attribute_default_policy_receives_concrete_event_handler_sink_names() {
	mut factory := TrustedTypePolicyFactory.create()
	factory.csp_policies = [TrustedTypesCSPPolicy{require_trusted_types_for: ["'script'"]}]
	mut calls := &AttributeSinkCalls{}
	factory.create_policy('default', TrustedTypePolicyOptions{
		create_script: fn [mut calls] (input string, args []webidl.Value) !PolicyResult {
			assert input == 'unsafe'
			assert args.len == 3
			assert webidl.to_string(args[1])! == 'TrustedScript'
			calls.names << webidl.to_string(args[2])!
			return PolicyResult{value: 'safe'}
		}
	})!
	for name, namespace in {'onclick': html_namespace, 'ondblclick': svg_namespace, 'onmousedown': mathml_namespace} {
		assert get_trusted_types_compliant_attribute_value(mut factory, name, none,
			element_interface('g', namespace), 'unsafe')! == 'safe'
		assert calls.names.last() == 'Element ${name}'
	}
	assert calls.names.len == 3
}

fn test_attribute_csp_violation_sample_contains_the_actual_event_handler_name() {
	mut factory := TrustedTypePolicyFactory.create()
	factory.csp_policies = [TrustedTypesCSPPolicy{require_trusted_types_for: ["'script'"]}]
	if _ := get_trusted_types_compliant_attribute_value(mut factory, 'onclick', none,
		element_interface('div', html_namespace), 'unsafe') {
		assert false
	} else {
		assert err.msg().contains('Element onclick')
	}
	assert factory.violations.len == 1
	assert factory.violations[0].sample == 'Element onclick|unsafe'
}
