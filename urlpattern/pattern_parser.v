// Copyright (c) 2025-2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of LibURL/Pattern/PatternParser.cpp and String.cpp.
module urlpattern

struct PatternParser {
	canonicalization        PatternCanonicalization
	segment_wildcard_regexp string
mut:
	token_list          []PatternToken
	part_list           []PatternPart
	pending_fixed_value string
	index               int
	next_numeric_name   int
}

fn parse_pattern_string(input string, options PatternCompileOptions, canonicalization PatternCanonicalization) ![]PatternPart {
	mut parser := PatternParser{
		canonicalization: canonicalization
		segment_wildcard_regexp: generate_segment_wildcard_regexp(options)
		token_list: tokenize_pattern(input, .strict)!
	}
	for parser.index < parser.token_list.len {
		mut char_token := parser.try_consume_token(.char_)
		mut name_token := parser.try_consume_token(.name)
		mut regexp_or_wildcard_token := parser.try_consume_regexp_or_wildcard_token(name_token)
		if name_token != none || regexp_or_wildcard_token != none {
			mut prefix := ''
			if token := char_token {
				prefix = token.value
			}
			if prefix != '' && (options.prefix_code_point == none || prefix != (options.prefix_code_point or { `\0` }).str()) {
				parser.pending_fixed_value += prefix
				prefix = ''
			}
			parser.maybe_add_pending_fixed_value()!
			modifier_token := parser.try_consume_modifier_token()
			parser.add_part(prefix, name_token, regexp_or_wildcard_token, '', modifier_token)!
			continue
		}
		mut fixed_token := char_token
		if fixed_token == none {
			fixed_token = parser.try_consume_token(.escaped_char)
		}
		if token := fixed_token {
			parser.pending_fixed_value += token.value
			continue
		}
		if parser.try_consume_token(.open) != none {
			prefix := parser.consume_text()
			name_token = parser.try_consume_token(.name)
			regexp_or_wildcard_token = parser.try_consume_regexp_or_wildcard_token(name_token)
			suffix := parser.consume_text()
			parser.consume_required_token(.close)!
			modifier_token := parser.try_consume_modifier_token()
			parser.add_part(prefix, name_token, regexp_or_wildcard_token, suffix, modifier_token)!
			continue
		}
		parser.maybe_add_pending_fixed_value()!
		parser.consume_required_token(.end)!
	}
	return parser.part_list
}

fn (mut parser PatternParser) consume_required_token(type_ PatternTokenType) ! {
	if parser.try_consume_token(type_) == none {
		return error('TypeError: missing required token `${type_}` in URL pattern')
	}
}

fn (mut parser PatternParser) consume_text() string {
	mut result := ''
	for {
		mut token := parser.try_consume_token(.char_)
		if token == none {
			token = parser.try_consume_token(.escaped_char)
		}
		if value := token {
			result += value.value
		} else {
			break
		}
	}
	return result
}

fn (mut parser PatternParser) maybe_add_pending_fixed_value() ! {
	if parser.pending_fixed_value == '' {
		return
	}
	encoded := canonicalize_pattern_component(parser.pending_fixed_value, parser.canonicalization)!
	parser.pending_fixed_value = ''
	parser.part_list << PatternPart{
		type_: .fixed_text
		value: encoded
		modifier: .none
	}
}

fn (parser &PatternParser) is_duplicate_name(name string) bool {
	for part in parser.part_list {
		if part.name == name {
			return true
		}
	}
	return false
}

fn (mut parser PatternParser) add_part(prefix string, name_token ?PatternToken, regexp_or_wildcard_token ?PatternToken, suffix string, modifier_token ?PatternToken) ! {
	mut modifier := PatternPartModifier.none
	if token := modifier_token {
		modifier = match token.value {
			'?' { .optional }
			'*' { .zero_or_more }
			'+' { .one_or_more }
			else { .none }
		}
	}
	if name_token == none && regexp_or_wildcard_token == none && modifier == .none {
		parser.pending_fixed_value += prefix
		return
	}
	parser.maybe_add_pending_fixed_value()!
	if name_token == none && regexp_or_wildcard_token == none {
		if suffix != '' {
			return error('TypeError: invalid suffix on fixed URLPattern group')
		}
		if prefix == '' {
			return
		}
		parser.part_list << PatternPart{
			type_: .fixed_text
			value: canonicalize_pattern_component(prefix, parser.canonicalization)!
			modifier: modifier
		}
		return
	}
	mut regexp_value := parser.segment_wildcard_regexp
	if token := regexp_or_wildcard_token {
		regexp_value = if token.type_ == .asterisk {
			full_wildcard_regexp_value
		} else {
			token.value
		}
	}
	mut type_ := PatternPartType.regexp
	if regexp_value == parser.segment_wildcard_regexp {
		type_ = .segment_wildcard
		regexp_value = ''
	} else if regexp_value == full_wildcard_regexp_value {
		type_ = .full_wildcard
		regexp_value = ''
	}
	mut name := ''
	if token := name_token {
		name = token.value
	} else if regexp_or_wildcard_token != none {
		name = parser.next_numeric_name.str()
		parser.next_numeric_name++
	}
	if parser.is_duplicate_name(name) {
		return error('TypeError: duplicate name `${name}` provided in URL pattern')
	}
	parser.part_list << PatternPart{
		type_: type_
		value: regexp_value
		modifier: modifier
		name: name
		prefix: canonicalize_pattern_component(prefix, parser.canonicalization)!
		suffix: canonicalize_pattern_component(suffix, parser.canonicalization)!
	}
}

