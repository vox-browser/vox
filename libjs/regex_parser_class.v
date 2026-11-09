// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
// LibRegex/Rust/src/parser.rs: character classes and Unicode sets.
module libjs

fn (mut p RegexSyntaxParser) character_class() !RegexCharacterClass {
	if p.depth >= 128 { return error('regular expression nesting limit exceeded') }
	p.depth++
	defer { p.depth-- }
	p.expect(`[`)!
	negated := p.eat(`^`)
	if p.flags.unicode_sets {
		saved := p.in_negated_class
		p.in_negated_class = negated
		expr := if p.peek() == `]` {
			RegexClassSetExpression(RegexClassSetUnion{})
		} else {
			p.set_expression()!
		}
		p.in_negated_class = saved
		if negated && regex_set_contains_strings(expr) { return error('invalid character class') }
		p.expect(`]`)!
		return RegexCharacterClass{ negated: negated, body: expr }
	}
	mut ranges := []RegexCharacterClassRange{}
	for p.peek() != `]` && p.peek() != rune(-1) {
		first := p.class_atom()!
		if !p.eat(`-`) {
			ranges << first
			continue
		}
		if p.peek() == `]` {
			ranges << first
			ranges << RegexLiteral{ code_point: u32(`-`) }
			continue
		}
		second := p.class_atom()!
		if first is RegexLiteral && second is RegexLiteral {
			if first.code_point > second.code_point {
				return regex_character_range_error(first.code_point, second.code_point)
			}
			ranges << RegexCharRange{ start: first.code_point, end: second.code_point }
		} else {
			if p.unicode_aware() { return error('invalid character class') }
			ranges << first
			ranges << RegexLiteral{ code_point: u32(`-`) }
			ranges << second
		}
	}
	p.expect(`]`)!
	return RegexCharacterClass{ negated: negated, body: RegexClassRanges{ ranges: ranges } }
}

fn regex_character_range_error(first u32, second u32) IError {
	a := if regex_unicode_scalar(first) { rune(first).str() } else { '\\u{${first:04X}}' }
	b := if regex_unicode_scalar(second) { rune(second).str() } else { '\\u{${second:04X}}' }
	return error("invalid character range '${a}'-'${b}'")
}

fn (mut p RegexSyntaxParser) class_atom() !RegexCharacterClassRange {
	character := p.take('invalid character class')!
	if character != `\\` { return RegexLiteral{ code_point: u32(character) } }
	escaped := p.take('lone trailing backslash')!
	if builtin := regex_builtin_escape(escaped) { return builtin }
	if p.unicode_aware() && escaped in [`p`, `P`] { return p.unicode_property(escaped == `P`)! }
	return RegexLiteral{ code_point: p.character_escape(escaped, true)! }
}

fn regex_set_operand_has_strings(operand RegexClassSetOperand) bool {
	match operand {
		RegexCharacterClass {
			if operand.negated { return false }
			body := operand.body
			if body is RegexClassSetExpression { return regex_set_contains_strings(body) }
		}
		RegexUnicodeProperty {
			return !operand.negated && operand.value == none && regex_is_string_property(operand.name)
		}
		RegexClassStringLiteral { return operand.code_points.len != 1 }
		else {}
	}
	return false
}

fn regex_set_contains_strings(expr RegexClassSetExpression) bool {
	match expr {
		RegexClassSetUnion {
			for operand in expr.operands {
				if regex_set_operand_has_strings(operand) { return true }
			}
			return false
		}
		RegexClassSetIntersection {
			for operand in expr.operands {
				if !regex_set_operand_has_strings(operand) { return false }
			}
			return true
		}
		RegexClassSetSubtraction {
			return expr.operands.len > 0 && regex_set_operand_has_strings(expr.operands[0])
		}
	}
}

fn regex_no_string_property(operand RegexClassSetOperand) ! {
	if operand is RegexUnicodeProperty && !operand.negated && regex_is_string_property(operand.name) {
		return error("invalid Unicode property '${operand.name}'")
	}
}

fn (p &RegexSyntaxParser) pair(character rune) bool {
	return p.peek() == character && p.peek_at(1) == character
}

fn (mut p RegexSyntaxParser) set_expression() !RegexClassSetExpression {
	saved := p.in_negated_class
	p.in_negated_class = false
	first := p.set_operand()!
	p.in_negated_class = saved
	mut operands := [first]
	operator := p.peek()
	if p.pair(`-`) || p.pair(`&`) {
		if operator == `-` && saved { regex_no_string_property(first)! }
		p.in_negated_class = false
		for p.pair(operator) {
			p.pos += 2
			if operator == `&` && p.peek() == `&` { return error('invalid character class') }
			operands << p.set_operand()!
		}
		p.in_negated_class = saved
		for operand in operands {
			if operand is RegexCharRange { return error('invalid character class') }
		}
		if operator == `-` { return RegexClassSetSubtraction{ operands: operands } }
		return RegexClassSetIntersection{ operands: operands }
	}
	if saved { regex_no_string_property(first)! }
	for p.peek() != `]` && p.peek() != rune(-1) { operands << p.set_operand()! }
	return RegexClassSetUnion{ operands: operands }
}

