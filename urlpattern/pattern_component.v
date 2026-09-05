// Copyright (c) 2025-2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of LibURL/Pattern/Component.cpp.
module urlpattern

import regex.pcre

struct CompiledPatternComponent {
	pattern_string     string
	regular_expression pcre.Regex
	group_name_list    []string
	has_regexp_groups  bool
}

struct PatternComponentMatch {
	input  string
	groups map[string]string
}

fn compile_pattern_component(input string, canonicalization PatternCanonicalization, options PatternCompileOptions) !CompiledPatternComponent {
	parts := parse_pattern_string(input, options, canonicalization)!
	for part in parts {
		if part.type_ == .regexp {
			validate_urlpattern_regexp(part.value)!
		}
	}
	generated := generate_regular_expression_and_names(parts, options)
	regular_expression_string := if options.ignore_case {
		'(?i)' + generated.expression
	} else {
		generated.expression
	}
	regular_expression := pcre.compile(regular_expression_string) or {
		return error('TypeError: RegExp compile error: ${err}')
	}
	mut has_regexp_groups := false
	for part in parts {
		if part.type_ == .regexp {
			has_regexp_groups = true
			break
		}
	}
	return CompiledPatternComponent{
		pattern_string: generate_pattern_string(parts, options)
		regular_expression: regular_expression
		group_name_list: generated.names
		has_regexp_groups: has_regexp_groups
	}
}

// LibJS compiles URLPattern expressions with the Unicode-sets (`v`) flag. In
// that grammar an arbitrary identity escape such as `\m` is a syntax error;
// regex.pcre is intentionally more permissive, so preserve the upstream
// validation before handing the translated expression to the host VM.
fn validate_urlpattern_regexp(value string) ! {
	mut index := 0
	mut in_character_class := false
	for index < value.len {
		character := value[index]
		if character == `[` {
			in_character_class = true
			index++
			continue
		}
		if character == `]` {
			in_character_class = false
			index++
			continue
		}
		if character != `\\` {
			index++
			continue
		}
		index++
		if index >= value.len {
			return error('TypeError: RegExp compile error: trailing escape')
		}
		escaped := value[index]
		if escaped in [`d`, `D`, `s`, `S`, `w`, `W`, `f`, `n`, `r`, `t`, `v`, `c`, `x`, `u`, `p`,
			`P`, `k`, `b`, `B`, `0`, `^`, `$`, `\\`, `.`, `*`, `+`, `?`, `(`, `)`, `[`, `]`, `{`,
			`}`, `|`, `/`] || (in_character_class && escaped == `-`) {
			index++
			continue
		}
		return error('TypeError: RegExp compile error: invalid escape `\\${escaped.ascii_str()}`')
	}
}

struct GeneratedPatternRegexp {
	expression string
	names      []string
}

fn generate_regular_expression_and_names(parts []PatternPart, options PatternCompileOptions) GeneratedPatternRegexp {
	mut result := '^'
	mut names := []string{}
	for part in parts {
		if part.type_ == .fixed_text {
			if part.modifier == .none {
				result += escape_regexp_string(part.value)
			} else {
				result += '(?:' + escape_regexp_string(part.value) + ')' + part.modifier.serialize()
			}
			continue
		}
		names << part.name
		mut regexp_value := part.value
		if part.type_ == .segment_wildcard {
			regexp_value = generate_segment_wildcard_regexp(options)
		} else if part.type_ == .full_wildcard {
			regexp_value = full_wildcard_regexp_value
		}
		if part.prefix == '' && part.suffix == '' {
			if part.modifier in [.none, .optional] {
				result += '(' + regexp_value + ')' + part.modifier.serialize()
			} else {
				result += '((?:' + regexp_value + ')' + part.modifier.serialize() + ')'
			}
			continue
		}
		if part.modifier in [.none, .optional] {
			result += '(?:' + escape_regexp_string(part.prefix) + '(' + regexp_value + ')'
			result += escape_regexp_string(part.suffix) + ')' + part.modifier.serialize()
			continue
		}
		result += '(?:' + escape_regexp_string(part.prefix) + '((?:' + regexp_value + ')(?:'
		result += escape_regexp_string(part.suffix) + escape_regexp_string(part.prefix)
		result += '(?:' + regexp_value + '))*)' + escape_regexp_string(part.suffix) + ')'
		if part.modifier == .zero_or_more {
			result += '?'
		}
	}
	return GeneratedPatternRegexp{
		expression: result + '\$'
		names: names
	}
}

fn (component &CompiledPatternComponent) match(input string) ?PatternComponentMatch {
	match_result := component.regular_expression.find(input) or { return none }
	mut groups := map[string]string{}
	for index, name in component.group_name_list {
		groups[name] = if index < match_result.groups.len { match_result.groups[index] } else { '' }
	}
	return PatternComponentMatch{
		input: input
		groups: groups
	}
}

fn protocol_component_matches_special_scheme(component &CompiledPatternComponent) bool {
	for scheme in ['ftp', 'file', 'http', 'https', 'ws', 'wss'] {
		if component.match(scheme) != none {
			return true
		}
	}
	return false
}
