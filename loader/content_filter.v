// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Loader/ContentBlocker.{h,cpp}. The upstream Rust engine is
// represented by a native V rule engine at this module boundary.
@[has_globals]
module loader

import dom
import encoding.utf8
import fetch
import platform
import url as liburl

pub enum ContentBlockerResourceType {
	document
	font
	image
	media
	object
	other
	ping
	script
	stylesheet
	subdocument
	websocket
	xml_http_request
}

fn serialized_url(url dom.URL) string {
	return url.serialize()
}

fn serialized_url_for_matching(url dom.URL) string {
	serialized := serialized_url(url)
	if url.scheme() == 'file' {
		return 'http://local-file.invalid/${serialized}'
	}
	return serialized
}

struct ContentBlockerNetworkRule {
	pattern          string
	exception        bool
	resource_types   []ContentBlockerResourceType
	party_constraint ?bool
	domains          []string
	excluded_domains []string
}

struct ContentBlockerCosmeticRule {
	domains          []string
	excluded_domains []string
	selector         string
	declaration      string
	exception        bool
}

fn line_looks_like_supported_cosmetic_rule(line string) bool {
	trimmed := line.trim_space()
	if trimmed == '' || trimmed.starts_with('!') || trimmed.starts_with('[') {
		return false
	}
	first_sharp := trimmed.index('#') or { return false }
	after_first := first_sharp + 1
	if after_first >= trimmed.len {
		return false
	}
	second_relative := trimmed[after_first..].index('#') or { return false }
	mut between := trimmed[after_first..after_first + second_relative]
	if between.starts_with('@') {
		if first_sharp == 0 {
			return false
		}
		between = between[1..]
	}
	if between.starts_with('?') {
		between = between[1..]
	}
	return between == ''
}

fn rules_contain_cosmetic_rules(rules []u8) bool {
	for line in rules.bytestr().split_into_lines() {
		if line_looks_like_supported_cosmetic_rule(line) {
			return true
		}
	}
	return false
}

fn parse_content_blocker_domains(input string) ([]string, []string) {
	mut domains := []string{}
	mut excluded := []string{}
	for raw_domain in input.split(',') {
		domain := raw_domain.trim_space().to_lower()
		if domain == '' {
			continue
		}
		if domain.starts_with('~') {
			if domain.len > 1 {
				excluded << domain[1..]
			}
		} else {
			domains << domain
		}
	}
	return domains, excluded
}

fn parse_cosmetic_rule(line string) ?ContentBlockerCosmeticRule {
	mut marker := '##'
	mut exception := false
	mut marker_index := line.index('#@#') or { -1 }
	if marker_index >= 0 {
		marker = '#@#'
		exception = true
	} else {
		marker_index = line.index('#?#') or { -1 }
		if marker_index >= 0 {
			marker = '#?#'
		} else {
			marker_index = line.index('##') or { return none }
		}
	}
	selector_text := line[marker_index + marker.len..].trim_space()
	if selector_text == '' {
		return none
	}
	domains, excluded_domains := parse_content_blocker_domains(line[..marker_index])
	mut selector := selector_text
	mut declaration := 'display: none !important;'
	style_index := selector_text.last_index(':style(') or { -1 }
	if style_index >= 0 && selector_text.ends_with(')') {
		selector = selector_text[..style_index].trim_space()
		declaration = selector_text[style_index + 7..selector_text.len - 1].trim_space()
		if declaration != '' && !declaration.ends_with(';') {
			declaration += ';'
		}
	}
	if selector == '' || declaration == '' {
		return none
	}
	return ContentBlockerCosmeticRule{
		domains: domains
		excluded_domains: excluded_domains
		selector: selector
		declaration: declaration
		exception: exception
	}
}

fn content_blocker_resource_type_from_name(name string) ?ContentBlockerResourceType {
	return match name {
		'document' { .document }
		'font' { .font }
		'image' { .image }
		'media' { .media }
		'object' { .object }
		'other' { .other }
		'ping' { .ping }
		'script' { .script }
		'stylesheet' { .stylesheet }
		'subdocument' { .subdocument }
		'websocket' { .websocket }
		'xmlhttprequest' { .xml_http_request }
		else { none }
	}
}

