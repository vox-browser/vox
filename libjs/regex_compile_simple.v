// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
// LibRegex/Rust/src/compiler.rs: fused-loop matcher construction.
module libjs

fn regex_compiler_union(matchers []RegexSimpleMatch) ?RegexSimpleMatch {
	if matchers.len == 0 { return none }
	mut result := matchers[0]
	for matcher in matchers[1..] {
		result = RegexSimpleUnion{ left: box_regex_simple_match(result), right: box_regex_simple_match(matcher) }
	}
	return result
}

fn regex_compiler_negate(matcher RegexSimpleMatch) ?RegexSimpleMatch {
	match matcher {
		RegexBytecodeCharClass {
			return RegexBytecodeCharClass{ ranges: matcher.ranges, negated: !matcher.negated }
		}
		RegexUnicodePropertyData {
			return RegexUnicodePropertyData{ ...matcher, negated: !matcher.negated }
		}
		else { return none }
	}
}

fn (c &RegexBytecodeCompiler) simple(atom RegexAtom) ?RegexSimpleMatch {
	match atom {
		RegexDot { return RegexAnyChar{ dot_all: c.dot_all } }
		RegexLiteral {
			if atom.code_point > 0xffff && !c.program.unicode { return none }
			if c.ignore_case {
				return RegexCharNoCase{ first: atom.code_point, second: atom.code_point }
			}
			return atom
		}
		RegexBuiltinCharacterClass { return atom }
		RegexUnicodeProperty {
			if c.program.unicode_sets && regex_is_string_property(atom.name) { return none }
			return regex_compiler_property(atom)
		}
		RegexCharacterClass {
			body := atom.body
			if body is RegexClassRanges { return c.simple_ranges(body.ranges, atom.negated) }
			if body is RegexClassSetExpression {
				if ranges := regex_compiler_union_ranges(body) {
					return RegexBytecodeCharClass{ ranges: ranges, negated: atom.negated }
				}
				if atom.negated { return none }
				if body is RegexClassSetUnion {
					mut matchers := []RegexSimpleMatch{}
					for operand in body.operands {
						matchers << regex_compiler_simple_operand(operand)?
					}
					return regex_compiler_union(matchers)
				}
			}
		}
		else {}
	}
	return none
}

fn (c &RegexBytecodeCompiler) simple_ranges(items []RegexCharacterClassRange, negated bool) ?RegexSimpleMatch {
	mut ranges := []RegexCharRange{}
	mut matchers := []RegexSimpleMatch{}
	mut complex := false
	for item in items {
		match item {
			RegexLiteral {
				if item.code_point > 0xffff && !c.program.unicode { return none }
				ranges << RegexCharRange{ start: item.code_point, end: item.code_point }
			}
			RegexCharRange { ranges << item }
			RegexBuiltinCharacterClass {
				complex = true
				matchers << item
			}
			RegexUnicodeProperty {
				complex = true
				if regex_is_string_property(item.name) { return none }
				matchers << regex_compiler_property(item)
			}
		}
	}
	regex_compiler_sort_ranges(mut ranges)
	if !complex { return RegexBytecodeCharClass{ ranges: ranges, negated: negated } }
	if negated { return none }
	if ranges.len > 0 { matchers << RegexBytecodeCharClass{ ranges: ranges } }
	return regex_compiler_union(matchers)
}

fn regex_compiler_simple_operand(operand RegexClassSetOperand) ?RegexSimpleMatch {
	match operand {
		RegexLiteral { return operand }
		RegexCharRange { return RegexBytecodeCharClass{ ranges: [operand] } }
		RegexBuiltinCharacterClass { return operand }
		RegexUnicodeProperty {
			if regex_is_string_property(operand.name) { return none }
			return regex_compiler_property(operand)
		}
		RegexClassStringLiteral { return none }
		RegexCharacterClass {
			body := operand.body
			if body is RegexClassRanges {
				mut ranges := []RegexCharRange{}
				for item in body.ranges {
					match item {
						RegexLiteral {
							ranges << RegexCharRange{ start: item.code_point, end: item.code_point }
						}
						RegexCharRange { ranges << item }
						else { return none }
					}
				}
				regex_compiler_sort_ranges(mut ranges)
				return RegexBytecodeCharClass{ ranges: ranges, negated: operand.negated }
			}
			if body is RegexClassSetExpression {
				if body !is RegexClassSetUnion { return none }
				mut matchers := []RegexSimpleMatch{}
				for item in body.operands { matchers << regex_compiler_simple_operand(item)? }
				if operand.negated {
					if matchers.len != 1 { return none }
					return regex_compiler_negate(matchers[0])
				}
				return regex_compiler_union(matchers)
			}
		}
	}
	return none
}
