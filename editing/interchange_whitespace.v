// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Editing/InterchangeWhitespace.{h,cpp}.
module editing

import dom
import strings

pub enum InterchangeWhitespaceTokenType {
	text
	protected_space
}

pub struct InterchangeWhitespaceToken {
pub:
	type_ InterchangeWhitespaceTokenType
	text  string
}

pub fn is_ascii_whitespace_text(node &dom.Node) bool {
	if !node.is_text() {
		return false
	}
	data := node.text_content() or { return false }
	return data.runes().all(it in [` `, `\t`, `\n`, `\v`, `\f`, `\r`])
}

fn flush_interchange_text(mut tokens []InterchangeWhitespaceToken, mut pending_text strings.Builder) {
	if pending_text.len == 0 {
		return
	}
	tokens << InterchangeWhitespaceToken{
		type_: .text
		text: pending_text.str()
	}
	pending_text = strings.new_builder(0)
}

fn append_interchange_protected_space(mut tokens []InterchangeWhitespaceToken, mut pending_text strings.Builder) {
	flush_interchange_text(mut tokens, mut pending_text)
	tokens << InterchangeWhitespaceToken{type_: .protected_space}
}

pub fn rebalance_whitespace_for_interchange(input string) []InterchangeWhitespaceToken {
	characters := input.runes()
	mut tokens := []InterchangeWhitespaceToken{}
	mut pending_text := strings.new_builder(input.len)

	mut index := 0
	for index < characters.len {
		if characters[index] !in [` `, `\n`] {
			pending_text.write_rune(characters[index])
			index++
			continue
		}

		start := index
		for index < characters.len && characters[index] in [` `, `\n`] {
			index++
		}
		mut count := index - start
		for count > 0 {
			mut add := count % 3
			if add == 0 {
				append_interchange_protected_space(mut tokens, mut pending_text)
				pending_text.write_u8(` `)
				append_interchange_protected_space(mut tokens, mut pending_text)
				add = 3
			} else if add == 1 {
				if start == 0 || start + 1 == characters.len {
					append_interchange_protected_space(mut tokens, mut pending_text)
				} else {
					pending_text.write_u8(` `)
				}
			} else if start == 0 {
				append_interchange_protected_space(mut tokens, mut pending_text)
				pending_text.write_u8(` `)
			} else if start + 2 == characters.len {
				append_interchange_protected_space(mut tokens, mut pending_text)
				append_interchange_protected_space(mut tokens, mut pending_text)
			} else {
				append_interchange_protected_space(mut tokens, mut pending_text)
				pending_text.write_u8(` `)
			}
			count -= add
		}
	}
	flush_interchange_text(mut tokens, mut pending_text)
	return tokens
}