fn parse_network_rule(line string) ?ContentBlockerNetworkRule {
	mut text := line.trim_space()
	if text == '' || text.starts_with('!') || text.starts_with('[')
		|| line_looks_like_supported_cosmetic_rule(text) {
		return none
	}
	mut exception := false
	if text.starts_with('@@') {
		exception = true
		text = text[2..]
	}
	mut pattern := text
	mut option_text := ''
	if dollar := text.last_index('$') {
		pattern = text[..dollar]
		option_text = text[dollar + 1..]
	}
	if pattern == '' {
		return none
	}
	mut resource_types := []ContentBlockerResourceType{}
	mut party_constraint := ?bool(none)
	mut domains := []string{}
	mut excluded_domains := []string{}
	for raw_option in option_text.split(',') {
		option := raw_option.trim_space().to_lower()
		if option == 'third-party' {
			party_constraint = true
		} else if option == 'first-party' || option == '~third-party' {
			party_constraint = false
		} else if option.starts_with('domain=') {
			for raw_domain in option[7..].split('|') {
				domain := raw_domain.trim_space()
				if domain.starts_with('~') {
					excluded_domains << domain[1..]
				} else if domain != '' {
					domains << domain
				}
			}
		} else if resource_type := content_blocker_resource_type_from_name(option) {
			resource_types << resource_type
		}
	}
	return ContentBlockerNetworkRule{
		pattern: pattern
		exception: exception
		resource_types: resource_types
		party_constraint: party_constraint
		domains: domains
		excluded_domains: excluded_domains
	}
}

fn host_matches_domain(host string, domain string) bool {
	normalized_host := host.trim_right('.').to_lower()
	normalized_domain := domain.trim_right('.').to_lower()
	return normalized_host == normalized_domain || normalized_host.ends_with('.${normalized_domain}')
}

fn content_blocker_site(host string) string {
	normalized := host.trim_right('.').to_lower()
	return liburl.get_registrable_domain(normalized) or {
		parts := normalized.split('.')
		if parts.len >= 2 {
			parts[parts.len - 2..].join('.')
		} else {
			normalized
		}
	}
}

fn is_third_party(target dom.URL, source dom.URL) bool {
	target_host := target.host() or { return true }
	source_host := source.host() or { return true }
	return content_blocker_site(target_host) != content_blocker_site(source_host)
}

fn is_adblock_separator(character u8) bool {
	return !((character >= `a` && character <= `z`) || (character >= `A` && character <= `Z`)
		|| (character >= `0` && character <= `9`) || character in [`_`, `-`, `.`, `%`])
}

fn adblock_piece_matches_at(text string, start int, pattern string) bool {
	mut text_index := start
	mut pattern_index := 0
	for pattern_index < pattern.len {
		character := pattern[pattern_index]
		if character == `*` {
			for pattern_index < pattern.len && pattern[pattern_index] == `*` {
				pattern_index++
			}
			if pattern_index == pattern.len {
				return true
			}
			for candidate := text_index; candidate <= text.len; candidate++ {
				if adblock_piece_matches_at(text, candidate, pattern[pattern_index..]) {
					return true
				}
			}
			return false
		}
		if character == `^` {
			if text_index == text.len {
				text_index++
				pattern_index++
				continue
			}
			if !is_adblock_separator(text[text_index]) {
				return false
			}
			text_index++
			pattern_index++
			continue
		}
		if text_index >= text.len || text[text_index] != character {
			return false
		}
		text_index++
		pattern_index++
	}
	return true
}

fn adblock_pattern_matches(pattern string, url dom.URL, serialized string) bool {
	mut needle := pattern
	mut domain_anchor := false
	mut start_anchor := false
	mut end_anchor := false
	if needle.starts_with('||') {
		domain_anchor = true
		needle = needle[2..]
	} else if needle.starts_with('|') {
		start_anchor = true
		needle = needle[1..]
	}
	if needle.ends_with('|') {
		end_anchor = true
		needle = needle[..needle.len - 1]
	}
	if domain_anchor {
		mut domain_end := needle.len
		for index, character in needle.bytes() {
			if character in [`/`, `^`, `*`] {
				domain_end = index
				break
			}
		}
		domain := needle[..domain_end].to_lower()
		host := url.host() or { return false }
		if !host_matches_domain(host, domain) {
			return false
		}
		remainder := needle[domain_end..]
		if remainder == '' || remainder == '^' {
			return true
		}
		path_start := serialized.index('://') or { -3 }
		authority_start := path_start + 3
		path_relative := serialized[authority_start..].index('/') or { serialized.len - authority_start }
		path_index := authority_start + path_relative
		return adblock_piece_matches_at(serialized, path_index, remainder)
	}
	if start_anchor {
		if !adblock_piece_matches_at(serialized, 0, needle) {
			return false
		}
		return !end_anchor || needle.len == serialized.len
	}
	for index := 0; index <= serialized.len; index++ {
		if adblock_piece_matches_at(serialized, index, needle) {
			if !end_anchor || index + needle.len == serialized.len {
				return true
			}
		}
	}
	return false
}

