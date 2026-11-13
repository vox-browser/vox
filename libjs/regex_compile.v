// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
// LibRegex/Rust/src/compiler.rs: AST lowering and repetition.
module libjs

import vunicode

struct RegexBytecodeCompiler {
mut:
	program       RegexProgram
	ignore_case   bool
	multiline     bool
	dot_all       bool
	backward      bool
	next_register u32
}

struct RegexCompileAlternative {
	value RegexAlternative
}

struct RegexCompileComponent {
	value RegexCharacterClassRange
}

struct RegexCompileOperand {
	value  RegexClassSetOperand
	length int
}

struct RegexCompileExpression {
	value  RegexClassSetExpression
	length int
}

struct RegexCompileString {
	points []u32
}

type RegexCompileChoice = RegexCompileAlternative
	| RegexCompileComponent
	| RegexCompileOperand
	| RegexCompileExpression
	| RegexCompileString

pub fn compile_regex_ast(pattern RegexPatternAst) RegexProgram {
	registers := 2 + pattern.capture_count * 2
	mut compiler := RegexBytecodeCompiler{
		program:       RegexProgram{
			capture_count:  pattern.capture_count
			register_count: registers
			unicode:        pattern.flags.unicode || pattern.flags.unicode_sets
			unicode_sets:   pattern.flags.unicode_sets
			ignore_case:    pattern.flags.ignore_case
			multiline:      pattern.flags.multiline
			dot_all:        pattern.flags.dot_all
		}
		ignore_case:   pattern.flags.ignore_case
		multiline:     pattern.flags.multiline
		dot_all:       pattern.flags.dot_all
		next_register: registers
	}
	compiler.emit(RegexSave{ reg: 0 })
	compiler.disjunction(pattern.disjunction)
	compiler.emit(RegexSave{ reg: 1 })
	compiler.emit(RegexMatch{})
	compiler.program.named_groups = pattern.named_groups.map(RegexNamedGroupEntry{ name: it.name, index: it.index })
	return compiler.program
}

fn (mut c RegexBytecodeCompiler) emit(instruction RegexInstruction) u32 {
	return c.program.emit(instruction)
}

fn (c &RegexBytecodeCompiler) offset() u32 { return c.program.current_offset() }

fn (mut c RegexBytecodeCompiler) register() u32 {
	value := c.next_register
	c.next_register++
	c.program.register_count = c.next_register
	return value
}

fn (mut c RegexBytecodeCompiler) choices(items []RegexCompileChoice) {
	mut jumps := []u32{}
	for index, item in items {
		mut split := u32(0)
		if index + 1 < items.len {
			split = c.emit(RegexSplit{ prefer: c.offset() + 1, other: 0xffffffff })
		}
		match item {
			RegexCompileAlternative { c.alternative(item.value) }
			RegexCompileComponent { c.component(item.value) }
			RegexCompileOperand { c.set_operand(item.value, item.length) }
			RegexCompileExpression { c.set_at_length(item.value, item.length) }
			RegexCompileString { c.point_string(item.points) }
		}
		if index + 1 < items.len {
			jumps << c.emit(RegexJump{ target: 0xffffffff })
			c.program.instructions[int(split)] = RegexSplit{ prefer: split + 1, other: c.offset() }
		}
	}
	for jump in jumps { c.program.instructions[int(jump)] = RegexJump{ target: c.offset() } }
}

fn (mut c RegexBytecodeCompiler) disjunction(body RegexDisjunction) {
	if body.alternatives.len == 2 && body.alternatives[0].terms.len == 1 && body.alternatives[1].terms.len == 1 {
		first := body.alternatives[0].terms[0]
		second := body.alternatives[1].terms[0]
		if left := c.simple(first.atom) {
			if right := c.simple(second.atom) {
				if left == right {
					mut optional := false
					if first.quantifier == none {
						if q := second.quantifier {
							optional = q == RegexQuantifier.zero_or_one(true)
						}
					} else if second.quantifier == none {
						if q := first.quantifier {
							optional = q == RegexQuantifier.zero_or_one(true)
						}
					}
					if optional {
						c.quantified(first.atom, RegexQuantifier.zero_or_one(true))
						return
					}
				}
			}
		}
	}
	mut choices := []RegexCompileChoice{cap: body.alternatives.len}
	for alternative in body.alternatives {
		choices << RegexCompileAlternative{ value: alternative }
	}
	c.choices(choices)
}

