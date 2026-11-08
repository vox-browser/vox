// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
// LibRegex/Rust/src/parser.rs: escapes, properties and identifier names.
module libjs

fn regex_builtin_escape(character rune) ?RegexBuiltinCharacterClass {
	return match character {
		`d` { RegexBuiltinCharacterClass.digit }
		`D` { RegexBuiltinCharacterClass.non_digit }
		`w` { RegexBuiltinCharacterClass.word }
		`W` { RegexBuiltinCharacterClass.non_word }
		`s` { RegexBuiltinCharacterClass.whitespace }
		`S` { RegexBuiltinCharacterClass.non_whitespace }
		else { none }
	}
}

fn regex_simple_escape(character rune) ?u32 {
	return match character {
		`n` { u32(10) }
		`r` { u32(13) }
		`t` { u32(9) }
		`f` { u32(12) }
		`v` { u32(11) }
		else { none }
	}
}

fn regex_ascii_alpha(character rune) bool {
	return (character >= `A` && character <= `Z`) || (character >= `a` && character <= `z`)
}

fn (mut p RegexSyntaxParser) atom_escape() !RegexAtom {
	p.expect(`\\`)!
	character := p.take('lone trailing backslash')!
	if builtin := regex_builtin_escape(character) { return builtin }
	if character == `b` { return RegexAssertionKind.word_boundary }
	if character == `B` { return RegexAssertionKind.non_word_boundary }
	if p.unicode_aware() && character in [`p`, `P`] { return p.unicode_property(character == `P`)! }
	if character >= `1` && character <= `9` && (p.unicode_aware() || u32(character - `0`) <= p.total_captures) {
		start := p.pos
		mut number := u32(character - `0`)
		mut overflow := false
		for regex_decimal_digit(p.peek()) {
			digit := u32(p.peek() - `0`)
			if u64(number) * 10 + digit > 0xffffffff {
				overflow = true
			} else {
				number = number * 10 + digit
			}
			p.pos++
		}
		if p.unicode_aware() {
			if overflow || number > p.total_captures {
				return error('invalid backreference \\${number}')
			}
			return RegexBackreferenceAtom{ reference: RegexIndexedBackreference{ index: number } }
		}
		if !overflow && number <= p.total_captures {
			return RegexBackreferenceAtom{ reference: RegexIndexedBackreference{ index: number } }
		}
		p.pos = start
		return RegexLiteral{ code_point: if character >= `8` {
			u32(character)
		} else {
			p.legacy_octal(character)
		} }
	}
	if character == `k` && (p.unicode_aware() || p.has_named) {
		p.expect(`<`)!
		name := p.group_name()!
		p.expect(`>`)!
		return RegexBackreferenceAtom{ reference: RegexNamedBackreference{ name: name } }
	}
	return RegexLiteral{ code_point: p.character_escape(character, false)! }
}

fn (mut p RegexSyntaxParser) character_escape(character rune, in_class bool) !u32 {
	if point := regex_simple_escape(character) { return point }
	if in_class && character == `b` { return 8 }
	if character == `0` && !regex_decimal_digit(p.peek()) { return 0 }
	if character == `c` {
		if p.peek() != rune(-1) {
			ctrl := p.take('invalid escape')!
			if regex_ascii_alpha(ctrl) { return u32(ctrl) & 31 }
			if p.unicode_aware() { return error("invalid escape '\\c'") }
			if in_class && (regex_decimal_digit(ctrl) || ctrl == `_`) { return u32(ctrl) & 31 }
			p.pos -= 2
		} else {
			if p.unicode_aware() { return error("invalid escape '\\c'") }
			p.pos--
		}
		return u32(`\\`)
	}
	if character == `x` {
		if p.unicode_aware() { return p.hex_escape(2) }
		start := p.pos
		return p.hex_escape(2) or {
			p.pos = start
			u32(`x`)
		}
	}
	if character == `u` {
		if p.unicode_aware() { return p.unicode_character_escape() }
		start := p.pos
		return p.unicode_escape() or {
			p.pos = start
			u32(`u`)
		}
	}
	if !p.unicode_aware() && character >= `0` && character <= `7` {
		return p.legacy_octal(character)
	}
	if !p.unicode_aware() { return u32(character) }
	if regex_syntax_character(character) || character == `/` || (in_class && character == `-`) {
		return u32(character)
	}
	return error("invalid escape '\\${character}'")
}

fn regex_hex_digit(character rune) ?u32 {
	if regex_decimal_digit(character) { return u32(character - `0`) }
	if character >= `a` && character <= `f` { return u32(character - `a` + 10) }
	if character >= `A` && character <= `F` { return u32(character - `A` + 10) }
	return none
}

