// Copyright (c) 2025-2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of LibURL/Pattern/Pattern.cpp and LibWeb/URLPattern/URLPattern.cpp.
module urlpattern

import url as liburl

pub struct URLPatternInit {
pub:
	protocol ?string
	username ?string
	password ?string
	hostname ?string
	port     ?string
	pathname ?string
	search   ?string
	hash     ?string
	base_url ?string
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

pub struct URLPatternExecResult {
pub:
	matched bool
	result  URLPatternResult
}

@[heap]
pub struct URLPattern {
	protocol_component CompiledPatternComponent
	username_component CompiledPatternComponent
	password_component CompiledPatternComponent
	hostname_component CompiledPatternComponent
	port_component     CompiledPatternComponent
	pathname_component CompiledPatternComponent
	search_component   CompiledPatternComponent
	hash_component     CompiledPatternComponent
}

pub fn URLPattern.new(input URLPatternInput, base_url ?string, options URLPatternOptions) !&URLPattern {
	return URLPattern.construct_impl(input, base_url, options)
}

pub fn URLPattern.construct_impl(input URLPatternInput, base_url ?string, options URLPatternOptions) !&URLPattern {
	return URLPattern.create(input, base_url, options)
}

// https://urlpattern.spec.whatwg.org/#url-pattern-create
pub fn URLPattern.create(input URLPatternInput, base_url ?string, options URLPatternOptions) !&URLPattern {
	mut init := PatternInitRecord{}
	match input {
		string {
			init = parse_constructor_string(input)!
			if base_url == none && init.protocol == none {
				return error('TypeError: relative URLPattern constructor must provide one of baseURL or protocol')
			}
			if value := base_url {
				init.base_url = value
			}
		}
		URLPatternInit {
			if base_url != none {
				return error('TypeError: constructor with URLPatternInit must not provide baseURL')
			}
			init = pattern_init_record(input)
		}
	}
	mut processed := process_url_pattern_init(init, .pattern, none, none, none, none, none, none, none, none)!
	if processed.protocol == none {
		processed.protocol = '*'
	}
	if processed.username == none {
		processed.username = '*'
	}
	if processed.password == none {
		processed.password = '*'
	}
	if processed.hostname == none {
		processed.hostname = '*'
	}
	if processed.port == none {
		processed.port = '*'
	}
	if processed.pathname == none {
		processed.pathname = '*'
	}
	if processed.search == none {
		processed.search = '*'
	}
	if processed.hash == none {
		processed.hash = '*'
	}
	protocol_string := processed.protocol or { '*' }
	mut port_string := processed.port or { '*' }
	if liburl.is_special_scheme(protocol_string) {
		if default_port := liburl.default_port_for_scheme(protocol_string) {
			if port_string == default_port.str() {
				port_string = ''
			}
		}
	}
	protocol_component := compile_pattern_component(protocol_string, .protocol, default_pattern_options())!
	username_component := compile_pattern_component(processed.username or { '*' }, .username, default_pattern_options())!
	password_component := compile_pattern_component(processed.password or { '*' }, .password, default_pattern_options())!
	hostname_string := processed.hostname or { '*' }
	hostname_component := compile_pattern_component(hostname_string, if hostname_pattern_is_ipv6_address(hostname_string) {
		PatternCanonicalization.ipv6_hostname
	} else {
		PatternCanonicalization.hostname
	}, hostname_pattern_options())!
	port_component := compile_pattern_component(port_string, .port, default_pattern_options())!
	case_options := PatternCompileOptions{
		ignore_case: options.ignore_case
	}
	pathname_component := if protocol_component_matches_special_scheme(&protocol_component) {
		compile_pattern_component(processed.pathname or { '*' }, .pathname, pathname_pattern_options(options.ignore_case))!
	} else {
		compile_pattern_component(processed.pathname or { '*' }, .opaque_pathname, case_options)!
	}
	search_component := compile_pattern_component(processed.search or { '*' }, .search, case_options)!
	hash_component := compile_pattern_component(processed.hash or { '*' }, .hash, case_options)!
	return &URLPattern{
		protocol_component: protocol_component
		username_component: username_component
		password_component: password_component
		hostname_component: hostname_component
		port_component: port_component
		pathname_component: pathname_component
		search_component: search_component
		hash_component: hash_component
	}
}

fn pattern_init_record(input URLPatternInit) PatternInitRecord {
	return PatternInitRecord{
		protocol: input.protocol
		username: input.username
		password: input.password
		hostname: input.hostname
		port: input.port
		pathname: input.pathname
		search: input.search
		hash: input.hash
		base_url: input.base_url
	}
}

pub fn (pattern &URLPattern) protocol() string {
	return pattern.protocol_component.pattern_string
}

pub fn (pattern &URLPattern) username() string {
	return pattern.username_component.pattern_string
}

pub fn (pattern &URLPattern) password() string {
	return pattern.password_component.pattern_string
}

pub fn (pattern &URLPattern) hostname() string {
	return pattern.hostname_component.pattern_string
}

pub fn (pattern &URLPattern) port() string {
	return pattern.port_component.pattern_string
}

pub fn (pattern &URLPattern) pathname() string {
	return pattern.pathname_component.pattern_string
}

pub fn (pattern &URLPattern) search() string {
	return pattern.search_component.pattern_string
}

pub fn (pattern &URLPattern) hash() string {
	return pattern.hash_component.pattern_string
}

pub fn (pattern &URLPattern) has_reg_exp_groups() bool {
	return pattern.protocol_component.has_regexp_groups || pattern.username_component.has_regexp_groups || pattern.password_component.has_regexp_groups || pattern.hostname_component.has_regexp_groups || pattern.port_component.has_regexp_groups || pattern.pathname_component.has_regexp_groups || pattern.search_component.has_regexp_groups || pattern.hash_component.has_regexp_groups
}

struct URLPatternMatchInput {
	valid      bool
	inputs     []URLPatternInput
	components PatternInitRecord
}

fn prepare_url_pattern_match_input(input URLPatternInput, base_url ?string) !URLPatternMatchInput {
	mut inputs := []URLPatternInput{}
	inputs << input
	match input {
		URLPatternInit {
			if base_url != none {
				return error('TypeError: base URL cannot be provided with URLPatternInit')
			}
			components := process_url_pattern_init(pattern_init_record(input), .url, '', '', '', '', '', '', '', '') or { return URLPatternMatchInput{} }
			return URLPatternMatchInput{
				valid: true
				inputs: inputs
				components: components
			}
		}
		string {
			mut parsed_base := ?liburl.URL(none)
			if base_url_string := base_url {
				parsed_base = liburl.parse(base_url_string) or { return URLPatternMatchInput{} }
				inputs << URLPatternInput(base_url_string)
			}
			parsed := if base := parsed_base {
				liburl.parse_with_base(input, &base) or { return URLPatternMatchInput{} }
			} else {
				liburl.parse(input) or { return URLPatternMatchInput{} }
			}
			hostname := if host_record := parsed.host { host_record.serialize() } else { '' }
			return URLPatternMatchInput{
				valid: true
				inputs: inputs
				components: PatternInitRecord{
					protocol: parsed.scheme
					username: parsed.username
					password: parsed.password
					hostname: hostname
					port: if parsed_port := parsed.port { parsed_port.str() } else { '' }
					pathname: parsed.serialize_path()
					search: parsed.query or { '' }
					hash: parsed.fragment or { '' }
				}
			}
		}
	}
}

pub fn (pattern &URLPattern) test(input URLPatternInput, base_url ?string) !bool {
	prepared := prepare_url_pattern_match_input(input, base_url)!
	if !prepared.valid {
		return false
	}
	return pattern.match_components(prepared.components) != none
}

pub fn (pattern &URLPattern) exec(input URLPatternInput, base_url ?string) !URLPatternExecResult {
	prepared := prepare_url_pattern_match_input(input, base_url)!
	if !prepared.valid {
		return URLPatternExecResult{}
	}
	matches := pattern.match_components(prepared.components) or { return URLPatternExecResult{} }
	return URLPatternExecResult{
		matched: true
		result: URLPatternResult{
			inputs: prepared.inputs
			protocol: component_result(matches[0])
			username: component_result(matches[1])
			password: component_result(matches[2])
			hostname: component_result(matches[3])
			port: component_result(matches[4])
			pathname: component_result(matches[5])
			search: component_result(matches[6])
			hash: component_result(matches[7])
		}
	}
}

fn (pattern &URLPattern) match_components(components PatternInitRecord) ?[]PatternComponentMatch {
	values := [components.protocol or { '' }, components.username or { '' },
		components.password or { '' }, components.hostname or { '' }, components.port or { '' },
		components.pathname or { '' }, components.search or { '' }, components.hash or { '' }]
	compiled := [&pattern.protocol_component, &pattern.username_component,
		&pattern.password_component, &pattern.hostname_component, &pattern.port_component,
		&pattern.pathname_component, &pattern.search_component, &pattern.hash_component]
	mut matches := []PatternComponentMatch{cap: 8}
	for index, component in compiled {
		matches << component.match(values[index]) or { return none }
	}
	return matches
}

fn component_result(value PatternComponentMatch) URLPatternComponentResult {
	return URLPatternComponentResult{
		input: value.input
		groups: value.groups
	}
}
