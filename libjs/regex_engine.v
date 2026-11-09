// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
// LibRegex/Rust/src/regex.rs: compiled ownership and public execution paths.
module libjs

@[heap]
pub struct RegexEngine {
pub:
	program &RegexProgram @[required]
mut:
	flags        RegexAstFlags
	hints        RegexPatternHints
	literal      ?[]u16
	word_literal ?[]u16
	alternatives ?[][]u16
	scratch      &RegexVmScratch @[required]
}

pub fn RegexEngine.compile(source []rune, flags RegexAstFlags) !&RegexEngine {
	parsed := parse_regex_ast_chars(source, flags)!
	compiled := compile_regex_ast(parsed)
	mut program := &RegexProgram{ ...compiled }
	for index, instruction in program.instructions {
		program.instructions[index] = regex_resolve_instruction(instruction)
	}
	return &RegexEngine{
		program:      program
		flags:        flags
		hints:        regex_analyze_pattern(program, regex_compiler_body_zero_width(parsed.disjunction), regex_ast_required_hint(parsed, flags))
		literal:      regex_engine_literal(parsed, flags)
		word_literal: regex_engine_word_literal(parsed, flags)
		alternatives: regex_engine_alternatives(parsed, flags)
		scratch:      RegexVmScratch.new()
	}
}

fn regex_resolve_data(data RegexUnicodePropertyData) RegexUnicodePropertyData {
	return RegexUnicodePropertyData{
		...data
		resolved: if data.resolved != none {
			data.resolved
		} else {
			regex_resolve_property(data.name, data.value)
		}
	}
}

fn regex_resolve_simple(matcher RegexSimpleMatch) RegexSimpleMatch {
	return match matcher {
		RegexUnicodePropertyData { regex_resolve_data(matcher) }
		RegexSimpleUnion {
			RegexSimpleUnion{ left: box_regex_simple_match(regex_resolve_simple(*matcher.left)), right: box_regex_simple_match(regex_resolve_simple(*matcher.right)) }
		}
		else { matcher }
	}
}

fn regex_resolve_instruction(instruction RegexInstruction) RegexInstruction {
	return match instruction {
		RegexUnicodePropertyData { regex_resolve_data(instruction) }
		RegexStringPropertyMatch {
			RegexStringPropertyMatch{ ...instruction, property: regex_resolve_data(instruction.property) }
		}
		RegexGreedyLoop {
			RegexGreedyLoop{ ...instruction, matcher: regex_resolve_simple(instruction.matcher) }
		}
		RegexLazyLoop {
			RegexLazyLoop{ ...instruction, matcher: regex_resolve_simple(instruction.matcher) }
		}
		else { instruction }
	}
}

fn regex_engine_literal_terms(terms []RegexTerm, flags RegexAstFlags, ascii_only bool) ?[]u16 {
	mut units := []u16{}
	for term in terms {
		if term.quantifier != none { return none }
		atom := term.atom
		if atom !is RegexLiteral { return none }
		if (flags.unicode || flags.unicode_sets) && atom.code_point >= 0xd800 && atom.code_point <= 0xdfff {
			return none
		}
		if ascii_only && atom.code_point > 0x7f { return none }
		regex_append_code_point_wtf16(mut units, atom.code_point)?
	}
	return units
}

fn regex_engine_literal(pattern RegexPatternAst, flags RegexAstFlags) ?[]u16 {
	if flags.ignore_case && (flags.unicode || flags.unicode_sets) { return none }
	if pattern.disjunction.alternatives.len != 1 { return none }
	return regex_engine_literal_terms(pattern.disjunction.alternatives[0].terms, flags, false)
}

fn regex_engine_alternatives(pattern RegexPatternAst, flags RegexAstFlags) ?[][]u16 {
	if flags.ignore_case && (flags.unicode || flags.unicode_sets) { return none }
	if pattern.disjunction.alternatives.len < 2 || pattern.capture_count > 0 { return none }
	mut alternatives := [][]u16{}
	for alternative in pattern.disjunction.alternatives {
		literal := regex_engine_literal_terms(alternative.terms, flags, flags.ignore_case)?
		if literal.len == 0 { return none }
		alternatives << literal
	}
	return alternatives
}

fn regex_engine_word_literal(pattern RegexPatternAst, flags RegexAstFlags) ?[]u16 {
	if flags.unicode || flags.unicode_sets || pattern.capture_count > 0 || pattern.disjunction.alternatives.len != 1 {
		return none
	}
	terms := pattern.disjunction.alternatives[0].terms
	if terms.len < 3 || terms[0].quantifier != none || terms.last().quantifier != none {
		return none
	}
	first := terms[0].atom
	last := terms.last().atom
	if first !is RegexAssertionKind || first != .word_boundary { return none }
	if last !is RegexAssertionKind || last != .word_boundary { return none }
	literal := regex_engine_literal_terms(terms[1..terms.len - 1], flags, flags.ignore_case)?
	if literal.len == 0 || !regex_is_word_char(u32(literal[0])) || !regex_is_word_char(u32(literal.last())) {
		return none
	}
	return literal
}

