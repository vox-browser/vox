// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Directive, DirectiveFactory, every concrete directive class,
// Names, KeywordSources and KeywordTrustedTypes.
module contentsecuritypolicy

pub enum DirectiveKind {
	base_uri
	child_source
	connect_source
	default_source
	font_source
	form_action
	frame_ancestors
	frame_source
	image_source
	manifest_source
	media_source
	object_source
	report_to
	report_uri
	require_trusted_types_for
	sandbox
	script_source
	script_source_element
	script_source_attribute
	style_source
	style_source_element
	style_source_attribute
	trusted_types
	webrtc
	worker_source
	unknown
}

pub struct SerializedDirective {
pub:
	name  string
	value []string
}

pub struct Directive {
pub:
	kind DirectiveKind
mut:
	name_  string
	value_ []string
}

pub fn create_directive(name string, value []string) Directive {
	kind := match name {
		base_uri { DirectiveKind.base_uri }
		child_src { .child_source }
		connect_src { .connect_source }
		default_src { .default_source }
		font_src { .font_source }
		form_action { .form_action }
		frame_ancestors { .frame_ancestors }
		frame_src { .frame_source }
		img_src { .image_source }
		manifest_src { .manifest_source }
		media_src { .media_source }
		object_src { .object_source }
		report_to { .report_to }
		report_uri { .report_uri }
		require_trusted_types_for { .require_trusted_types_for }
		sandbox { .sandbox }
		script_src { .script_source }
		script_src_elem { .script_source_element }
		script_src_attr { .script_source_attribute }
		style_src { .style_source }
		style_src_elem { .style_source_element }
		style_src_attr { .style_source_attribute }
		trusted_types { .trusted_types }
		webrtc { .webrtc }
		worker_src { .worker_source }
		else { .unknown }
	}
	return Directive{
		name_:  name
		value_: value.clone()
		kind:   kind
	}
}

pub fn (directive &Directive) name() string {
	return directive.name_
}

pub fn (directive &Directive) value() []string {
	return directive.value_.clone()
}

pub fn (directive Directive) clone() Directive {
	return create_directive(directive.name_, directive.value_)
}

pub fn (directive Directive) serialize() SerializedDirective {
	return SerializedDirective{
		name:  directive.name_
		value: directive.value_.clone()
	}
}

fn (directive Directive) uses_plain_fetch_check() bool {
	return directive.kind in [.connect_source, .font_source, .frame_source, .image_source,
		.manifest_source, .media_source, .object_source, .worker_source]
}

pub fn (directive Directive) pre_request_check(request &Request, policy &Policy) Result {
	effective := get_the_effective_directive_for_request(request)
	if directive.kind == .default_source || directive.kind == .child_source {
		if should_fetch_directive_execute(effective, directive.name_, policy) == .no {
			return .allowed
		}
		name := effective or { return .allowed }
		return create_directive(name, directive.value_).pre_request_check(request, policy)
	}
	if directive.kind in [.script_source, .script_source_element] {
		if should_fetch_directive_execute(effective, directive.name_, policy) == .no {
			return .allowed
		}
		return script_directives_pre_request_check(request, directive, policy)
	}
	if directive.kind in [.style_source, .style_source_element] {
		if should_fetch_directive_execute(effective, directive.name_, policy) == .no {
			return .allowed
		}
		if does_nonce_match_source_list(request.cryptographic_nonce_metadata, directive.value_) == .matches {
			return .allowed
		}
		return if does_request_match_source_list(request, directive.value_, policy) == .matches {
			Result.allowed
		} else {
			Result.blocked
		}
	}
	if directive.uses_plain_fetch_check() {
		if should_fetch_directive_execute(effective, directive.name_, policy) == .no {
			return .allowed
		}
		return if does_request_match_source_list(request, directive.value_, policy) == .matches {
			Result.allowed
		} else {
			Result.blocked
		}
	}
	return .allowed
}