fn domain_constraints_match(domains []string, excluded_domains []string, source_url dom.URL) bool {
	host := source_url.host() or { return domains.len == 0 }
	for domain in excluded_domains {
		if host_matches_domain(host, domain) {
			return false
		}
	}
	if domains.len == 0 {
		return true
	}
	for domain in domains {
		if host_matches_domain(host, domain) {
			return true
		}
	}
	return false
}

fn (rule &ContentBlockerNetworkRule) matches(url dom.URL, source_url dom.URL, resource_type ContentBlockerResourceType) bool {
	if rule.resource_types.len > 0 && resource_type !in rule.resource_types {
		return false
	}
	if constraint := rule.party_constraint {
		if is_third_party(url, source_url) != constraint {
			return false
		}
	}
	if !domain_constraints_match(rule.domains, rule.excluded_domains, source_url) {
		return false
	}
	return adblock_pattern_matches(rule.pattern, url, serialized_url_for_matching(url))
}

fn cosmetic_rule_applies_to_url(rule &ContentBlockerCosmeticRule, url dom.URL) bool {
	return domain_constraints_match(rule.domains, rule.excluded_domains, url)
}

fn simple_selector_hint_matches(selector string, classes []string, ids []string) bool {
	for arm_text in selector.split(',') {
		arm := arm_text.trim_space()
		if arm.starts_with('.') && !arm[1..].contains_any(' .#[:>+~') {
			if arm[1..] in classes {
				return true
			}
			continue
		}
		if arm.starts_with('#') && !arm[1..].contains_any(' .#[:>+~') {
			if arm[1..] in ids {
				return true
			}
			continue
		}
		return true
	}
	return false
}

pub struct ContentBlocker {
mut:
	filtering_enabled_  bool = true
	has_rules_          bool
	has_cosmetic_rules_ bool
	network_rules_      []ContentBlockerNetworkRule
	cosmetic_rules_     []ContentBlockerCosmeticRule
}

pub fn ContentBlocker.create() &ContentBlocker {
	return &ContentBlocker{}
}

pub fn ContentBlocker.the() &ContentBlocker {
	if loader_global_content_blocker == unsafe { nil } {
		// A lazy first lookup can happen while a navigation document owns
		// allocations. The shared blocker must survive that document.
		persistent := platform.enter_persistent()
		loader_global_content_blocker = ContentBlocker.create()
		platform.leave_persistent(persistent)
	}
	return loader_global_content_blocker
}

pub fn (blocker &ContentBlocker) has_rules() bool {
	return blocker.has_rules_
}

pub fn (blocker &ContentBlocker) has_cosmetic_rules() bool {
	return blocker.has_cosmetic_rules_
}

pub fn (blocker &ContentBlocker) filtering_enabled() bool {
	return blocker.filtering_enabled_
}

pub fn (mut blocker ContentBlocker) set_filtering_enabled(enabled bool) {
	blocker.filtering_enabled_ = enabled
}

pub fn (mut blocker ContentBlocker) set_patterns(patterns []string) ! {
	mut lines := []string{}
	for pattern in patterns {
		if pattern != '' {
			lines << pattern
		}
	}
	mut serialized := lines.join('\n')
	if serialized != '' {
		serialized += '\n'
	}
	blocker.set_rules_from_bytes(serialized.bytes())!
}

pub fn (mut blocker ContentBlocker) set_rules_from_bytes(rules_bytes []u8) ! {
	if rules_bytes.len == 0 {
		blocker.has_rules_ = false
		blocker.has_cosmetic_rules_ = false
		blocker.network_rules_.clear()
		blocker.cosmetic_rules_.clear()
		return
	}
	if !utf8.validate(rules_bytes.data, rules_bytes.len) {
		return error('Failed to create content blocker')
	}
	mut network_rules := []ContentBlockerNetworkRule{}
	mut cosmetic_rules := []ContentBlockerCosmeticRule{}
	for line in rules_bytes.bytestr().split_into_lines() {
		if cosmetic_rule := parse_cosmetic_rule(line.trim_space()) {
			cosmetic_rules << cosmetic_rule
		} else if network_rule := parse_network_rule(line) {
			network_rules << network_rule
		}
	}
	blocker.network_rules_ = network_rules
	blocker.cosmetic_rules_ = cosmetic_rules
	blocker.has_rules_ = true
	blocker.has_cosmetic_rules_ = rules_contain_cosmetic_rules(rules_bytes)
}

