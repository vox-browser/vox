// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
// LibRegex/Rust/src/compiler.rs: classes, string properties and set operations.
module libjs

struct RegexCompilerOrderedRange {
	value RegexCharRange
	index int
}

fn regex_compiler_sort_ranges(mut ranges []RegexCharRange) {
	// Preserve Rust's stable equal-start ordering; the VM's large-range binary
	// search is right-biased, so reordering equal starts can change its answer.
	mut ordered := []RegexCompilerOrderedRange{cap: ranges.len}
	for index, value in ranges {
		ordered << RegexCompilerOrderedRange{ value: value, index: index }
	}
	ordered.sort_with_compare(fn (a &RegexCompilerOrderedRange, b &RegexCompilerOrderedRange) int {
		if a.value.start < b.value.start { return -1 }
		if a.value.start > b.value.start { return 1 }
		if a.index < b.index { return -1 }
		if a.index > b.index { return 1 }
		return 0
	})
	for index, item in ordered { ranges[index] = item.value }
}

fn (mut c RegexBytecodeCompiler) point_string(points []u32) {
	for index in 0 .. points.len {
		c.character(points[if c.backward { points.len - 1 - index } else { index }])
	}
}

fn regex_compiler_property_strings(name string) [][]u32 {
	packed := regex_get_string_property_data(name)
	if packed.len == 0 { return [][]u32{} }
	mut strings := [][]u32{}
	mut offset := 1
	for _ in 0 .. packed[0] {
		if offset >= packed.len { break }
		length := int(packed[offset])
		offset++
		if length > packed.len - offset { break }
		strings << packed[offset..offset + length].clone()
		offset += length
	}
	return strings
}

fn (mut c RegexBytecodeCompiler) string_property(property RegexUnicodeProperty) {
	mut strings := regex_compiler_property_strings(property.name)
	if strings.len == 0 {
		c.emit(regex_compiler_property(property))
		return
	}
	// Stable longest-first order is also significant for equal-length choices.
	for index in 1 .. strings.len {
		mut j := index
		for j > 0 && strings[j].len > strings[j - 1].len {
			strings[j], strings[j - 1] = strings[j - 1], strings[j]
			j--
		}
	}
	mut packed := []u32{}
	for points in strings {
		packed << u32(points.len)
		for index in 0 .. points.len {
			packed << points[if c.backward { points.len - 1 - index } else { index }]
		}
	}
	c.emit(RegexStringPropertyMatch{ strings: packed, property: regex_compiler_property(property) })
}

fn regex_compiler_inline_builtin(class RegexBuiltinCharacterClass, mut ranges []RegexCharRange) bool {
	if class !in [.digit, .word] { return false }
	ranges << RegexCharRange{ start: 48, end: 57 }
	if class == .word {
		ranges << RegexCharRange{ start: 65, end: 90 }
		ranges << RegexCharRange{ start: 95, end: 95 }
		ranges << RegexCharRange{ start: 97, end: 122 }
	}
	return true
}

fn (mut c RegexBytecodeCompiler) character_class(class RegexCharacterClass) {
	body := class.body
	if body is RegexClassSetExpression {
		c.set_class(body, class.negated)
		return
	}
	if body is RegexClassRanges {
		mut ranges := []RegexCharRange{}
		mut complex := false
		for item in body.ranges {
			match item {
				RegexLiteral {
					if !c.program.unicode && item.code_point > 0xffff {
						hi := ((item.code_point - 0x10000) >> 10) + 0xd800
						lo := ((item.code_point - 0x10000) & 0x3ff) + 0xdc00
						ranges << RegexCharRange{ start: hi, end: hi }
						ranges << RegexCharRange{ start: lo, end: lo }
					} else {
						ranges << RegexCharRange{ start: item.code_point, end: item.code_point }
					}
				}
				RegexCharRange { ranges << item }
				RegexBuiltinCharacterClass {
					if class.negated || c.program.unicode || !regex_compiler_inline_builtin(item, mut ranges) {
						complex = true
					}
				}
				RegexUnicodeProperty { complex = true }
			}
		}
		if complex {
			c.complex_class(body.ranges, class.negated)
		} else {
			regex_compiler_sort_ranges(mut ranges)
			c.emit(RegexBytecodeCharClass{ ranges: ranges, negated: class.negated })
		}
	}
}

fn (mut c RegexBytecodeCompiler) complex_class(ranges []RegexCharacterClassRange, negated bool) {
	if negated && ranges.len == 1 {
		item := ranges[0]
		if item is RegexBuiltinCharacterClass {
			c.emit(item.negated())
			return
		}
	}
	mut start := u32(0)
	forward := !c.backward
	if negated {
		start = c.emit(RegexLookStart{ positive: false, forward: forward, end: 0xffffffff })
	}
	mut choices := []RegexCompileChoice{cap: ranges.len}
	for range in ranges { choices << RegexCompileComponent{ value: range } }
	c.choices(choices)
	if negated {
		c.end_look(start, false, forward)
		c.emit(RegexAnyChar{ dot_all: true })
	}
}

fn (mut c RegexBytecodeCompiler) component(component RegexCharacterClassRange) {
	match component {
		RegexLiteral { c.character(component.code_point) }
		RegexCharRange { c.emit(RegexBytecodeCharClass{ ranges: [component] }) }
		RegexBuiltinCharacterClass { c.emit(component) }
		RegexUnicodeProperty { c.emit(regex_compiler_property(component)) }
	}
}

