// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Loader/SiteCompatibility.{h,cpp}.
module loader

import dom
import urlpattern
import x.json2

pub enum UserAgentTransformation {
	hide_ladybird
}

fn parse_patterns(object map[string]json2.Any) ![]string {
	value := object['matches'] or {
		return error("Site-compatibility rule must contain a non-empty 'matches' array")
	}
	if value !is []json2.Any {
		return error("Site-compatibility rule must contain a non-empty 'matches' array")
	}
	items := value as []json2.Any
	if items.len == 0 {
		return error("Site-compatibility rule must contain a non-empty 'matches' array")
	}
	mut result := []string{cap: items.len}
	for pattern in items {
		if pattern !is string {
			return error('Site-compatibility rule patterns must be non-empty strings')
		}
		text := pattern as string
		if text == '' {
			return error('Site-compatibility rule patterns must be non-empty strings')
		}
		result << text
	}
	return result
}

fn parse_user_agent_transformations(object map[string]json2.Any) ![]UserAgentTransformation {
	value := object['user_agent'] or { return []UserAgentTransformation{} }
	if value !is []json2.Any {
		return error("Site-compatibility rule 'user_agent' must be a non-empty array")
	}
	items := value as []json2.Any
	if items.len == 0 {
		return error("Site-compatibility rule 'user_agent' must be a non-empty array")
	}
	mut result := []UserAgentTransformation{cap: items.len}
	for transformation in items {
		if transformation !is string {
			return error('User-Agent transformations must be strings')
		}
		name := transformation as string
		if name != 'hide_Ladybird' {
			return error('Unknown User-Agent transformation')
		}
		result << .hide_ladybird
	}
	return result
}

fn parse_exposed_interfaces(object map[string]json2.Any) ![]string {
	value := object['expose_experimental_interfaces'] or { return []string{} }
	if value !is []json2.Any {
		return error("Site-compatibility rule 'expose_experimental_interfaces' must be a non-empty array")
	}
	items := value as []json2.Any
	if items.len == 0 {
		return error("Site-compatibility rule 'expose_experimental_interfaces' must be a non-empty array")
	}
	mut result := []string{cap: items.len}
	for name in items {
		if name !is string {
			return error("Site-compatibility rule 'expose_experimental_interfaces' entries must be non-empty strings")
		}
		text := name as string
		if text == '' {
			return error("Site-compatibility rule 'expose_experimental_interfaces' entries must be non-empty strings")
		}
		result << text
	}
	return result
}

pub struct SiteCompatibilityRule {
mut:
	patterns_                   []string
	compiled_patterns_          []&urlpattern.URLPattern
	user_agent_transformations_ []UserAgentTransformation
	exposed_interfaces_         []string
}

pub fn SiteCompatibilityRule.from_json(value json2.Any) !SiteCompatibilityRule {
	if value !is map[string]json2.Any {
		return error('Site-compatibility rule must be a JSON object')
	}
	object := value as map[string]json2.Any
	transformations := parse_user_agent_transformations(object)!
	exposed_interfaces := parse_exposed_interfaces(object)!
	if transformations.len == 0 && exposed_interfaces.len == 0 {
		return error("Site-compatibility rule must contain a 'user_agent' or an 'expose_experimental_interfaces' array")
	}
	return SiteCompatibilityRule.create(parse_patterns(object)!, transformations, exposed_interfaces)
}

pub fn SiteCompatibilityRule.create(patterns []string, transformations []UserAgentTransformation, exposed_interfaces []string) !SiteCompatibilityRule {
	mut compiled_patterns := []&urlpattern.URLPattern{cap: patterns.len}
	for pattern in patterns {
		compiled := urlpattern.URLPattern.create(pattern, none, urlpattern.URLPatternOptions{}) or {
			return error('Site-compatibility rule contains an invalid URL pattern')
		}
		compiled_patterns << compiled
	}
	return SiteCompatibilityRule{
		patterns_:                   patterns.clone()
		compiled_patterns_:          compiled_patterns
		user_agent_transformations_: transformations.clone()
		exposed_interfaces_:         exposed_interfaces.clone()
	}
}

pub fn (rule &SiteCompatibilityRule) patterns() []string {
	return rule.patterns_.clone()
}

pub fn (rule &SiteCompatibilityRule) user_agent_transformations() []UserAgentTransformation {
	return rule.user_agent_transformations_.clone()
}

pub fn (rule &SiteCompatibilityRule) exposed_interfaces() []string {
	return rule.exposed_interfaces_.clone()
}

pub fn (rule &SiteCompatibilityRule) exposes_experimental_interface(name string) bool {
	return name in rule.exposed_interfaces_
}

pub fn (rule &SiteCompatibilityRule) matches(url dom.URL) bool {
	serialized := url.serialize()
	for pattern in rule.compiled_patterns_ {
		if pattern.test(serialized, none) or { false } {
			return true
		}
	}
	return false
}

fn remove_ladybird_product(user_agent string) string {
	mut products := []string{}
	for product in user_agent.split(' ') {
		if product.starts_with('Ladybird/') {
			continue
		}
		products << product
	}
	return products.join(' ')
}

pub fn (rule &SiteCompatibilityRule) apply_user_agent_transformations(user_agent string) string {
	mut transformed := user_agent
	for transformation in rule.user_agent_transformations_ {
		match transformation {
			.hide_ladybird { transformed = remove_ladybird_product(transformed) }
		}
	}
	return transformed
}

pub struct SiteCompatibilityData {
mut:
	rules_ []SiteCompatibilityRule
}

// WebCompat/twitch.tv.json: Twitch's desktop routing rejects the Ladybird
// product token. Restrict this override to its HTTPS origin and subdomains.
pub fn default_site_compatibility_data() SiteCompatibilityData {
	mut data := SiteCompatibilityData{}
	data.add_rule(SiteCompatibilityRule.create([
		'https://twitch.tv/*',
		'https://*.twitch.tv/*',
	], [.hide_ladybird], []) or { panic('Invalid built-in Twitch compatibility rule: ${err}') })
	return data
}

pub fn SiteCompatibilityData.from_json(value json2.Any) !SiteCompatibilityData {
	if value !is []json2.Any {
		return error('Site-compatibility data must be a JSON array')
	}
	mut data := SiteCompatibilityData{}
	for rule in value as []json2.Any {
		data.add_rule(SiteCompatibilityRule.from_json(rule)!)
	}
	return data
}

pub fn (mut data SiteCompatibilityData) add_rule(rule SiteCompatibilityRule) {
	data.rules_ << rule
}

pub fn (data &SiteCompatibilityData) rules() []SiteCompatibilityRule {
	return data.rules_.clone()
}

pub fn (data &SiteCompatibilityData) user_agent_for_url(url dom.URL, default_user_agent string) string {
	mut user_agent := default_user_agent
	for rule in data.rules_ {
		if rule.matches(url) {
			user_agent = rule.apply_user_agent_transformations(user_agent)
		}
	}
	return user_agent
}

pub fn (data &SiteCompatibilityData) user_agent_for_websocket_url(url dom.URL, default_user_agent string) string {
	http_url := match url.scheme() {
		'ws' { url.with_protocol('http') }
		'wss' { url.with_protocol('https') }
		else { url }
	}
	return data.user_agent_for_url(http_url, default_user_agent)
}

pub fn (data &SiteCompatibilityData) exposes_experimental_interface(url dom.URL, name string) bool {
	for rule in data.rules_ {
		if rule.exposes_experimental_interface(name) && rule.matches(url) {
			return true
		}
	}
	return false
}
