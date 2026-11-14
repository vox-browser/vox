// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Directives/DirectiveOperations.{h,cpp}.
module contentsecuritypolicy

import sri
import url

pub enum ShouldExecute {
	no
	yes
}

pub enum MatchResult {
	does_not_match
	matches
}

fn ends_with_ignoring_ascii_case(value string, suffix string) bool {
	if value.len < suffix.len {
		return false
	}
	return value[value.len - suffix.len..].to_lower() == suffix.to_lower()
}

fn substring_view(value string, start int) string {
	assert start >= 0 && start <= value.len
	return value[start..]
}

pub fn get_the_effective_directive_for_request(request &Request) ?string {
	if request.initiator in [.prefetch, .prerender] {
		return default_src
	}
	destination := request.destination or { return connect_src }
	return match destination {
		// Top-level document navigations use navigation checks. Applying the
		// fallback connect-src directive here would incorrectly block them.
		.document { none }
		.manifest { manifest_src }
		.object, .embed { object_src }
		.frame, .iframe { frame_src }
		.audio, .track, .video { media_src }
		.font { font_src }
		.image { img_src }
		.style { style_src_elem }
		.script, .xslt, .audio_worklet, .paint_worklet { script_src_elem }
		.service_worker, .shared_worker, .worker { worker_src }
		.json, .web_identity { connect_src }
		.report { none }
		else { connect_src }
	}
}

pub fn get_fetch_directive_fallback_list(directive_name ?string) []string {
	name := directive_name or { return [] }
	return match name {
		script_src_elem { [script_src_elem, script_src, default_src] }
		script_src_attr { [script_src_attr, script_src, default_src] }
		style_src_elem { [style_src_elem, style_src, default_src] }
		style_src_attr { [style_src_attr, style_src, default_src] }
		worker_src { [worker_src, child_src, script_src, default_src] }
		connect_src { [connect_src, default_src] }
		manifest_src { [manifest_src, default_src] }
		object_src { [object_src, default_src] }
		frame_src { [frame_src, child_src, default_src] }
		media_src { [media_src, default_src] }
		font_src { [font_src, default_src] }
		img_src { [img_src, default_src] }
		else { [] }
	}
}

pub fn should_fetch_directive_execute(effective_directive_name ?string, directive_name string, policy &Policy) ShouldExecute {
	for fallback in get_fetch_directive_fallback_list(effective_directive_name) {
		if directive_name == fallback {
			return .yes
		}
		if policy.contains_directive_with_name(fallback) {
			return .no
		}
	}
	return .no
}

pub fn get_the_effective_directive_for_inline_checks(type_ InlineType) string {
	return match type_ {
		.script, .navigation { script_src_elem }
		.script_attribute { script_src_attr }
		.style { style_src_elem }
		.style_attribute { style_src_attr }
	}
}

pub fn scheme_part_matches(a string, b string) MatchResult {
	a_lower := a.to_lower()
	b_lower := b.to_lower()
	if a_lower == b_lower || (a_lower == 'http' && b_lower == 'https')
		|| (a_lower == 'ws' && b_lower in ['wss', 'http', 'https'])
		|| (a_lower == 'wss' && b_lower == 'https') {
		return .matches
	}
	return .does_not_match
}

pub fn host_part_matches(pattern string, maybe_host ?url.Host) MatchResult {
	host := maybe_host or { return .does_not_match }
	// A CSP host-source matches domains, never opaque or numeric IP hosts.
	if !host.is_domain() {
		return .does_not_match
	}
	host_string := host.serialize()
	if pattern == '*' {
		return .matches
	}
	if pattern.starts_with('*.') {
		remaining_without_asterisk := substring_view(pattern, 1)
		return if ends_with_ignoring_ascii_case(host_string, remaining_without_asterisk) {
			MatchResult.matches
		} else {
			MatchResult.does_not_match
		}
	}
	return if pattern.to_lower() == host_string.to_lower() {
		MatchResult.matches
	} else {
		MatchResult.does_not_match
	}
}

fn optional_u16_equal(a ?u16, b ?u16) bool {
	if av := a {
		if bv := b {
			return av == bv
		}
		return false
	}
	return b == none
}

pub fn port_part_matches(input ?string, record url.URL) MatchResult {
	if value := input {
		if value == '*' {
			return .matches
		}
		number := value.u64()
		if number > 65535 {
			return .does_not_match
		}
		normalized := u16(number)
		if port := record.port {
			return if port == normalized { MatchResult.matches } else { MatchResult.does_not_match }
		}
		default_port := url.default_port_for_scheme(record.scheme)
		return if default_value := default_port {
			if default_value == normalized {
				MatchResult.matches
			} else {
				MatchResult.does_not_match
			}
		} else {
			MatchResult.does_not_match
		}
	}
	// An absent CSP port matches a URL with an absent (default) port.
	return if record.port == none { MatchResult.matches } else { MatchResult.does_not_match }
}