pub fn (blocker &ContentBlocker) is_filtered(url dom.URL) bool {
	return blocker.is_filtered_for_resource(url, url, .other)
}

// Translation of the C++ resource-type is_filtered overload.
pub fn (blocker &ContentBlocker) is_filtered_for_resource(url dom.URL, source_url dom.URL, resource_type ContentBlockerResourceType) bool {
	if !blocker.filtering_enabled() || !blocker.has_rules() || url.scheme() == 'data' {
		return false
	}
	normalized_source_url := ContentBlocker.source_url_for_matching(source_url)
	mut blocked := false
	for rule in blocker.network_rules_ {
		if rule.matches(url, normalized_source_url, resource_type) {
			if rule.exception {
				return false
			}
			blocked = true
		}
	}
	return blocked
}

// Translation of the C++ fetch-metadata is_filtered overload.
pub fn (blocker &ContentBlocker) is_filtered_with_metadata(url dom.URL, source_url dom.URL, destination ?fetch.Destination, initiator_type ?fetch.InitiatorType, mode fetch.Mode) bool {
	return blocker.is_filtered_for_resource(url, ContentBlocker.source_url_for_matching(source_url),
		ContentBlocker.resource_type_from_fetch_metadata(destination, initiator_type, mode))
}

pub fn (blocker &ContentBlocker) cosmetic_style_sheet_for_url(url dom.URL, classes []string, ids []string) string {
	if !blocker.filtering_enabled() || !blocker.has_rules() || !blocker.has_cosmetic_rules() {
		return ''
	}
	mut exceptions := []string{}
	for rule in blocker.cosmetic_rules_ {
		if rule.exception && cosmetic_rule_applies_to_url(&rule, url) {
			exceptions << rule.selector
		}
	}
	mut lines := []string{}
	for rule in blocker.cosmetic_rules_ {
		if rule.exception || rule.selector in exceptions || !cosmetic_rule_applies_to_url(&rule, url) {
			continue
		}
		if rule.domains.len == 0 && !simple_selector_hint_matches(rule.selector, classes, ids) {
			continue
		}
		lines << '${rule.selector} { ${rule.declaration} }'
	}
	return lines.join('\n')
}

pub fn (blocker &ContentBlocker) cosmetic_style_sheet(url dom.URL) string {
	return blocker.cosmetic_style_sheet_for_url(url, [], [])
}

pub fn (blocker &ContentBlocker) has_generic_cosmetic_selectors_for_url(url dom.URL, classes []string, ids []string) bool {
	if !blocker.filtering_enabled() || !blocker.has_rules() || !blocker.has_cosmetic_rules() {
		return false
	}
	for rule in blocker.cosmetic_rules_ {
		if !rule.exception && rule.domains.len == 0 && cosmetic_rule_applies_to_url(&rule, url)
			&& simple_selector_hint_matches(rule.selector, classes, ids) {
			return true
		}
	}
	return false
}

pub fn ContentBlocker.resource_type_from_fetch_metadata(destination ?fetch.Destination, initiator_type ?fetch.InitiatorType, mode fetch.Mode) ContentBlockerResourceType {
	if mode == .websocket {
		return .websocket
	}
	if value := destination {
		return match value {
			.audio, .track, .video { .media }
			.document { .document }
			.embed, .object { .object }
			.font { .font }
			.frame, .iframe { .subdocument }
			.image { .image }
			.audio_worklet, .paint_worklet, .script, .service_worker, .shared_worker, .worker { .script }
			.style { .stylesheet }
			else { .other }
		}
	}
	if value := initiator_type {
		return match value {
			.audio, .video, .track { .media }
			.beacon, .ping { .ping }
			.embed, .object { .object }
			.fetch, .xml_http_request { .xml_http_request }
			.font { .font }
			.frame, .iframe { .subdocument }
			.image, .img { .image }
			.script { .script }
			.css { .stylesheet }
			else { .other }
		}
	}
	return .other
}

pub fn ContentBlocker.source_url_for_matching(source_url dom.URL) dom.URL {
	if source_url.scheme() != 'blob' {
		return source_url
	}
	return dom.dom_url_parse(source_url.serialize_path(), dom.url_about_blank(), 'UTF-8') or {
		source_url
	}
}
