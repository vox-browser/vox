// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of BlockingAlgorithms.{h,cpp}.
module contentsecuritypolicy

import sri
import url

pub fn does_resource_hint_request_violate_policy(request &Request, policy &Policy) ?Directive {
	default_directive := policy.get_directive_by_name(default_src) or { return none }
	for directive in policy.directives() {
		if directive.pre_request_check(request, policy) == .allowed {
			return none
		}
	}
	return default_directive
}

pub fn does_request_violate_policy(request &Request, policy &Policy) ?Directive {
	if request.initiator == .prefetch {
		return does_resource_hint_request_violate_policy(request, policy)
	}
	mut violates := ?Directive(none)
	for directive in policy.directives() {
		if directive.pre_request_check(request, policy) == .blocked {
			violates = directive
		}
	}
	return violates
}

pub fn report_content_security_policy_violations_for_request(mut global GlobalContext, request &Request) {
	if isnil(request.policy_list) {
		return
	}
	for policy in request.policy_list.policies {
		if policy.disposition() == .enforce {
			continue
		}
		if does_request_violate_policy(request, policy) != none {
			violation := create_a_violation_object_for_request_and_policy(global, request, policy)
			violation.report_a_violation(mut global)
		}
	}
}

pub fn should_request_be_blocked_by_content_security_policy(mut global GlobalContext, request &Request) Result {
	if isnil(request.policy_list) {
		return .allowed
	}
	mut result := Result.allowed
	for policy in request.policy_list.policies {
		if policy.disposition() == .report {
			continue
		}
		if does_request_violate_policy(request, policy) != none {
			violation := create_a_violation_object_for_request_and_policy(global, request, policy)
			violation.report_a_violation(mut global)
			result = .blocked
		}
	}
	return result
}

pub fn should_request_be_blocked_by_integrity_policy(request &Request) Result {
	parsed_metadata := sri.parse_metadata(request.integrity_metadata)
	if parsed_metadata.len > 0 && request.mode in [.cors, .same_origin] {
		return .allowed
	}
	if request.is_local {
		return .allowed
	}
	if request.integrity_policy.is_empty() && request.report_only_integrity_policy.is_empty() {
		return .allowed
	}
	mut block := false
	if destination := request.destination {
		block = 'inline' in request.integrity_policy.sources
			&& destination in request.integrity_policy.blocked_destinations
		// Report-only policy is intentionally evaluated without blocking, matching
		// Ladybird's current implementation (reporting remains an upstream FIXME).
	}
	return if block { Result.blocked } else { Result.allowed }
}

pub fn should_response_to_request_be_blocked_by_content_security_policy(mut global GlobalContext, response &Response, request &Request) Result {
	if isnil(request.policy_list) {
		return .allowed
	}
	mut result := Result.allowed
	for policy in request.policy_list.policies {
		for directive in policy.directives() {
			if directive.post_request_check(request, response, policy) == .blocked {
				violation := create_a_violation_object_for_request_and_policy(global, request,
					policy)
				violation.report_a_violation(mut global)
				if policy.disposition() == .enforce {
					result = .blocked
				}
			}
		}
	}
	return result
}

pub fn should_navigation_request_of_type_be_blocked_by_content_security_policy(mut global GlobalContext, request &Request, navigation_type NavigationType) Result {
	if isnil(request.policy_list) {
		return .allowed
	}
	mut result := Result.allowed
	for policy in request.policy_list.policies {
		for directive in policy.directives() {
			if directive.pre_navigation_check(request, navigation_type, policy) == .blocked {
				mut violation := create_a_violation_object_for_global_policy_and_directive(global,
					policy, directive.name())
				violation.set_resource(ViolationResource(request.url))
				violation.report_a_violation(mut global)
				if policy.disposition() == .enforce {
					result = .blocked
				}
			}
		}
	}
	if result == .allowed && request.current_url.scheme == 'javascript' {
		for policy in request.policy_list.policies {
			for directive in policy.directives() {
				if directive.inline_check(none, .navigation, policy,
					request.current_url.serialize(false)) == .blocked {
					mut violation := create_a_violation_object_for_global_policy_and_directive(global,
						policy, get_the_effective_directive_for_inline_checks(.navigation))
					violation.set_resource(ViolationResource(request.url))
					violation.report_a_violation(mut global)
					if policy.disposition() == .enforce {
						result = .blocked
					}
				}
			}
		}
	}
	return result
}

pub fn should_navigation_response_to_navigation_request_of_type_in_target_be_blocked_by_content_security_policy(mut global GlobalContext, request ?&Request, response &Response, response_csp_list &PolicyList, navigation_type NavigationType, target NavigableContext) Result {
	navigation_request := request or { return .allowed }
	mut result := Result.allowed
	for policy in response_csp_list.policies {
		for directive in policy.directives() {
			if directive.navigation_response_check(response, target, .response, policy) == .blocked {
				mut violation := create_a_violation_object_for_global_policy_and_directive(global,
					policy, directive.name())
				violation.set_resource(if response_url := response.url {
					ViolationResource(response_url)
				} else {
					ViolationResource(EmptyResource{})
				})
				violation.report_a_violation(mut global)
				if policy.disposition() == .enforce {
					result = .blocked
				}
			}
		}
	}
	if !isnil(navigation_request.policy_list) {
		for policy in navigation_request.policy_list.policies {
			for directive in policy.directives() {
				if directive.navigation_response_check(response, target, .source, policy) == .blocked {
					mut violation := create_a_violation_object_for_global_policy_and_directive(global,
						policy, directive.name())
					violation.set_resource(ViolationResource(navigation_request.url))
					violation.report_a_violation(mut global)
					if policy.disposition() == .enforce {
						result = .blocked
					}
				}
			}
		}
	}
	_ = navigation_type
	return result
}

