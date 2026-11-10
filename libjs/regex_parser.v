// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
// LibRegex/Rust/src/parser.rs: ECMAScript pattern grammar.
module libjs

struct RegexSyntaxParser {
mut:
	source           []rune
	pos              int
	flags            RegexAstFlags
	next_capture     u32 = 1
	total_captures   u32
	has_named        bool
	groups           []RegexNamedGroup
	names            []map[string]bool
	in_negated_class bool
	depth            int
}

pub fn parse_regex_ast(source string, flags RegexAstFlags) !RegexPatternAst {
	return parse_regex_ast_chars(source.runes(), flags)
}

pub fn parse_regex_ast_flags(source string) !RegexAstFlags {
	mut flags := RegexAstFlags{}
	for character in source.runes() {
		match character {
			`g` {
				if flags.global { return error('invalid flags "${source}"') }
				flags.global = true
			}
			`i` {
				if flags.ignore_case { return error('invalid flags "${source}"') }
				flags.ignore_case = true
			}
			`m` {
				if flags.multiline { return error('invalid flags "${source}"') }
				flags.multiline = true
			}
			`s` {
				if flags.dot_all { return error('invalid flags "${source}"') }
				flags.dot_all = true
			}
			`u` {
				if flags.unicode || flags.unicode_sets { return error('invalid flags "${source}"') }
				flags.unicode = true
			}
			`v` {
				if flags.unicode || flags.unicode_sets { return error('invalid flags "${source}"') }
				flags.unicode_sets = true
			}
			`y` {
				if flags.sticky { return error('invalid flags "${source}"') }
				flags.sticky = true
			}
			`d` {
				if flags.has_indices { return error('invalid flags "${source}"') }
				flags.has_indices = true
			}
			else { return error('invalid flags "${source}"') }
		}
	}
	return flags
}

pub fn parse_regex_ast_chars(source []rune, flags RegexAstFlags) !RegexPatternAst {
	// Rust's Vec<char> guarantees scalars. V rune arrays also permit arbitrary
	// integers, so enforce that source-side type invariant at this boundary.
	for point in source {
		if point < 0 || !regex_unicode_scalar(u32(point)) {
			return error('invalid Unicode source character')
		}
	}
	mut p := RegexSyntaxParser{ source: source, flags: flags }
	mut in_class := false
	for i := 0; i < source.len; i++ {
		character := source[i]
		if character == `\\` {
			i++
			continue
		}
		if character == `[` && !in_class {
			in_class = true
			continue
		}
		if character == `]` && in_class {
			in_class = false
			continue
		}
		if character != `(` || in_class { continue }
		if i + 1 < source.len && source[i + 1] == `?` {
			if i + 2 < source.len && source[i + 2] == `<`
				&& (i + 3 >= source.len || source[i + 3] !in [`=`, `!`]) {
				p.total_captures++
				p.has_named = true
			}
		} else {
			p.total_captures++
		}
	}
	body := p.disjunction()!
	if p.pos < source.len { return error("unexpected character '${p.peek()}'") }
	mut group_names := map[string]bool{}
	for group in p.groups { group_names[group.name] = true }
	regex_validate_named_backrefs(body, group_names)!
	return RegexPatternAst{
		disjunction:   body
		flags:         flags
		capture_count: p.next_capture - 1
		named_groups:  p.groups
	}
}

fn regex_validate_named_backrefs(body RegexDisjunction, names map[string]bool) ! {
	for alternative in body.alternatives {
		for term in alternative.terms {
			atom := term.atom
			match atom {
				RegexBackreferenceAtom {
					ref := atom.reference
					if ref is RegexNamedBackreference && ref.name !in names {
						return error('invalid named backreference \\k<${ref.name}>')
					}
				}
				RegexGroup { regex_validate_named_backrefs(atom.body, names)! }
				RegexNonCapturingGroup { regex_validate_named_backrefs(atom.body, names)! }
				RegexLookaround { regex_validate_named_backrefs(atom.body, names)! }
				RegexModifierGroup { regex_validate_named_backrefs(atom.body, names)! }
				else {}
			}
		}
	}
}

fn (p &RegexSyntaxParser) peek() rune { return p.peek_at(0) }

fn (p &RegexSyntaxParser) peek_at(offset int) rune {
	if p.pos + offset >= p.source.len { return rune(-1) }
	return p.source[p.pos + offset]
}

fn (mut p RegexSyntaxParser) take(message string) !rune {
	if p.pos >= p.source.len { return error(message) }
	character := p.source[p.pos]
	p.pos++
	return character
}

fn (mut p RegexSyntaxParser) eat(character rune) bool {
	if p.peek() != character { return false }
	p.pos++
	return true
}

