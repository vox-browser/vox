// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of TrustedTypes/TrustedTypePolicy.{h,cpp}.
module trustedtypes

import webidl

pub struct PolicyResult {
pub:
	value ?string
}

pub type PolicyCallback = fn (string, []webidl.Value) !PolicyResult

// Invoke a Trusted Type policy callback with an undefined `this` value and
// rethrow callback exceptions. `PolicyCallback` models `this` out of band; its
// first parameter is the converted first argument and the second receives the
// complete JavaScript argument list.
pub fn invoke_trusted_type_policy_callback(callback PolicyCallback, arguments []webidl.Value) !PolicyResult {
	input := if arguments.len > 0 { webidl.to_string(arguments[0])! } else { '' }
	return callback(input, arguments)
}

pub struct TrustedTypePolicyOptions {
pub:
	create_html       ?PolicyCallback
	create_script     ?PolicyCallback
	create_script_url ?PolicyCallback
}

pub enum ThrowIfCallbackMissing {
	no
	yes
}

@[heap]
pub struct TrustedTypePolicy {
mut:
	name_   string
	options TrustedTypePolicyOptions
}

pub fn TrustedTypePolicy.create(name string, options TrustedTypePolicyOptions) &TrustedTypePolicy {
	return &TrustedTypePolicy{
		name_: name
		options: options
	}
}

pub fn (policy &TrustedTypePolicy) name() string {
	return policy.name_
}

pub fn (policy &TrustedTypePolicy) get_trusted_type_policy_value(name TrustedTypeName, value string, arguments []webidl.Value, throw_if_missing ThrowIfCallbackMissing) !PolicyResult {
	callback := match name {
		.trusted_html { policy.options.create_html }
		.trusted_script { policy.options.create_script }
		.trusted_script_url { policy.options.create_script_url }
	}
	if function := callback {
		mut args := [webidl.string_value(value)]
		args << arguments
		return invoke_trusted_type_policy_callback(function, args)
	}
	if throw_if_missing == .yes {
		return error('TypeError: Trying to create a trusted type without a callback')
	}
	return PolicyResult{}
}

pub fn (policy &TrustedTypePolicy) create_html(input string, arguments []webidl.Value) !TrustedHTML {
	trusted := policy.create_a_trusted_type(.trusted_html, input, arguments)!
	if trusted is TrustedHTML {
		return trusted
	}
	return error('internal trusted type mismatch')
}

pub fn (policy &TrustedTypePolicy) create_script(input string, arguments []webidl.Value) !TrustedScript {
	trusted := policy.create_a_trusted_type(.trusted_script, input, arguments)!
	if trusted is TrustedScript {
		return trusted
	}
	return error('internal trusted type mismatch')
}

pub fn (policy &TrustedTypePolicy) create_script_url(input string, arguments []webidl.Value) !TrustedScriptURL {
	trusted := policy.create_a_trusted_type(.trusted_script_url, input, arguments)!
	if trusted is TrustedScriptURL {
		return trusted
	}
	return error('internal trusted type mismatch')
}

// https://w3c.github.io/trusted-types/dist/spec/#create-a-trusted-type-algorithm
pub fn (policy &TrustedTypePolicy) create_a_trusted_type(name TrustedTypeName, input string, arguments []webidl.Value) !TrustedType {
	result := policy.get_trusted_type_policy_value(name, input, arguments, .yes)!
	return create_trusted_type(name, result.value or { '' })
}

pub fn create_trusted_type(name TrustedTypeName, data string) TrustedType {
	return match name {
		.trusted_html {
			TrustedHTML{
				data: data
			}
		}
		.trusted_script {
			TrustedScript{
				data: data
			}
		}
		.trusted_script_url {
			TrustedScriptURL{
				data: data
			}
		}
	}
}

pub struct TrustedTypeResult {
pub:
	value ?TrustedType
}

pub fn process_value_with_a_default_policy(factory &TrustedTypePolicyFactory, name TrustedTypeName, input TrustedTypeOrString, sink InjectionSink) !TrustedTypeResult {
	return process_value_with_a_default_policy_named(factory, name, input, injection_sink_string(sink))
}

fn process_value_with_a_default_policy_named(factory &TrustedTypePolicyFactory, name TrustedTypeName, input TrustedTypeOrString, sink_name string) !TrustedTypeResult {
	policy := factory.default_policy() or { return TrustedTypeResult{} }
	callback_arguments := [webidl.string_value(trusted_type_name_string(name)),
		webidl.string_value(sink_name)]
	result := policy.get_trusted_type_policy_value(name, stringify(input), callback_arguments, .no)!
	data := result.value or { return TrustedTypeResult{} }
	return TrustedTypeResult{
		value: create_trusted_type(name, data)
	}
}

pub fn get_trusted_type_compliant_string(mut factory TrustedTypePolicyFactory, expected TrustedTypeName, input TrustedTypeOrString, sink InjectionSink, sink_group string, include_report_only bool) !string {
	return get_trusted_type_compliant_string_named(mut factory, expected, input, sink,
		injection_sink_string(sink), sink_group, include_report_only)
}

fn get_trusted_type_compliant_string_named(mut factory TrustedTypePolicyFactory, expected TrustedTypeName, input TrustedTypeOrString, sink InjectionSink, sink_name string, sink_group string, include_report_only bool) !string {
	if trusted_type_matches(input, expected) {
		return stringify(input)
	}
	if !factory.does_sink_require_trusted_types(sink_group, include_report_only) {
		return stringify(input)
	}
	converted := process_value_with_a_default_policy_named(factory, expected, input, sink_name)!
	if trusted := converted.value {
		return match trusted {
			TrustedHTML { trusted.data }
			TrustedScript { trusted.data }
			TrustedScriptURL { trusted.data }
		}
	}
	if should_sink_type_mismatch_violation_be_blocked_named(mut factory, sink, sink_name, sink_group, stringify(input)) {
		return error('TypeError: Sink ${sink_name} of type ${sink_group} requires a TrustedType to be used')
	}
	return stringify(input)
}

// Translation of validate-attribute-mutation. DOM element/document lookup is
// represented explicitly by ElementInterface and the factory passed by the
// embedding layer.
pub fn get_trusted_types_compliant_attribute_value(mut factory TrustedTypePolicyFactory, attribute_name string, attribute_ns ?string, element ElementInterface, new_value TrustedTypeOrString) !string {
	normalized_ns := if value := attribute_ns {
		if value == '' { none } else { value }
	} else {
		none
	}
	data := get_trusted_type_data_for_attribute(element, attribute_name.to_lower(), normalized_ns) or {
		return stringify(new_value)
	}
	sink_name := if data.sink == .element_event_handler { 'Element ${attribute_name.to_lower()}' } else { injection_sink_string(data.sink) }
	return get_trusted_type_compliant_string_named(mut factory, data.trusted_type, new_value, data.sink, sink_name, "'script'", true)
}
