// Copyright (c) 2025-2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of LibURL/Pattern/Tokenizer.cpp.
module urlpattern

import encoding.utf8

struct PatternTokenizer {
	input  []rune
	policy PatternTokenizerPolicy
mut:
	tokens     []PatternToken
	index      int
	next_index int
	code_point rune
}

fn tokenize_pattern(input string, policy PatternTokenizerPolicy) ![]PatternToken {
	mut tokenizer := PatternTokenizer{
		input: input.runes()
		policy: policy
	}
	for tokenizer.index < tokenizer.input.len {
		tokenizer.seek_and_get_next_code_point(tokenizer.index)
		if tokenizer.code_point == `*` {
			tokenizer.add_default_token(.asterisk)
			continue
		}
		if tokenizer.code_point in [`+`, `?`] {
			tokenizer.add_default_token(.other_modifier)
			continue
		}
		if tokenizer.code_point == `\\` {
			if tokenizer.index == tokenizer.input.len - 1 {
				tokenizer.process_error(tokenizer.next_index, tokenizer.index)!
				continue
			}
			escaped_index := tokenizer.next_index
			tokenizer.get_next_code_point()
			tokenizer.add_token_with_default_length(.escaped_char, tokenizer.next_index, escaped_index)
			continue
		}
		if tokenizer.code_point == `{` {
			tokenizer.add_default_token(.open)
			continue
		}
		if tokenizer.code_point == `}` {
			tokenizer.add_default_token(.close)
			continue
		}
		if tokenizer.code_point == `:` {
			mut name_position := tokenizer.next_index
			name_start := name_position
			for name_position < tokenizer.input.len {
				tokenizer.seek_and_get_next_code_point(name_position)
				if !is_valid_pattern_name_code_point(tokenizer.code_point, name_position == name_start) {
					break
				}
				name_position = tokenizer.next_index
			}
			if name_position <= name_start {
				tokenizer.process_error(name_start, tokenizer.index)!
				continue
			}
			tokenizer.add_token_with_default_length(.name, name_position, name_start)
			continue
		}
		if tokenizer.code_point == `(` {
			mut depth := 1
			mut regexp_position := tokenizer.next_index
			regexp_start := regexp_position
			mut had_error := false
			for regexp_position < tokenizer.input.len {
				tokenizer.seek_and_get_next_code_point(regexp_position)
				if u32(tokenizer.code_point) > 0x7f || (regexp_position == regexp_start && tokenizer.code_point == `?`) {
					tokenizer.process_error(regexp_start, tokenizer.index)!
					had_error = true
					break
				}
				if tokenizer.code_point == `\\` {
					if regexp_position == tokenizer.input.len - 1 {
						tokenizer.process_error(regexp_start, tokenizer.index)!
						had_error = true
						break
					}
					tokenizer.get_next_code_point()
					if u32(tokenizer.code_point) > 0x7f {
						tokenizer.process_error(regexp_start, tokenizer.index)!
						had_error = true
						break
					}
					regexp_position = tokenizer.next_index
					continue
				}
				if tokenizer.code_point == `)` {
					depth--
					if depth == 0 {
						regexp_position = tokenizer.next_index
						break
					}
				} else if tokenizer.code_point == `(` {
					depth++
					if regexp_position == tokenizer.input.len - 1 {
						tokenizer.process_error(regexp_start, tokenizer.index)!
						had_error = true
						break
					}
					temporary_position := tokenizer.next_index
					tokenizer.get_next_code_point()
					if tokenizer.code_point != `?` {
						tokenizer.process_error(regexp_start, tokenizer.index)!
						had_error = true
						break
					}
					tokenizer.next_index = temporary_position
				}
				regexp_position = tokenizer.next_index
			}
			if had_error {
				continue
			}
			if depth != 0 || regexp_position - regexp_start - 1 == 0 {
				tokenizer.process_error(regexp_start, tokenizer.index)!
				continue
			}
			tokenizer.add_token(.regexp, regexp_position, regexp_start, regexp_position - regexp_start - 1)
			continue
		}
		tokenizer.add_default_token(.char_)
	}
	tokenizer.add_token_with_default_length(.end, tokenizer.index, tokenizer.index)
	return tokenizer.tokens
}

fn (mut tokenizer PatternTokenizer) get_next_code_point() {
	tokenizer.code_point = tokenizer.input[tokenizer.next_index]
	tokenizer.next_index++
}

fn (mut tokenizer PatternTokenizer) seek_and_get_next_code_point(index int) {
	tokenizer.next_index = index
	tokenizer.get_next_code_point()
}

fn (mut tokenizer PatternTokenizer) add_token(type_ PatternTokenType, next_position int, value_position int, value_length int) {
	tokenizer.tokens << PatternToken{
		type_: type_
		index: tokenizer.index
		value: tokenizer.input[value_position..value_position + value_length].string()
	}
	tokenizer.index = next_position
}

fn (mut tokenizer PatternTokenizer) add_token_with_default_length(type_ PatternTokenType, next_position int, value_position int) {
	tokenizer.add_token(type_, next_position, value_position, next_position - value_position)
}

fn (mut tokenizer PatternTokenizer) add_default_token(type_ PatternTokenType) {
	tokenizer.add_token_with_default_length(type_, tokenizer.next_index, tokenizer.index)
}

fn (mut tokenizer PatternTokenizer) process_error(next_position int, value_position int) ! {
	if tokenizer.policy == .strict {
		return error('TypeError: error processing a URLPattern token')
	}
	tokenizer.add_token_with_default_length(.invalid_char, next_position, value_position)
}

fn is_valid_pattern_name_code_point(code_point rune, first bool) bool {
	if first {
		return code_point in [`$`, `_`] || utf8.is_letter(code_point)
	}
	return code_point == `$` || code_point == `_` || utf8.is_letter(code_point) || (code_point >= `0` && code_point <= `9`)
}