pub fn (engine &RegexEngine) is_single_non_bmp_literal() bool {
	if !(engine.flags.unicode || engine.flags.unicode_sets) { return false }
	if literal := engine.literal {
		return literal.len == 2 && is_utf16_high_surrogate(literal[0]) && is_utf16_low_surrogate(literal[1])
	}
	return false
}

fn (engine &RegexEngine) literal_at(input RegexInput, position uint, literal []u16) bool {
	if position > input.len() || uint(literal.len) > input.len() - position { return false }
	if !engine.flags.ignore_case { return input.matches_u16_at(position, literal) }
	if literal.all(it <= 0x7f) {
		return regex_matches_ascii_case_insensitive_u16_at(input, position, literal)
	}
	for index, unit in literal {
		if !regex_case_fold_eq(u32(input.code_unit(position + uint(index))), u32(unit), engine.flags.unicode || engine.flags.unicode_sets) {
			return false
		}
	}
	return true
}

fn regex_engine_word_boundaries(input RegexInput, start uint, end uint) bool {
	return (start == 0 || !regex_is_word_char(u32(input.code_unit(start - 1))))
		&& (end >= input.len() || !regex_is_word_char(u32(input.code_unit(end))))
}

fn regex_engine_write_pair(mut output []i32, start uint, end uint) {
	if output.len >= 2 {
		output[0] = i32(start)
		output[1] = i32(end)
	}
}

fn (engine &RegexEngine) literal_search(input RegexInput, start uint, literal []u16, words bool, mut output []i32) bool {
	if literal.len == 0 {
		regex_engine_write_pair(mut output, start, start)
		return true
	}
	if start > input.len() || uint(literal.len) > input.len() - start { return false }
	end := input.len() - uint(literal.len)
	for position := start; position <= end; position++ {
		if engine.literal_at(input, position, literal) && (!words || regex_engine_word_boundaries(input, position, position + uint(literal.len))) {
			regex_engine_write_pair(mut output, position, position + uint(literal.len))
			return true
		}
	}
	return false
}

fn (engine &RegexEngine) alternative_search(input RegexInput, start uint, alternatives [][]u16, mut output []i32) bool {
	for position := start; position < input.len(); position++ {
		for literal in alternatives {
			if engine.literal_at(input, position, literal) {
				regex_engine_write_pair(mut output, position, position + uint(literal.len))
				return true
			}
		}
	}
	return false
}

pub fn (mut engine RegexEngine) exec(input RegexInput, start uint, mut output []i32) RegexVmResult {
	if engine.flags.sticky {
		return regex_execute_anchored_into_with_scratch(engine.program, input, start, engine.hints, mut output, mut engine.scratch)
	}
	if literal := engine.literal {
		return if engine.literal_search(input, start, literal, false, mut output) {
			.match
		} else {
			.no_match
		}
	}
	if literal := engine.word_literal {
		return if engine.literal_search(input, start, literal, true, mut output) {
			.match
		} else {
			.no_match
		}
	}
	if alternatives := engine.alternatives {
		return if engine.alternative_search(input, start, alternatives, mut output) {
			.match
		} else {
			.no_match
		}
	}
	return regex_execute_into_with_scratch(engine.program, input, start, engine.hints, mut output, mut engine.scratch)
}

pub fn (mut engine RegexEngine) test(input RegexInput, start uint) RegexVmResult {
	mut pair := [i32(-1), -1]
	return engine.exec(input, start, mut pair)
}

pub fn (mut engine RegexEngine) find_all(input RegexInput, start uint, mut output []i32) i32 {
	if engine.literal == none && engine.word_literal == none && engine.alternatives == none {
		return regex_find_all_with_scratch(engine.program, input, start, engine.hints, mut output, mut engine.scratch)
	}
	mut position := start
	mut count := i32(0)
	for position <= input.len() {
		mut pair := [i32(-1), -1]
		matched := if literal := engine.literal {
			engine.literal_search(input, position, literal, false, mut pair)
		} else if literal := engine.word_literal {
			engine.literal_search(input, position, literal, true, mut pair)
		} else if alternatives := engine.alternatives {
			engine.alternative_search(input, position, alternatives, mut pair)
		} else {
			false
		}
		if !matched { break }
		index := int(count) * 2
		if index + 1 >= output.len { return -1 }
		output[index] = pair[0]
		output[index + 1] = pair[1]
		count++
		position = regex_next_search_position(pair[0], pair[1])
	}
	return count
}
