// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of URLPattern/URLPattern.{h,cpp,idl}. Pattern token compilation
// in upstream LibURL is represented here by deterministic component matching;
// URL parsing remains the standard-library boundary.
module urlpattern

import net.urllib

pub struct URLPatternInit {
pub:
	protocol string
	username string
	password string
	hostname string
	port     string
	pathname string
	search   string
	hash     string
	base_url string
}

pub type URLPatternInput = URLPatternInit | string

pub struct URLPatternOptions {
pub:
	ignore_case bool
}

pub struct URLPatternComponentResult {
pub:
	input  string
	groups map[string]string
}

pub struct URLPatternResult {
pub:
	inputs   []URLPatternInput
	protocol URLPatternComponentResult
	username URLPatternComponentResult
	password URLPatternComponentResult
	hostname URLPatternComponentResult
	port     URLPatternComponentResult
	pathname URLPatternComponentResult
	search   URLPatternComponentResult
	hash     URLPatternComponentResult
}

// WebIDL's nullable URLPatternResult needs to coexist with parsing exceptions.
// V does not combine option and result return types, so this record preserves
// the null-vs-match distinction while `!` remains available for TypeError.
pub struct URLPatternExecResult {
pub:
	matched bool
	result  URLPatternResult
}

struct PatternComponents {
	protocol string = '*'
	username string = '*'
	password string = '*'
	hostname string = '*'
	port     string = '*'
	pathname string = '*'
	search   string = '*'
	hash     string = '*'
}

@[heap]
pub struct URLPattern {
pub:
	ignore_case bool
mut:
	components PatternComponents
}

pub fn URLPattern.new(input URLPatternInput, base_url ?string, options URLPatternOptions) !&URLPattern {
	components := components_from_input(input, base_url)!
	return &URLPattern{
		ignore_case: options.ignore_case
		components:  components
	}
}

fn components_from_input(input URLPatternInput, base_url ?string) !PatternComponents {
	match input {
		string {
			parsed := parse_url_reference(input, base_url)!
			return components_from_url(parsed)
		}
		URLPatternInit {
			selected_base := if input.base_url != '' { ?string(input.base_url) } else { base_url }
			mut defaults := PatternComponents{}
			if base := selected_base {
				defaults = components_from_url(urllib.parse(base)!)
			}
			return PatternComponents{
				protocol: value_or(input.protocol, defaults.protocol)
				username: value_or(input.username, defaults.username)
				password: value_or(input.password, defaults.password)
				hostname: value_or(input.hostname, defaults.hostname)
				port:     value_or(input.port, defaults.port)
				pathname: value_or(input.pathname, defaults.pathname)
				search:   value_or(input.search, defaults.search)
				hash:     value_or(input.hash, defaults.hash)
			}
		}
	}
}

fn value_or(value string, fallback string) string {
	return if value == '' { fallback } else { value }
}

fn parse_url_reference(raw string, base_url ?string) !urllib.URL {
	reference := urllib.parse(raw)!
	if reference.is_abs() {
		return reference
	}
	base := base_url or { return error('TypeError: a relative URLPattern string requires baseURL') }
	parsed_base := urllib.parse(base)!
	return parsed_base.resolve_reference(reference)!
}

fn components_from_url(url urllib.URL) PatternComponents {
	mut username := ''
	mut password := ''
	if user := url.user {
		username = user.username
		if user.password_set {
			password = user.password
		}
	}
	return PatternComponents{
		protocol: url.scheme
		username: username
		password: password
		hostname: url.hostname()
		port:     url.port()
		pathname: url.path
		search:   url.raw_query
		hash:     url.fragment
	}
}

pub fn (pattern &URLPattern) protocol() string {
	return pattern.components.protocol
}

pub fn (pattern &URLPattern) username() string {
	return pattern.components.username
}

pub fn (pattern &URLPattern) password() string {
	return pattern.components.password
}

pub fn (pattern &URLPattern) hostname() string {
	return pattern.components.hostname
}

pub fn (pattern &URLPattern) port() string {
	return pattern.components.port
}

pub fn (pattern &URLPattern) pathname() string {
	return pattern.components.pathname
}