fn (mut p RegexSyntaxParser) hex_escape(digits int) !u32 {
	mut value := u32(0)
	for _ in 0 .. digits {
		character := p.take('invalid Unicode escape')!
		digit := regex_hex_digit(character) or { return error('invalid Unicode escape') }
		value = value * 16 + digit
	}
	return value
}

fn (mut p RegexSyntaxParser) unicode_escape() !u32 {
	if !p.eat(`{`) { return p.hex_escape(4) }
	if !p.unicode_aware() { return error('invalid Unicode escape') }
	mut value := u32(0)
	mut count := 0
	for p.peek() != `}` && p.peek() != rune(-1) {
		digit := regex_hex_digit(p.peek()) or { return error('invalid Unicode escape') }
		if u64(value) * 16 + digit > 0x10ffff { return error('invalid Unicode escape') }
		value = value * 16 + digit
		p.pos++
		count++
	}
	if count == 0 { return error('invalid Unicode escape') }
	p.expect(`}`)!
	return value
}

fn (mut p RegexSyntaxParser) unicode_character_escape() !u32 {
	braced := p.peek() == `{`
	value := p.unicode_escape()!
	if !braced && value >= 0xd800 && value <= 0xdbff {
		start := p.pos
		if p.eat(`\\`) && p.eat(`u`) && p.peek() != `{` {
			low := p.unicode_escape()!
			if low >= 0xdc00 && low <= 0xdfff {
				return 0x10000 + ((value - 0xd800) << 10) + low - 0xdc00
			}
		}
		p.pos = start
	}
	return value
}

fn (mut p RegexSyntaxParser) legacy_octal(first rune) u32 {
	mut value := u32(first - `0`)
	for _ in 0 .. 2 {
		character := p.peek()
		if character < `0` || character > `7` || value * 8 + u32(character - `0`) > 255 { break }
		p.pos++
		value = value * 8 + u32(character - `0`)
	}
	return value
}

fn (mut p RegexSyntaxParser) property_name() !string {
	start := p.pos
	for regex_ascii_alpha(p.peek()) || regex_decimal_digit(p.peek()) || p.peek() == `_` { p.pos++ }
	if start == p.pos { return error("invalid Unicode property ''") }
	return p.source[start..p.pos].string()
}

fn (mut p RegexSyntaxParser) unicode_property(negated bool) !RegexUnicodeProperty {
	p.expect(`{`)!
	name := p.property_name()!
	value := if p.eat(`=`) { ?string(p.property_name()!) } else { ?string(none) }
	p.expect(`}`)!
	if !regex_is_valid_ecma262_property(name, value) {
		return error("invalid Unicode property '${name}'")
	}
	if value == none && regex_is_string_property(name) && (!p.flags.unicode_sets || negated) {
		return error("invalid Unicode property '${name}'")
	}
	return RegexUnicodeProperty{ negated: negated, name: name, value: value }
}

fn regex_unicode_scalar(value u32) bool {
	return value <= 0x10ffff && (value < 0xd800 || value > 0xdfff)
}

fn (mut p RegexSyntaxParser) name_unicode_escape() !u32 {
	if !p.eat(`{`) {
		return p.hex_escape(4) or { return error('invalid group name') }
	}
	mut value := u32(0)
	mut count := 0
	for p.peek() != `}` && p.peek() != rune(-1) {
		digit := regex_hex_digit(p.peek()) or { return error('invalid group name') }
		if u64(value) * 16 + digit > 0xffffffff { return error('invalid group name') }
		value = value * 16 + digit
		p.pos++
		count++
	}
	if !p.eat(`}`) || count == 0 || value > 0x10ffff { return error('invalid group name') }
	return value
}

fn (mut p RegexSyntaxParser) group_name_char() !rune {
	character := p.take('invalid group name')!
	if character != `\\` { return character }
	if !p.eat(`u`) { return error('invalid group name') }
	braced := p.peek() == `{`
	mut point := p.name_unicode_escape()!
	if point >= 0xd800 && point <= 0xdbff {
		if braced || !p.eat(`\\`) || !p.eat(`u`) || p.peek() == `{` {
			return error('invalid group name')
		}
		low := p.name_unicode_escape()!
		if low < 0xdc00 || low > 0xdfff { return error('invalid group name') }
		point = 0x10000 + ((point - 0xd800) << 10) + low - 0xdc00
	}
	if !regex_unicode_scalar(point) { return error('invalid group name') }
	return rune(point)
}

fn (mut p RegexSyntaxParser) group_name() !string {
	first := p.group_name_char()!
	if first !in [`$`, `_`] && !regex_has_identifier_start_property(u32(first)) {
		return error('invalid group name')
	}
	mut name := [first]
	for p.peek() != `>` && p.peek() != rune(-1) {
		character := p.group_name_char()!
		if character != `$` && !regex_has_identifier_continue_property(u32(character)) {
			return error('invalid group name')
		}
		name << character
	}
	return name.string()
}