fn (mut p RegexSyntaxParser) expect(character rune) ! {
	if p.eat(character) { return }
	if p.peek() == rune(-1) { return error('unexpected end of pattern') }
	return error("unexpected character '${p.peek()}'")
}

fn (p &RegexSyntaxParser) unicode_aware() bool { return p.flags.unicode || p.flags.unicode_sets }

fn (mut p RegexSyntaxParser) merge_names(index int, names map[string]bool) {
	for name, _ in names { p.names[index][name] = true }
}

fn (mut p RegexSyntaxParser) disjunction() !RegexDisjunction {
	// V's recursive sum records have larger stack frames than Rust enums.
	if p.depth >= 128 { return error('regular expression nesting limit exceeded') }
	p.depth++
	defer { p.depth-- }
	inherited := if p.names.len > 0 { p.names.last().clone() } else { map[string]bool{} }
	p.names << inherited.clone()
	mut alternatives := [p.alternative()!]
	for p.eat(`|`) {
		committed := p.names.last().clone()
		if p.names.len > 1 { p.merge_names(p.names.len - 2, committed) }
		p.names[p.names.len - 1] = inherited.clone()
		alternatives << p.alternative()!
	}
	final_names := p.names.pop()
	if p.names.len > 0 {
		for name, _ in final_names {
			if name !in inherited { p.names[p.names.len - 1][name] = true }
		}
	}
	return RegexDisjunction{ alternatives: alternatives }
}

fn (mut p RegexSyntaxParser) alternative() !RegexAlternative {
	mut terms := []RegexTerm{}
	for p.peek() != rune(-1) && p.peek() !in [`)`, `|`] {
		atom := p.atom()!
		mut quantifiable := true
		if atom is RegexAssertionKind { quantifiable = false }
		if atom is RegexLookaround {
			quantifiable = !p.unicode_aware() && atom.kind in [.lookahead_positive,
				.lookahead_negative]
		}
		mut quantifier := ?RegexQuantifier(none)
		if quantifiable {
			quantifier = (p.quantifier()!).value
		} else if p.peek() in [`*`, `+`, `?`] || p.looks_like_quantifier() {
			return error('nothing to repeat')
		}
		terms << RegexTerm{ atom: atom, quantifier: quantifier }
	}
	return RegexAlternative{ terms: terms }
}

fn (p &RegexSyntaxParser) looks_like_quantifier() bool {
	if p.peek() != `{` { return false }
	mut i := p.pos + 1
	if i >= p.source.len || !regex_decimal_digit(p.source[i]) { return false }
	for i < p.source.len && regex_decimal_digit(p.source[i]) { i++ }
	if i < p.source.len && p.source[i] == `,` {
		i++
		for i < p.source.len && regex_decimal_digit(p.source[i]) { i++ }
	}
	return i < p.source.len && p.source[i] == `}`
}

fn regex_decimal_digit(character rune) bool { return character >= `0` && character <= `9` }

fn (mut p RegexSyntaxParser) decimal() ?u32 {
	start := p.pos
	mut value := u64(0)
	for regex_decimal_digit(p.peek()) {
		value = value * 10 + u64(p.peek() - `0`)
		if value > 0x7fffffff { value = 0x7fffffff }
		p.pos++
	}
	if start == p.pos { return none }
	return u32(value)
}

struct RegexParsedQuantifier {
	value ?RegexQuantifier
}

fn (mut p RegexSyntaxParser) quantifier() !RegexParsedQuantifier {
	character := p.peek()
	if character in [`*`, `+`, `?`] {
		p.pos++
		greedy := !p.eat(`?`)
		value := match character {
			`*` { RegexQuantifier.zero_or_more(greedy) }
			`+` { RegexQuantifier.one_or_more(greedy) }
			else { RegexQuantifier.zero_or_one(greedy) }
		}
		return RegexParsedQuantifier{ value: value }
	}
	if character != `{` { return RegexParsedQuantifier{} }
	start := p.pos
	p.pos++
	minimum := p.decimal() or {
		p.pos = start
		if p.unicode_aware() { return error('invalid quantifier') }
		return RegexParsedQuantifier{}
	}
	maximum := if p.eat(`,`) { p.decimal() } else { ?u32(minimum) }
	if !p.eat(`}`) {
		p.pos = start
		if p.unicode_aware() { return error('invalid quantifier') }
		return RegexParsedQuantifier{}
	}
	if max := maximum {
		if max < minimum { return error('invalid quantifier') }
	}
	return RegexParsedQuantifier{ value: RegexQuantifier{ min: minimum, max: maximum, greedy: !p.eat(`?`) } }
}