fn (mut c RegexBytecodeCompiler) alternative(alternative RegexAlternative) {
	for offset in 0 .. alternative.terms.len {
		index := if c.backward { alternative.terms.len - 1 - offset } else { offset }
		term := alternative.terms[index]
		if q := term.quantifier { c.quantified(term.atom, q) } else { c.atom(term.atom) }
	}
}

fn regex_compiler_capture_indices(atom RegexAtom, mut groups []u32) {
	match atom {
		RegexGroup {
			groups << atom.index
			regex_compiler_body_captures(atom.body, mut groups)
		}
		RegexNonCapturingGroup { regex_compiler_body_captures(atom.body, mut groups) }
		RegexLookaround { regex_compiler_body_captures(atom.body, mut groups) }
		RegexModifierGroup { regex_compiler_body_captures(atom.body, mut groups) }
		else {}
	}
}

fn regex_compiler_body_captures(body RegexDisjunction, mut groups []u32) {
	for alternative in body.alternatives {
		for term in alternative.terms { regex_compiler_capture_indices(term.atom, mut groups) }
	}
}

fn regex_compiler_capture_registers(atom RegexAtom) []u32 {
	if atom is RegexLookaround || atom is RegexAssertionKind { return []u32{} }
	mut groups := []u32{}
	regex_compiler_capture_indices(atom, mut groups)
	mut registers := []u32{cap: groups.len * 2}
	for group in groups {
		registers << group * 2
		registers << group * 2 + 1
	}
	return registers
}

fn (mut c RegexBytecodeCompiler) clear_captures(atom RegexAtom) {
	for register in regex_compiler_capture_registers(atom) {
		c.emit(RegexClearRegister{ reg: register })
	}
}

fn regex_compiler_body_zero_width(body RegexDisjunction) bool {
	for alternative in body.alternatives {
		mut empty := true
		for term in alternative.terms {
			if q := term.quantifier {
				if q.min == 0 { continue }
			}
			if !regex_compiler_atom_zero_width(term.atom) {
				empty = false
				break
			}
		}
		if empty { return true }
	}
	return false
}

fn regex_compiler_atom_zero_width(atom RegexAtom) bool {
	return match atom {
		RegexCharacterClass { regex_compiler_class_zero_width(atom) }
		RegexGroup { regex_compiler_body_zero_width(atom.body) }
		RegexNonCapturingGroup { regex_compiler_body_zero_width(atom.body) }
		RegexModifierGroup { regex_compiler_body_zero_width(atom.body) }
		RegexBackreferenceAtom, RegexLookaround, RegexAssertionKind { true }
		else { false }
	}
}

fn regex_compiler_class_zero_width(class RegexCharacterClass) bool {
	if class.negated { return false }
	body := class.body
	if body is RegexClassSetExpression { return regex_compiler_set_zero_width(body) }
	return false
}

fn regex_compiler_operand_zero_width(operand RegexClassSetOperand) bool {
	return match operand {
		RegexClassStringLiteral { operand.code_points.len == 0 }
		RegexCharacterClass { regex_compiler_class_zero_width(operand) }
		else { false }
	}
}

fn regex_compiler_set_zero_width(expression RegexClassSetExpression) bool {
	if expression.operands.len == 0 { return false }
	match expression {
		RegexClassSetUnion {
			for operand in expression.operands {
				if regex_compiler_operand_zero_width(operand) { return true }
			}
			return false
		}
		RegexClassSetIntersection {
			for operand in expression.operands {
				if !regex_compiler_operand_zero_width(operand) { return false }
			}
			return true
		}
		RegexClassSetSubtraction {
			return regex_compiler_operand_zero_width(expression.operands[0])
		}
	}
}