pub fn path_part_matches(a string, b string) MatchResult {
	if a == '' || (a == '/' && b == '') {
		return .matches
	}
	exact := !a.ends_with('/')
	mut parts_a := a.split('/')
	parts_b := b.split('/')
	if parts_a.len > parts_b.len || (exact && parts_a.len != parts_b.len) {
		return .does_not_match
	}
	if !exact {
		parts_a = parts_a[..parts_a.len - 1]
	}
	for index, part_a in parts_a {
		if url.percent_decode(part_a).bytestr() != url.percent_decode(parts_b[index]).bytestr() {
			return .does_not_match
		}
	}
	return .matches
}

pub fn url_from_origin(origin url.Origin) ?url.URL {
	if origin is url.OriginTuple {
		scheme := origin.scheme or { return none }
		return url.URL{
			scheme: scheme
			host: origin.host
			port: origin.port
		}
	}
	return none
}

fn is_http_or_https_scheme(scheme string) bool {
	return scheme == 'http' || scheme == 'https'
}

pub fn does_url_match_expression_in_origin_with_redirect_count(record url.URL, expression string, origin url.Origin, redirect_count u8) MatchResult {
	base_scheme := origin_scheme(origin)
	if expression == '*' && (is_http_or_https_scheme(record.scheme) || record.scheme == base_scheme) {
		return .matches
	}
	scheme_expression := parse_source_expression(.scheme_source, expression)
	host_expression := parse_source_expression(.host_source, expression)
	if parsed := scheme_expression {
		part := parsed.scheme_part or { '' }
		return scheme_part_matches(part, record.scheme)
	}
	if parsed := host_expression {
		if part := parsed.scheme_part {
			if scheme_part_matches(part, record.scheme) == .does_not_match {
				return .does_not_match
			}
		} else if scheme_part_matches(base_scheme, record.scheme) == .does_not_match {
			return .does_not_match
		}
		host_part := parsed.host_part or { return .does_not_match }
		if host_part_matches(host_part, record.host) == .does_not_match
			|| port_part_matches(parsed.port_part, record) == .does_not_match {
			return .does_not_match
		}
		if path := parsed.path_part {
			if path != '' && redirect_count == 0
				&& path_part_matches(path, record.serialize_path()) == .does_not_match {
				return .does_not_match
			}
		}
		return .matches
	}
	if expression.to_lower() == keyword_self {
		if origin.is_same_origin(record.origin()) {
			return .matches
		}
		origin_default_port := url.default_port_for_scheme(base_scheme)
		record_default_port := url.default_port_for_scheme(record.scheme)
		hosts_same := if host := origin_host(origin) {
			if record_host := record.host { host == record_host } else { false }
		} else {
			false
		}
		ports_same := optional_u16_equal(origin_port(origin), record.port)
			|| (optional_u16_equal(origin_port(origin), origin_default_port)
				&& optional_u16_equal(record.port, record_default_port))
		if hosts_same && ports_same {
			if record.scheme in ['https', 'wss']
				|| (base_scheme == 'http' && record.scheme in ['http', 'ws']) {
				return .matches
			}
		}
	}
	return .does_not_match
}

pub fn does_url_match_source_list_in_origin_with_redirect_count(record url.URL, source_list []string, origin url.Origin, redirect_count u8) MatchResult {
	if source_list.len == 0 || (source_list.len == 1 && source_list[0].to_lower() == "'none'") {
		return .does_not_match
	}
	for expression in source_list {
		if does_url_match_expression_in_origin_with_redirect_count(record, expression, origin, redirect_count) == .matches {
			return .matches
		}
	}
	return .does_not_match
}

pub fn does_request_match_source_list(request &Request, source_list []string, policy &Policy) MatchResult {
	return does_url_match_source_list_in_origin_with_redirect_count(request.current_url, source_list, policy.self_origin_value(), request.redirect_count)
}

pub fn does_response_match_source_list(response &Response, request &Request, source_list []string, policy &Policy) MatchResult {
	record := response.url or { return .does_not_match }
	return does_url_match_source_list_in_origin_with_redirect_count(record, source_list, policy.self_origin_value(), request.redirect_count)
}

pub fn does_nonce_match_source_list(nonce string, source_list []string) MatchResult {
	if nonce == '' {
		return .does_not_match
	}
	for expression in source_list {
		if parsed := parse_source_expression(.nonce_source, expression) {
			if value := parsed.base64_value {
				if nonce == value {
					return .matches
				}
			}
		}
	}
	return .does_not_match
}