fn (mut parser PatternParser) try_consume_modifier_token() ?PatternToken {
	if token := parser.try_consume_token(.other_modifier) {
		return token
	}
	return parser.try_consume_token(.asterisk)
}

fn (mut parser PatternParser) try_consume_regexp_or_wildcard_token(name_token ?PatternToken) ?PatternToken {
	if token := parser.try_consume_token(.regexp) {
		return token
	}
	if name_token == none {
		return parser.try_consume_token(.asterisk)
	}
	return none
}

fn (mut parser PatternParser) try_consume_token(type_ PatternTokenType) ?PatternToken {
	if parser.index >= parser.token_list.len || parser.token_list[parser.index].type_ != type_ {
		return none
	}
	token := parser.token_list[parser.index]
	parser.index++
	return token
}

fn escape_pattern_string(input string) string {
	mut result := ''
	for character in input.bytes() {
		if character in [`+`, `*`, `?`, `:`, `{`, `}`, `(`, `)`, `\\`] {
			result += '\\'
		}
		result += character.ascii_str()
	}
	return result
}

fn escape_regexp_string(input string) string {
	mut result := ''
	for character in input.bytes() {
		if character in [`.`, `+`, `*`, `?`, `^`, `$`, `{`, `}`, `(`, `)`, `[`, `]`, `|`, `/`, `\\`] {
			result += '\\'
		}
		result += character.ascii_str()
	}
	return result
}

fn generate_segment_wildcard_regexp(options PatternCompileOptions) string {
	mut result := '[^'
	if delimiter := options.delimiter_code_point {
		result += escape_regexp_string(delimiter.str())
	}
	return result + ']+?'
}

fn generate_pattern_string(parts []PatternPart, options PatternCompileOptions) string {
	mut result := ''
	for index, part in parts {
		if part.type_ == .fixed_text {
			if part.modifier == .none {
				result += escape_pattern_string(part.value)
			} else {
				result += '{' + escape_pattern_string(part.value) + '}' + part.modifier.serialize()
			}
			continue
		}
		custom_name := part.name.len > 0 && !(part.name[0] >= `0` && part.name[0] <= `9`)
		mut needs_grouping := part.suffix != '' || (part.prefix != '' && (options.prefix_code_point == none || part.prefix != (options.prefix_code_point or { `\0` }).str()))
		if !needs_grouping && custom_name && part.type_ == .segment_wildcard && part.modifier == .none && index + 1 < parts.len && parts[index + 1].prefix == '' && parts[index + 1].suffix == '' {
			next := parts[index + 1]
			if next.type_ == .fixed_text && next.value != '' {
				needs_grouping = is_valid_pattern_name_code_point(next.value.runes()[0], false)
			} else if next.type_ != .fixed_text && next.name != '' {
				needs_grouping = next.name[0] >= `0` && next.name[0] <= `9`
			}
		}
		if !needs_grouping && part.prefix == '' && index > 0 && parts[index - 1].type_ == .fixed_text {
			previous := parts[index - 1]
			if (previous.value == '' && options.prefix_code_point == none) || (options.prefix_code_point != none && previous.value == (options.prefix_code_point or { `\0` }).str()) {
				needs_grouping = true
			}
		}
		if needs_grouping {
			result += '{'
		}
		result += escape_pattern_string(part.prefix)
		if custom_name {
			result += ':' + part.name
		}
		match part.type_ {
			.regexp {
				result += '(' + part.value + ')'
			}
			.segment_wildcard {
				if !custom_name {
					result += '(' + generate_segment_wildcard_regexp(options) + ')'
				}
			}
			.full_wildcard {
				if !custom_name && (index == 0 || parts[index - 1].type_ == .fixed_text || parts[index - 1].modifier != .none || needs_grouping || part.prefix != '') {
					result += '*'
				} else {
					result += '(' + full_wildcard_regexp_value + ')'
				}
			}
			.fixed_text {}
		}
		if part.type_ == .segment_wildcard && custom_name && part.suffix != '' && is_valid_pattern_name_code_point(part.suffix.runes()[0], false) {
			result += '\\'
		}
		result += escape_pattern_string(part.suffix)
		if needs_grouping {
			result += '}'
		}
		result += part.modifier.serialize()
	}
	return result
}