fn (mut p RegexSyntaxParser) atom() !RegexAtom {
	character := p.peek()
	if character in [`*`, `+`, `?`] || p.looks_like_quantifier() {
		return error('nothing to repeat')
	}
	if p.unicode_aware() && character in [`{`, `}`, `]`] {
		return error("unexpected character '${character}'")
	}
	match character {
		`.` {
			p.pos++
			return RegexDot{}
		}
		`^` {
			p.pos++
			return RegexAssertionKind.start_of_input
		}
		`$` {
			p.pos++
			return RegexAssertionKind.end_of_input
		}
		`\\` { return p.atom_escape() }
		`[` { return p.character_class() }
		`(` { return p.group() }
		else {
			p.pos++
			return RegexLiteral{ code_point: u32(character) }
		}
	}
}

fn (mut p RegexSyntaxParser) group_body() !RegexDisjunction {
	body := p.disjunction()!
	p.expect(`)`)!
	return body
}

fn (mut p RegexSyntaxParser) group() !RegexAtom {
	p.expect(`(`)!
	if !p.eat(`?`) {
		index := p.next_capture
		p.next_capture++
		return RegexGroup{ index: index, body: p.group_body()! }
	}
	if p.eat(`:`) { return RegexNonCapturingGroup{ body: p.group_body()! } }
	if p.peek() in [`=`, `!`] {
		positive := p.eat(`=`)
		if !positive { p.pos++ }
		return RegexLookaround{
			kind: if positive { .lookahead_positive } else { .lookahead_negative }
			body: p.group_body()!
		}
	}
	if p.eat(`<`) {
		if p.peek() in [`=`, `!`] {
			positive := p.eat(`=`)
			if !positive { p.pos++ }
			return RegexLookaround{
				kind: if positive { .lookbehind_positive } else { .lookbehind_negative }
				body: p.group_body()!
			}
		}
		name := p.group_name()!
		p.expect(`>`)!
		if p.names.len > 0 && name in p.names.last() {
			return error("duplicate group name '${name}'")
		}
		index := p.next_capture
		p.next_capture++
		if p.names.len > 0 { p.names[p.names.len - 1][name] = true }
		p.groups << RegexNamedGroup{ name: name, index: index }
		return RegexGroup{ index: index, name: name, body: p.group_body()! }
	}
	if p.peek() in [`i`, `m`, `s`, `-`] {
		adding, remove := p.modifier_flags()!
		p.expect(`:`)!
		return RegexModifierGroup{ add_flags: adding, remove_flags: remove, body: p.group_body()! }
	}
	if p.peek() == rune(-1) { return error('unexpected end of pattern') }
	return error("unexpected character '${p.peek()}'")
}

fn (mut p RegexSyntaxParser) modifier_flags() !(RegexModifierFlags, RegexModifierFlags) {
	mut adding := RegexModifierFlags{}
	mut remove := RegexModifierFlags{}
	mut removing := false
	mut seen := []rune{}
	for p.peek() !in [rune(-1), `:`, `)`] {
		character := p.take('invalid modifier flags')!
		if character == `-` && !removing {
			removing = true
			continue
		}
		if character !in [`i`, `m`, `s`] || character in seen {
			return error('invalid modifier flags')
		}
		seen << character
		if removing {
			match character {
				`i` { remove.ignore_case = true }
				`m` { remove.multiline = true }
				else { remove.dot_all = true }
			}
		} else {
			match character {
				`i` { adding.ignore_case = true }
				`m` { adding.multiline = true }
				else { adding.dot_all = true }
			}
		}
	}
	if removing && seen.len == 0 { return error('invalid modifier flags') }
	return adding, remove
}

fn regex_syntax_character(character rune) bool {
	return character in [`^`, `$`, `\\`, `.`, `*`, `+`, `?`, `(`, `)`, `[`, `]`, `{`, `}`, `|`]
}

fn regex_class_set_syntax(character rune) bool {
	return character in [`(`, `)`, `{`, `}`, `/`, `-`, `|`]
}

// ClassSetReservedPunctuator; Ladybird 7d40499c017a.
fn regex_class_set_reserved_punctuator(character rune) bool {
	return character in [`&`, `-`, `!`, `#`, `%`, `,`, `:`, `;`, `<`, `=`, `>`, `@`, rune(96), `~`]
}

fn regex_class_set_double(character rune) bool {
	return character in [`&`, `!`, `#`, `$`, `%`, `*`, `+`, `,`, `.`, `:`, `;`, `<`, `=`, `>`,
		`?`, `@`, `^`, rune(96), `~`]
}