fn (mut c RegexBytecodeCompiler) quantified(atom RegexAtom, q RegexQuantifier) {
	if matcher := c.simple(atom) {
		if maximum := q.max {
			if maximum == q.min && q.min <= 100000 {
				for _ in 0 .. q.min { c.atom(atom) }
				return
			}
		}
		if q.greedy {
			c.emit(RegexGreedyLoop{ matcher: matcher, min: q.min, max: q.max })
		} else {
			c.emit(RegexLazyLoop{ matcher: matcher, min: q.min, max: q.max })
		}
		return
	}
	empty := regex_compiler_atom_zero_width(atom)
	if (q.max or { q.min }) > 100000 {
		counter := c.register()
		progress := if empty { ?u32(c.register()) } else { ?u32(none) }
		c.emit(RegexRepeatStart{ counter_reg: counter })
		body := c.offset()
		if register := progress { c.emit(RegexSave{ reg: register }) }
		c.clear_captures(atom)
		c.atom(atom)
		if register := progress {
			c.emit(RegexProgressCheck{ reg: register, clear_captures: regex_compiler_capture_registers(atom) })
		}
		c.emit(RegexRepeatCheck{ counter_reg: counter, min: q.min, max: q.max, body: body, greedy: q.greedy })
		return
	}
	for index in 0 .. q.min {
		if index > 0 { c.clear_captures(atom) }
		c.atom(atom)
	}
	if maximum := q.max {
		if maximum == q.min { return }
		count := maximum - q.min
		if !empty {
			c.counted_optional(atom, count, q.greedy)
			return
		}
		for _ in 0 .. count {
			progress := c.register()
			c.optional_body(atom, q.greedy, ?u32(progress), none)
		}
	} else {
		progress := c.register()
		loop_start := c.offset()
		c.optional_body(atom, q.greedy, if empty { ?u32(progress) } else { ?u32(none) }, ?u32(loop_start))
	}
}

fn (mut c RegexBytecodeCompiler) optional_body(atom RegexAtom, greedy bool, progress ?u32, loop_start ?u32) {
	split := c.emit(RegexSplit{ prefer: 0xffffffff, other: 0xffffffff })
	if register := progress { c.emit(RegexSave{ reg: register }) }
	c.clear_captures(atom)
	c.atom(atom)
	if register := progress {
		c.emit(RegexProgressCheck{ reg: register, clear_captures: regex_compiler_capture_registers(atom) })
	}
	if target := loop_start { c.emit(RegexJump{ target: target }) }
	c.program.instructions[int(split)] = RegexSplit{
		prefer: if greedy { split + 1 } else { c.offset() }
		other:  if greedy { c.offset() } else { split + 1 }
	}
}

fn (mut c RegexBytecodeCompiler) counted_optional(atom RegexAtom, count u32, greedy bool) {
	counter := c.register()
	c.emit(RegexRepeatStart{ counter_reg: counter })
	check := c.emit(RegexRepeatCheck{ counter_reg: counter, min: 0, max: count, body: 0xffffffff, greedy: greedy })
	skip := c.emit(RegexJump{ target: 0xffffffff })
	body := c.offset()
	c.clear_captures(atom)
	c.atom(atom)
	c.emit(RegexJump{ target: check })
	c.program.instructions[int(check)] = RegexRepeatCheck{ counter_reg: counter, min: 0, max: count, body: body, greedy: greedy }
	c.program.instructions[int(skip)] = RegexJump{ target: c.offset() }
}

fn (mut c RegexBytecodeCompiler) character(point u32) {
	if c.ignore_case && regex_unicode_scalar(point) {
		// Both operations use Unicode root case mapping. Only the first scalar
		// decides whether the source emits CharNoCase; matching uses canonicalize.
		lower := vunicode.decode_utf16(vunicode.map_case(vunicode.encode_utf16([point]), '', .lowercase).units)
		upper := vunicode.full_upper(point)
		if lower.len > 0 && upper.len > 0 && lower[0] != upper[0] {
			c.emit(RegexCharNoCase{ first: point, second: point })
			return
		}
	}
	c.emit(RegexLiteral{ code_point: point })
}