pub fn (pattern &URLPattern) search() string {
	return pattern.components.search
}

pub fn (pattern &URLPattern) hash() string {
	return pattern.components.hash
}

pub fn (pattern &URLPattern) has_reg_exp_groups() bool {
	for component in pattern.pattern_component_values() {
		if component.contains('(') || component.contains(')') {
			return true
		}
	}
	return false
}

fn (pattern &URLPattern) pattern_component_values() []string {
	return [pattern.protocol(), pattern.username(), pattern.password(),
		pattern.hostname(), pattern.port(), pattern.pathname(),
		pattern.search(), pattern.hash()]
}

pub fn (pattern &URLPattern) test(input URLPatternInput, base_url ?string) !bool {
	candidate := components_from_input(input, base_url)!
	patterns := pattern.pattern_component_values()
	values := [candidate.protocol, candidate.username, candidate.password, candidate.hostname,
		candidate.port, candidate.pathname, candidate.search, candidate.hash]
	for index, component_pattern in patterns {
		match_component(component_pattern, values[index], pattern.ignore_case) or { return false }
	}
	return true
}

pub fn (pattern &URLPattern) exec(input URLPatternInput, base_url ?string) !URLPatternExecResult {
	candidate := components_from_input(input, base_url)!
	mut results := []URLPatternComponentResult{cap: 8}
	patterns := pattern.pattern_component_values()
	values := [candidate.protocol, candidate.username, candidate.password, candidate.hostname,
		candidate.port, candidate.pathname, candidate.search, candidate.hash]
	for index, component_pattern in patterns {
		result := match_component(component_pattern, values[index], pattern.ignore_case) or {
			return URLPatternExecResult{}
		}
		results << result
	}
	return URLPatternExecResult{
		matched: true
		result:  URLPatternResult{
			inputs:   [input]
			protocol: results[0]
			username: results[1]
			password: results[2]
			hostname: results[3]
			port:     results[4]
			pathname: results[5]
			search:   results[6]
			hash:     results[7]
		}
	}
}

// match_component supports URLPattern's common literal, wildcard and named
// segment forms. Parenthesized regexp tokens are retained/reflected but native
// regexp execution is deliberately outside this package.
fn match_component(raw_pattern string, raw_input string, ignore_case bool) ?URLPatternComponentResult {
	component_pattern := if ignore_case { raw_pattern.to_lower_ascii() } else { raw_pattern }
	input := if ignore_case { raw_input.to_lower_ascii() } else { raw_input }
	mut groups := map[string]string{}
	if component_pattern == '*' {
		groups['0'] = raw_input
		return URLPatternComponentResult{
			input:  raw_input
			groups: groups
		}
	}
	pattern_segments := component_pattern.split('/')
	input_segments := input.split('/')
	if pattern_segments.len == input_segments.len {
		mut matched := true
		for index, segment in pattern_segments {
			if segment.starts_with(':') && segment.len > 1 {
				groups[segment[1..]] = raw_input.split('/')[index]
			} else if !glob_match(segment, input_segments[index]) {
				matched = false
				break
			}
		}
		if matched {
			return URLPatternComponentResult{
				input:  raw_input
				groups: groups
			}
		}
	}
	if glob_match(component_pattern, input) {
		return URLPatternComponentResult{
			input:  raw_input
			groups: groups
		}
	}
	return none
}

fn glob_match(pattern string, input string) bool {
	mut pattern_index := 0
	mut input_index := 0
	mut star_index := -1
	mut retry_input := 0
	for input_index < input.len {
		if pattern_index < pattern.len && pattern[pattern_index] == input[input_index] {
			pattern_index++
			input_index++
		} else if pattern_index < pattern.len && pattern[pattern_index] == `*` {
			star_index = pattern_index
			pattern_index++
			retry_input = input_index
		} else if star_index >= 0 {
			pattern_index = star_index + 1
			retry_input++
			input_index = retry_input
		} else {
			return false
		}
	}
	for pattern_index < pattern.len && pattern[pattern_index] == `*` {
		pattern_index++
	}
	return pattern_index == pattern.len
}
