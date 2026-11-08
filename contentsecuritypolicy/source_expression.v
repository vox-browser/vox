// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Directives/SourceExpression.{h,cpp}.
module contentsecuritypolicy

pub struct SourceExpressionParseResult {
pub:
	scheme_part    ?string
	host_part      ?string
	port_part      ?string
	path_part      ?string
	keyword_source ?string
	base64_value   ?string
	hash_algorithm ?string
}

pub enum Production {
	scheme_source
	host_source
	keyword_source
	nonce_source
	hash_source
}

fn is_alpha(c u8) bool {
	return (c >= `a` && c <= `z`) || (c >= `A` && c <= `Z`)
}

fn is_digit(c u8) bool {
	return c >= `0` && c <= `9`
}

fn is_hex(c u8) bool {
	return is_digit(c) || (c >= `a` && c <= `f`) || (c >= `A` && c <= `F`)
}

fn parse_scheme_at(input string, start int) ?int {
	if start >= input.len || !is_alpha(input[start]) {
		return none
	}
	mut pos := start + 1
	for pos < input.len && (is_alpha(input[pos]) || is_digit(input[pos])
		|| input[pos] in [`+`, `-`, `.`]) {
		pos++
	}
	return pos
}

fn parse_scheme_source(input string) ?SourceExpressionParseResult {
	end := parse_scheme_at(input, 0) or { return none }
	if end + 1 != input.len || input[end] != `:` {
		return none
	}
	return SourceExpressionParseResult{
		scheme_part: input[..end]
	}
}

fn parse_host_source(input string) ?SourceExpressionParseResult {
	mut pos := 0
	mut scheme := ?string(none)
	if scheme_end := parse_scheme_at(input, 0) {
		if scheme_end + 3 <= input.len && input[scheme_end..scheme_end + 3] == '://' {
			scheme = input[..scheme_end]
			pos = scheme_end + 3
		}
	}
	host_start := pos
	if pos < input.len && input[pos] == `*` {
		pos++
		if pos < input.len && input[pos] == `.` {
			pos++
			if pos >= input.len || !(is_alpha(input[pos]) || is_digit(input[pos])
				|| input[pos] == `-`) {
				return none
			}
			for pos < input.len && (is_alpha(input[pos]) || is_digit(input[pos])
				|| input[pos] == `-`) {
				pos++
			}
		} else {
			// A bare wildcard is a complete host-part.
		}
	} else {
		if pos >= input.len || !(is_alpha(input[pos]) || is_digit(input[pos]) || input[pos] == `-`) {
			return none
		}
		for pos < input.len && (is_alpha(input[pos]) || is_digit(input[pos]) || input[pos] == `-`) {
			pos++
		}
	}
	for pos < input.len && input[pos] == `.` {
		pos++
		for pos < input.len && (is_alpha(input[pos]) || is_digit(input[pos]) || input[pos] == `-`) {
			pos++
		}
	}
	host := input[host_start..pos]
	if host == '*.' || host == '' {
		return none
	}
	mut port := ?string(none)
	if pos < input.len && input[pos] == `:` {
		pos++
		port_start := pos
		if pos < input.len && input[pos] == `*` {
			pos++
		} else {
			for pos < input.len && is_digit(input[pos]) {
				pos++
			}
			if pos == port_start {
				return none
			}
		}
		port = input[port_start..pos]
	}
	mut path := ?string(none)
	if pos < input.len {
		if input[pos] != `/` {
			return none
		}
		path_start := pos
		for pos < input.len {
			c := input[pos]
			if c == `;` || c == `,` {
				return none
			}
			if c == `%` {
				if pos + 2 >= input.len || !is_hex(input[pos + 1]) || !is_hex(input[pos + 2]) {
					return none
				}
				pos += 3
				continue
			}
			if !(is_alpha(c) || is_digit(c)
				|| c in [`/`, `-`, `.`, `_`, `~`, `!`, `$`, `&`, `'`, `(`, `)`, `*`, `+`, `=`, `:`, `@`]) {
				return none
			}
			pos++
		}
		path = input[path_start..pos]
	}
	if pos != input.len {
		return none
	}
	return SourceExpressionParseResult{
		scheme_part: scheme
		host_part:   host
		port_part:   port
		path_part:   path
	}
}

fn parse_base64(input string, start int, end_limit int) ?int {
	mut pos := start
	for pos < end_limit && (is_alpha(input[pos]) || is_digit(input[pos])
		|| input[pos] in [`+`, `/`, `-`, `_`]) {
		pos++
	}
	if pos == start {
		return none
	}
	mut padding := 0
	for pos < end_limit && input[pos] == `=` && padding < 2 {
		pos++
		padding++
	}
	return pos
}

fn parse_nonce_source(input string) ?SourceExpressionParseResult {
	if input.len < 9 || !input[..7].to_lower().starts_with("'nonce-") || input[input.len - 1] != `'` {
		return none
	}
	end := parse_base64(input, 7, input.len - 1) or { return none }
	if end != input.len - 1 {
		return none
	}
	return SourceExpressionParseResult{
		base64_value: input[7..end]
	}
}

fn parse_hash_source(input string) ?SourceExpressionParseResult {
	if input.len < 11 || input[0] != `'` || input[input.len - 1] != `'` {
		return none
	}
	dash := input.index_after('-', 1) or { return none }
	algorithm := input[1..dash].to_lower()
	if algorithm !in ['sha256', 'sha384', 'sha512'] {
		return none
	}
	end := parse_base64(input, dash + 1, input.len - 1) or { return none }
	if end != input.len - 1 {
		return none
	}
	return SourceExpressionParseResult{
		hash_algorithm: input[1..dash]
		base64_value:   input[dash + 1..end]
	}
}

pub fn parse_source_expression(production Production, input string) ?SourceExpressionParseResult {
	return match production {
		.scheme_source {
			parse_scheme_source(input)
		}
		.host_source {
			parse_host_source(input)
		}
		.keyword_source {
			if input.to_lower() in [keyword_self, unsafe_inline, unsafe_eval, trusted_types_eval, strict_dynamic, unsafe_hashes,
				report_sample, unsafe_allow_redirects, wasm_unsafe_eval] {
				SourceExpressionParseResult{
					keyword_source: input
				}
			} else {
				none
			}
		}
		.nonce_source {
			parse_nonce_source(input)
		}
		.hash_source {
			parse_hash_source(input)
		}
	}
}
