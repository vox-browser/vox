// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module aria

// LibWeb's ARIA token lists split only on Infra ASCII whitespace. V's
// string.fields() also treats non-ASCII Unicode whitespace as separators, so
// keep the source algorithm explicit here.
fn ascii_whitespace_separated_tokens(input string) []string {
	mut tokens := []string{}
	mut start := 0
	for index := 0; index <= input.len; index++ {
		at_end := index == input.len
		is_ascii_whitespace := !at_end && input[index] in [u8(0x09), 0x0a, 0x0c, 0x0d, 0x20]
		if !at_end && !is_ascii_whitespace {
			continue
		}
		if index > start {
			tokens << input[start..index]
		}
		start = index + 1
	}
	return tokens
}

fn value_equals(value ?string, expected string) bool {
	return value or { return false } == expected
}