pub fn should_elements_inline_type_behavior_be_blocked_by_content_security_policy(mut global GlobalContext, element ElementContext, type_ InlineType, source string) Result {
	if isnil(global.policy_list) {
		return .allowed
	}
	mut result := Result.allowed
	for policy in global.policy_list.policies {
		for directive in policy.directives() {
			if directive.inline_check(element, type_, policy, source) == .blocked {
				mut violation := create_a_violation_object_for_global_policy_and_directive(global,
					policy, get_the_effective_directive_for_inline_checks(type_))
				violation.set_resource(ViolationResource(ViolationResourceKind.inline))
				violation.set_element(element)
				if contains_ascii_case_insensitive(directive.value(), report_sample) {
					runes := source.runes()
					sample_length := if runes.len < 40 { runes.len } else { 40 }
					violation.set_sample(runes[..sample_length].string())
				}
				violation.report_a_violation(mut global)
				if policy.disposition() == .enforce {
					result = .blocked
				}
			}
		}
	}
	return result
}

fn script_source_list(policy &Policy) ?[]string {
	if directive := policy.get_directive_by_name(script_src) {
		return directive.value()
	}
	if directive := policy.get_directive_by_name(default_src) {
		return directive.value()
	}
	return none
}

pub fn ensure_csp_does_not_block_string_compilation(mut global GlobalContext, input CompilationInput) ! {
	mut source_string := input.code_string
	if input.type_ != .timer {
		mut is_trusted := false
		if trusted_body := input.body_arg_trusted_data {
			is_trusted = trusted_body == input.body_string
			if is_trusted {
				if input.parameter_arg_trusted_data.len != input.parameter_strings.len {
					is_trusted = false
				} else {
					for index, parameter in input.parameter_strings {
						trusted := input.parameter_arg_trusted_data[index] or {
							is_trusted = false
							break
						}
						if trusted != parameter {
							is_trusted = false
							break
						}
					}
				}
			}
		}
		_ = is_trusted
		if input.trusted_types_failed {
			return error('EvalError: Blocked by Content Security Policy')
		}
		if transformed := input.trusted_types_result {
			source_string = transformed
			if source_string != input.code_string {
				return error('EvalError: Blocked by Content Security Policy')
			}
		}
	}
	if isnil(global.policy_list) {
		return
	}
	mut blocked := false
	mut trusted_types_required := false
	for policy in global.policy_list.policies {
		if policy.disposition() != .enforce { continue }
		if directive := policy.get_directive_by_name(require_trusted_types_for) {
			if "'script'" in directive.value() { trusted_types_required = true }
		}
	}
	for policy in global.policy_list.policies {
		if source_list := script_source_list(policy) {
			if trusted_types_required && contains_ascii_case_insensitive(source_list, trusted_types_eval) { continue }
			if !contains_ascii_case_insensitive(source_list, unsafe_eval) {
				mut violation := create_a_violation_object_for_global_policy_and_directive(global,
					policy, script_src)
				violation.set_resource(ViolationResource(ViolationResourceKind.eval))
				if contains_ascii_case_insensitive(source_list, report_sample) {
					runes := source_string.runes()
					sample_length := if runes.len < 40 { runes.len } else { 40 }
					violation.set_sample(runes[..sample_length].string())
				}
				violation.report_a_violation(mut global)
				if policy.disposition() == .enforce {
					blocked = true
				}
			}
		}
	}
	if blocked {
		return error('EvalError: Blocked by Content Security Policy')
	}
}

pub fn ensure_csp_does_not_block_wasm_byte_compilation(mut global GlobalContext) ! {
	if isnil(global.policy_list) {
		return
	}
	mut blocked := false
	for policy in global.policy_list.policies {
		if source_list := script_source_list(policy) {
			if !contains_ascii_case_insensitive(source_list, unsafe_eval)
				&& !contains_ascii_case_insensitive(source_list, wasm_unsafe_eval) {
				mut violation := create_a_violation_object_for_global_policy_and_directive(global,
					policy, script_src)
				violation.set_resource(ViolationResource(ViolationResourceKind.wasm_eval))
				violation.report_a_violation(mut global)
				if policy.disposition() == .enforce {
					blocked = true
				}
			}
		}
	}
	if blocked {
		return error('WebAssembly.CompileError: Blocked by Content Security Policy')
	}
}

pub fn is_base_allowed_for_document(mut global GlobalContext, base url.URL) Result {
	if isnil(global.policy_list) {
		return .allowed
	}
	for policy in global.policy_list.policies {
		if directive := policy.get_directive_by_name(base_uri) {
			if does_url_match_source_list_in_origin_with_redirect_count(base, directive.value(),
				policy.self_origin_value(), 0) == .does_not_match {
				mut violation := create_a_violation_object_for_global_policy_and_directive(global,
					policy, base_uri)
				violation.set_resource(ViolationResource(ViolationResourceKind.inline))
				violation.report_a_violation(mut global)
				if policy.disposition() == .enforce {
					return .blocked
				}
			}
		}
	}
	return .allowed
}