pub fn (directive Directive) post_request_check(request &Request, response &Response, policy &Policy) Result {
	effective := get_the_effective_directive_for_request(request)
	if directive.kind == .default_source || directive.kind == .child_source {
		if should_fetch_directive_execute(effective, directive.name_, policy) == .no {
			return .allowed
		}
		name := effective or { return .allowed }
		return create_directive(name, directive.value_).post_request_check(request, response, policy)
	}
	if directive.kind in [.script_source, .script_source_element] {
		if should_fetch_directive_execute(effective, directive.name_, policy) == .no {
			return .allowed
		}
		return script_directives_post_request_check(request, response, directive, policy)
	}
	if directive.kind in [.style_source, .style_source_element] {
		if should_fetch_directive_execute(effective, directive.name_, policy) == .no {
			return .allowed
		}
		if does_nonce_match_source_list(request.cryptographic_nonce_metadata, directive.value_) == .matches {
			return .allowed
		}
		return if does_response_match_source_list(response, request, directive.value_, policy) == .matches {
			Result.allowed
		} else {
			Result.blocked
		}
	}
	if directive.uses_plain_fetch_check() {
		if should_fetch_directive_execute(effective, directive.name_, policy) == .no {
			return .allowed
		}
		return if does_response_match_source_list(response, request, directive.value_, policy) == .matches {
			Result.allowed
		} else {
			Result.blocked
		}
	}
	return .allowed
}

pub fn (directive Directive) inline_check(element ?ElementContext, type_ InlineType, policy &Policy, source string) Result {
	if directive.kind !in [.default_source, .script_source, .script_source_element,
		.script_source_attribute, .style_source, .style_source_element, .style_source_attribute] {
		return .allowed
	}
	effective := get_the_effective_directive_for_inline_checks(type_)
	if directive.kind == .default_source {
		if should_fetch_directive_execute(effective, default_src, policy) == .no {
			return .allowed
		}
		return create_directive(effective, directive.value_).inline_check(element, type_, policy,
			source)
	}
	if should_fetch_directive_execute(effective, directive.name_, policy) == .no {
		return .allowed
	}
	return if does_element_match_source_list_for_type_and_source(element, directive.value_, type_,
		source) == .matches {
		Result.allowed
	} else {
		Result.blocked
	}
}

pub fn (directive Directive) initialization(is_worker bool, policy &Policy) Result {
	if directive.kind != .sandbox || policy.disposition() != .enforce || !is_worker {
		return .allowed
	}
	flags := parse_a_sandboxing_directive(directive.value_)
	if flags.contains(.sandboxed_scripts) || flags.contains(.sandboxed_origin) {
		return .blocked
	}
	return .allowed
}

pub fn (directive Directive) pre_navigation_check(request &Request, navigation_type NavigationType, policy &Policy) Result {
	if directive.kind == .form_action && navigation_type == .form_submission
		&& does_request_match_source_list(request, directive.value_, policy) == .does_not_match {
		return .blocked
	}
	return .allowed
}

pub fn (directive Directive) navigation_response_check(response &Response, target NavigableContext, check_type CheckType, policy &Policy) Result {
	if directive.kind != .frame_ancestors || response.is_local || check_type == .source {
		return .allowed
	}
	ancestor_origins := target.active_ancestor_origins()
	if ancestor_origins.len == 0 {
		return .allowed
	}
	for ancestor_origin in ancestor_origins {
		if ancestor_origin.is_opaque() {
			return .blocked
		}
		ancestor_url := url_from_origin(ancestor_origin) or { return .blocked }
		if does_url_match_source_list_in_origin_with_redirect_count(ancestor_url, directive.value_,
			policy.self_origin_value(), 0) == .does_not_match {
			return .blocked
		}
	}
	return .allowed
}

pub fn (directive Directive) webrtc_pre_connect_check() Result {
	if directive.kind != .webrtc {
		return .allowed
	}
	return if directive.value_.len == 1 && directive.value_[0].to_lower() == "'allow'" {
		Result.allowed
	} else {
		Result.blocked
	}
}