fn (mut p RegexSyntaxParser) set_operand() !RegexClassSetOperand {
	character := p.peek()
	if character == rune(-1) { return error('invalid character class') }
	if character == `[` { return p.character_class()! }
	if p.eat(`\\`) {
		esc := p.peek()
		if esc == rune(-1) { return error('lone trailing backslash') }
		if p.eat(`q`) { return p.class_string() }
		if builtin := regex_builtin_escape(esc) {
			p.pos++
			return builtin
		}
		if esc in [`p`, `P`] {
			p.pos++
			return p.unicode_property(esc == `P`)!
		}
		return p.set_range(p.set_char_escape()!)
	}
	if regex_class_set_syntax(character) || (p.peek_at(1) == character && regex_class_set_double(character)) {
		return error('invalid character class')
	}
	p.pos++
	return p.set_range(u32(character))
}

fn (mut p RegexSyntaxParser) set_char_escape() !u32 {
	character := p.take('lone trailing backslash')!
	if point := regex_simple_escape(character) { return point }
	if character == `b` { return 8 }
	if character == `0` && !regex_decimal_digit(p.peek()) { return 0 }
	if character == `x` { return p.hex_escape(2) }
	if character == `u` { return p.unicode_character_escape() }
	if regex_syntax_character(character) || character == `/` || character == `-` {
		return u32(character)
	}
	return error("invalid escape '\\${character}'")
}

fn (mut p RegexSyntaxParser) set_range(first u32) !RegexClassSetOperand {
	if !p.eat(`-`) { return RegexLiteral{ code_point: first } }
	if p.peek() in [`]`, `-`] || p.pair(`&`) {
		p.pos--
		return RegexLiteral{ code_point: first }
	}
	mut second := u32(0)
	if p.eat(`\\`) {
		second = p.set_char_escape()!
	} else {
		character := p.take('invalid character class')!
		if regex_class_set_syntax(character) { return error('invalid character class') }
		second = u32(character)
	}
	if first > second { return regex_character_range_error(first, second) }
	return RegexCharRange{ start: first, end: second }
}

fn (mut p RegexSyntaxParser) class_string() !RegexClassSetOperand {
	p.expect(`{`)!
	mut alternatives := [][]rune{}
	mut current := []rune{}
	for p.peek() != `}` && p.peek() != rune(-1) {
		character := p.take('unexpected end of pattern')!
		if character == `|` {
			alternatives << current
			current = []
			continue
		}
		if character in [`(`, `)`, `[`, `]`, `{`, `}`, `/`, `-`] {
			return error('invalid character class')
		}
		if character != `\\` {
			current << character
			continue
		}
		esc := p.take('lone trailing backslash')!
		mut point := u32(0)
		if simple := regex_simple_escape(esc) {
			point = simple
		} else if esc == `b` {
			point = 8
		} else if esc == `0` {
			point = 0
		} else if esc == `x` {
			point = p.hex_escape(2)!
		} else if esc == `u` {
			point = p.unicode_character_escape()!
		} else if esc == `c` {
			ctrl := p.take('unexpected end of pattern')!
			if !regex_ascii_alpha(ctrl) { return error("invalid escape '\\${ctrl}'") }
			point = u32(ctrl) & 31
		} else if regex_syntax_character(esc) || esc == `-` {
			point = u32(esc)
		} else {
			return error("invalid escape '\\${esc}'")
		}
		if !regex_unicode_scalar(point) { return error('invalid Unicode escape') }
		current << rune(point)
	}
	alternatives << current
	p.expect(`}`)!
	if p.in_negated_class {
		for alternative in alternatives {
			if alternative.len > 1 { return error('invalid character class') }
		}
	}
	if alternatives.len == 1 { return RegexClassStringLiteral{ code_points: alternatives[0] } }
	// Stable insertion order for equal lengths matches Rust's stable sort.
	for i in 1 .. alternatives.len {
		mut j := i
		for j > 0 && alternatives[j].len > alternatives[j - 1].len {
			alternatives[j], alternatives[j - 1] = alternatives[j - 1], alternatives[j]
			j--
		}
	}
	mut operands := []RegexClassSetOperand{cap: alternatives.len}
	for alternative in alternatives {
		operands << RegexClassStringLiteral{ code_points: alternative }
	}
	return RegexCharacterClass{ body: RegexClassSetExpression(RegexClassSetUnion{ operands: operands }) }
}