fn regex_compiler_union_ranges(expression RegexClassSetExpression) ?[]RegexCharRange {
	if expression !is RegexClassSetUnion { return none }
	mut ranges := []RegexCharRange{}
	for item in expression.operands {
		match item {
			RegexLiteral {
				ranges << RegexCharRange{ start: item.code_point, end: item.code_point }
			}
			RegexCharRange { ranges << item }
			RegexCharacterClass {
				if item.negated { return none }
				body := item.body
				if body is RegexClassRanges {
					for range in body.ranges {
						match range {
							RegexLiteral {
								ranges << RegexCharRange{ start: range.code_point, end: range.code_point }
							}
							RegexCharRange { ranges << range }
							else { return none }
						}
					}
				} else if body is RegexClassSetExpression {
					ranges << regex_compiler_union_ranges(body)?
				}
			}
			else { return none }
		}
	}
	regex_compiler_sort_ranges(mut ranges)
	return ranges
}

fn (mut c RegexBytecodeCompiler) set_class(expression RegexClassSetExpression, negated bool) {
	if expression is RegexClassSetUnion && expression.operands.len == 0 {
		if negated { c.emit(RegexAnyChar{ dot_all: true }) } else { c.emit(RegexFail{}) }
		return
	}
	if ranges := regex_compiler_union_ranges(expression) {
		c.emit(RegexBytecodeCharClass{ ranges: ranges, negated: negated })
		return
	}
	forward := !c.backward
	mut start := u32(0)
	if negated {
		start = c.emit(RegexLookStart{ positive: false, forward: forward, end: 0xffffffff })
	}
	lengths := c.set_lengths(expression)
	if lengths.len == 0 {
		c.emit(RegexFail{})
	} else {
		mut choices := []RegexCompileChoice{cap: lengths.len}
		for length in lengths {
			choices << RegexCompileExpression{ value: expression, length: length }
		}
		c.choices(choices)
	}
	if negated {
		c.end_look(start, false, forward)
		c.emit(RegexAnyChar{ dot_all: true })
	}
}

fn (c &RegexBytecodeCompiler) operand_lengths(operand RegexClassSetOperand) []int {
	match operand {
		RegexClassStringLiteral { return [operand.code_points.len] }
		RegexCharacterClass {
			if !operand.negated {
				body := operand.body
				if body is RegexClassSetExpression { return c.set_lengths(body) }
			}
		}
		RegexUnicodeProperty {
			if c.program.unicode_sets && !operand.negated && regex_is_string_property(operand.name) {
				mut lengths := [1]
				for points in regex_compiler_property_strings(operand.name) {
					if points.len !in lengths { lengths << points.len }
				}
				lengths.sort(a > b)
				return lengths
			}
		}
		else {}
	}
	return [1]
}

fn (c &RegexBytecodeCompiler) set_lengths(expression RegexClassSetExpression) []int {
	operands := expression.operands
	if operands.len == 0 { return []int{} }
	mut lengths := c.operand_lengths(operands[0])
	if expression is RegexClassSetSubtraction { return lengths }
	for operand in operands[1..] {
		next := c.operand_lengths(operand)
		if expression is RegexClassSetIntersection {
			lengths = lengths.filter(it in next)
		} else {
			for length in next { if length !in lengths { lengths << length } }
		}
	}
	lengths.sort(a > b)
	return lengths
}

fn (mut c RegexBytecodeCompiler) set_at_length(expression RegexClassSetExpression, length int) {
	operands := expression.operands
	if operands.len == 0 {
		c.emit(RegexFail{})
		return
	}
	if expression is RegexClassSetUnion {
		mut choices := []RegexCompileChoice{}
		for operand in operands {
			if length in c.operand_lengths(operand) {
				choices << RegexCompileOperand{ value: operand, length: length }
			}
		}
		if choices.len == 0 { c.emit(RegexFail{}) } else { c.choices(choices) }
		return
	}
	c.set_operand(operands[0], length)
	positive := expression is RegexClassSetIntersection
	for operand in operands[1..] {
		if length !in c.operand_lengths(operand) {
			if positive {
				c.emit(RegexFail{})
				return
			}
			continue
		}
		forward := c.backward
		start := c.emit(RegexLookStart{ positive: positive, forward: forward, end: 0xffffffff })
		saved := c.backward
		c.backward = !forward
		c.set_operand(operand, length)
		c.backward = saved
		c.end_look(start, positive, forward)
	}
}

fn (mut c RegexBytecodeCompiler) set_operand(operand RegexClassSetOperand, length int) {
	match operand {
		RegexLiteral {
			if length == 1 { c.character(operand.code_point) } else { c.emit(RegexFail{}) }
		}
		RegexCharRange {
			if length == 1 {
				c.emit(RegexBytecodeCharClass{ ranges: [operand] })
			} else {
				c.emit(RegexFail{})
			}
		}
		RegexBuiltinCharacterClass {
			if length == 1 { c.emit(operand) } else { c.emit(RegexFail{}) }
		}
		RegexClassStringLiteral {
			if operand.code_points.len != length {
				c.emit(RegexFail{})
				return
			}
			c.point_string(operand.code_points.map(u32(it)))
		}
		RegexCharacterClass {
			body := operand.body
			if !operand.negated && body is RegexClassSetExpression {
				c.set_at_length(body, length)
			} else if length == 1 {
				c.character_class(operand)
			} else {
				c.emit(RegexFail{})
			}
		}
		RegexUnicodeProperty {
			if c.program.unicode_sets && !operand.negated && regex_is_string_property(operand.name) && length != 1 {
				mut choices := []RegexCompileChoice{}
				for points in regex_compiler_property_strings(operand.name) {
					if points.len == length { choices << RegexCompileString{ points: points } }
				}
				if choices.len == 0 { c.emit(RegexFail{}) } else { c.choices(choices) }
			} else if length == 1 {
				c.emit(regex_compiler_property(operand))
			} else {
				c.emit(RegexFail{})
			}
		}
	}
}