pub fn does_integrity_metadata_match_source_list(integrity_metadata string, source_list []string) MatchResult {
	mut expressions := []SourceExpressionParseResult{}
	for expression in source_list {
		if parsed := parse_source_expression(.hash_source, expression) {
			expressions << parsed
		}
	}
	if expressions.len == 0 {
		return .does_not_match
	}
	sources := sri.parse_metadata(integrity_metadata)
	if sources.len == 0 {
		return .does_not_match
	}
	for source in sources {
		mut matched := false
		for expression in expressions {
			algorithm := expression.hash_algorithm or { continue }
			value := expression.base64_value or { continue }
			if algorithm.to_lower() == source.algorithm.to_lower() && value == source.base64_value {
				matched = true
				break
			}
		}
		if !matched {
			return .does_not_match
		}
	}
	return .matches
}

pub fn script_directives_pre_request_check(request &Request, directive Directive, policy &Policy) Result {
	if request.destination_is_script_like() {
		if does_nonce_match_source_list(request.cryptographic_nonce_metadata, directive.value()) == .matches
			|| does_integrity_metadata_match_source_list(request.integrity_metadata, directive.value()) == .matches {
			return .allowed
		}
		if contains_ascii_case_insensitive(directive.value(), strict_dynamic) {
			return if request.parser_metadata == .parser_inserted {
				Result.blocked
			} else {
				Result.allowed
			}
		}
		if does_request_match_source_list(request, directive.value(), policy) == .does_not_match {
			return .blocked
		}
	}
	return .allowed
}

pub fn script_directives_post_request_check(request &Request, response &Response, directive Directive, policy &Policy) Result {
	if request.destination_is_script_like() {
		if does_nonce_match_source_list(request.cryptographic_nonce_metadata, directive.value()) == .matches
			|| does_integrity_metadata_match_source_list(request.integrity_metadata, directive.value()) == .matches {
			return .allowed
		}
		if contains_ascii_case_insensitive(directive.value(), strict_dynamic) {
			return if request.parser_metadata != .parser_inserted {
				Result.allowed
			} else {
				Result.blocked
			}
		}
		if does_response_match_source_list(response, request, directive.value(), policy) == .does_not_match {
			return .blocked
		}
	}
	return .allowed
}

fn contains_ascii_case_insensitive(values []string, needle string) bool {
	for value in values {
		if value.to_lower() == needle.to_lower() {
			return true
		}
	}
	return false
}

pub fn does_a_source_list_allow_all_inline_behavior_for_type(source_list []string, type_ InlineType) bool {
	mut allow_all := false
	for expression in source_list {
		if parse_source_expression(.nonce_source, expression) != none
			|| parse_source_expression(.hash_source, expression) != none {
			return false
		}
		if type_ in [.script, .script_attribute, .navigation]
			&& expression.to_lower() == strict_dynamic {
			return false
		}
		if expression.to_lower() == unsafe_inline {
			allow_all = true
		}
	}
	return allow_all
}

pub fn is_element_nonceable(element ?ElementContext) bool {
	value := element or { return false }
	if !value.is_html_or_svg || value.nonce == '' {
		return false
	}
	if value.is_script {
		for name, attribute_value in value.attributes {
			lower_name := name.to_lower()
			lower_value := attribute_value.to_lower()
			if lower_name.contains('<link') || lower_name.contains('<script') || lower_name.contains('<style')
				|| lower_value.contains('<link') || lower_value.contains('<script') || lower_value.contains('<style') {
				return false
			}
		}
	}
	return !value.had_duplicate_attribute
}

pub fn does_element_match_source_list_for_type_and_source(element ?ElementContext, source_list []string, type_ InlineType, source string) MatchResult {
	if does_a_source_list_allow_all_inline_behavior_for_type(source_list, type_) {
		return .matches
	}
	if type_ in [.script, .style] && is_element_nonceable(element) {
		value := element or { ElementContext{} }
		for expression in source_list {
			if parsed := parse_source_expression(.nonce_source, expression) {
				if nonce := parsed.base64_value {
					if nonce == value.nonce {
						return .matches
					}
				}
			}
		}
	}
	unsafe_hashes_flag := contains_ascii_case_insensitive(source_list, unsafe_hashes)
	if type_ in [.script, .style] || unsafe_hashes_flag {
		for expression in source_list {
			if expression.to_lower() == strict_dynamic && type_ == .script {
				if value := element {
					if value.is_script && !value.parser_inserted {
						return .matches
					}
				}
			}
			if parsed := parse_source_expression(.hash_source, expression) {
				algorithm := parsed.hash_algorithm or { continue }
				expected_raw := parsed.base64_value or { continue }
				actual := sri.apply_algorithm_to_bytes(algorithm.to_lower(), source.bytes()) or {
					continue
				}
				expected := expected_raw.replace('-', '+').replace('_', '/')
				if actual == expected {
					return .matches
				}
			}
		}
	}
	return .does_not_match
}