fn (mut c RegexBytecodeCompiler) atom(atom RegexAtom) {
	match atom {
		RegexLiteral {
			if atom.code_point > 0xffff && !c.program.unicode {
				c.emit(RegexLiteral{ code_point: ((atom.code_point - 0x10000) >> 10) + 0xd800 })
				c.emit(RegexLiteral{ code_point: ((atom.code_point - 0x10000) & 0x3ff) + 0xdc00 })
			} else {
				c.character(atom.code_point)
			}
		}
		RegexDot { c.emit(RegexAnyChar{ dot_all: c.dot_all }) }
		RegexBuiltinCharacterClass { c.emit(atom) }
		RegexCharacterClass { c.character_class(atom) }
		RegexUnicodeProperty {
			if c.program.unicode_sets && !atom.negated && regex_is_string_property(atom.name) {
				c.string_property(atom)
			} else {
				c.emit(regex_compiler_property(atom))
			}
		}
		RegexGroup {
			c.emit(RegexSave{ reg: atom.index * 2 })
			c.disjunction(atom.body)
			c.emit(RegexSave{ reg: atom.index * 2 + 1 })
		}
		RegexNonCapturingGroup { c.disjunction(atom.body) }
		RegexBackreferenceAtom {
			reference := atom.reference
			match reference {
				RegexIndexedBackreference { c.emit(reference) }
				RegexNamedBackreference { c.emit(reference) }
			}
		}
		RegexLookaround {
			positive := atom.kind in [.lookahead_positive, .lookbehind_positive]
			forward := atom.kind in [.lookahead_positive, .lookahead_negative]
			start := c.emit(RegexLookStart{ positive: positive, forward: forward, end: 0xffffffff })
			saved := c.backward
			c.backward = !forward
			c.disjunction(atom.body)
			c.backward = saved
			c.end_look(start, positive, forward)
		}
		RegexAssertionKind {
			match atom {
				.start_of_input { c.emit(RegexAssertStart{ multiline: c.multiline }) }
				.end_of_input { c.emit(RegexAssertEnd{ multiline: c.multiline }) }
				.word_boundary { c.emit(RegexAssertWordBoundary{}) }
				.non_word_boundary { c.emit(RegexAssertNonWordBoundary{}) }
			}
		}
		RegexModifierGroup {
			ignore := regex_compiler_modifier(atom.add_flags.ignore_case, atom.remove_flags.ignore_case)
			multiline := regex_compiler_modifier(atom.add_flags.multiline, atom.remove_flags.multiline)
			dot_all := regex_compiler_modifier(atom.add_flags.dot_all, atom.remove_flags.dot_all)
			c.emit(RegexPushModifiers{ ignore_case: ignore, multiline: multiline, dot_all: dot_all })
			saved_ignore, saved_multiline, saved_dot := c.ignore_case, c.multiline, c.dot_all
			if value := ignore { c.ignore_case = value }
			if value := multiline { c.multiline = value }
			if value := dot_all { c.dot_all = value }
			c.disjunction(atom.body)
			c.ignore_case, c.multiline, c.dot_all = saved_ignore, saved_multiline, saved_dot
			c.emit(RegexPopModifiers{})
		}
	}
}

fn regex_compiler_modifier(add bool, remove bool) ?bool {
	if add { return true }
	if remove { return false }
	return none
}

fn regex_compiler_property(property RegexUnicodeProperty) RegexUnicodePropertyData {
	return RegexUnicodePropertyData{ negated: property.negated, name: property.name, value: property.value }
}

fn (mut c RegexBytecodeCompiler) end_look(start u32, positive bool, forward bool) {
	c.emit(RegexLookEnd{})
	c.program.instructions[int(start)] = RegexLookStart{ positive: positive, forward: forward, end: c.offset() }
}
