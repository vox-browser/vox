module libjs

// LibRegex/Rust/src/vm.rs::PatternHints and analyze_pattern, with its
// control-flow, anchor, first-character and required-literal helpers.
pub struct RegexFirstChar {
pub mut:
	code_point       u32
	case_insensitive bool
}

pub struct RegexRequiredLiteralHint {
pub mut:
	literal                []u16
	ascii_case_insensitive bool
}

pub struct RegexStartPositionHint {
pub mut:
	includes_input_start bool
	literal_code_units   []u16
}

pub type RegexSimpleScan = RegexBytecodeCharClass
	| RegexBuiltinCharacterClass
	| RegexLiteral
	| RegexGreedyLoop

pub struct RegexPatternHints {
pub mut:
	first_char          ?RegexFirstChar
	first_filter        ?RegexSimpleMatch
	start_position_hint ?RegexStartPositionHint
	starts_with_anchor  bool
	anchor_multiline    bool
	trailing_literal    ?[]u16
	required_literal    ?RegexRequiredLiteralHint
	simple_scan         ?RegexSimpleScan
	can_match_empty     bool
}

struct RegexInputStart {}

struct RegexLiteralCodeUnit {
	unit u16
}

type RegexLeadingAlternativeStart = RegexInputStart | RegexLiteralCodeUnit

fn regex_instruction_at(instructions []RegexInstruction, pc uint) ?RegexInstruction {
	if pc >= uint(instructions.len) { return none }
	return instructions[int(pc)]
}

fn regex_for_each_successor(instruction RegexInstruction, pc uint, instruction_count uint, callback fn (uint)) {
	match instruction {
		RegexJump {
			callback(uint(instruction.target))
		}
		RegexSplit {
			callback(uint(instruction.prefer))
			callback(uint(instruction.other))
		}
		RegexRepeatCheck {
			callback(uint(instruction.body))
			if pc + 1 < instruction_count { callback(pc + 1) }
		}
		RegexLookStart {
			callback(uint(instruction.end))
			if pc + 1 < instruction_count { callback(pc + 1) }
		}
		RegexMatch, RegexFail, RegexLookEnd {}
		else {
			if pc + 1 < instruction_count { callback(pc + 1) }
		}
	}
}

fn regex_suffix_has_linear_tail(instructions []RegexInstruction, suffix_start uint) bool {
	if suffix_start + 1 >= uint(instructions.len) { return false }
	mut predecessor_count := []uint{len: instructions.len}
	mut predecessor := []uint{len: instructions.len, init: ~uint(0)}
	for pc, instruction in instructions {
		regex_for_each_successor(instruction, uint(pc), uint(instructions.len), fn [mut predecessor_count, mut predecessor, pc] (successor uint) {
			predecessor_count[int(successor)]++
			if predecessor[int(successor)] == ~uint(0) { predecessor[int(successor)] = uint(pc) }
		})
	}
	for target := suffix_start + 1; target < uint(instructions.len); target++ {
		if predecessor_count[int(target)] != 1 || predecessor[int(target)] != target - 1 {
			return false
		}
	}
	return true
}

fn regex_extract_trailing_literal(instructions []RegexInstruction, assert_end_pc uint) ?[]u16 {
	mut trailing_code_points := []u32{}
	mut suffix_start := assert_end_pc
	mut pc := assert_end_pc
	for pc > 0 {
		prev_pc := pc - 1
		instruction := instructions[int(prev_pc)]
		match instruction {
			RegexLiteral {
				trailing_code_points << instruction.code_point
				suffix_start = prev_pc
				pc = prev_pc
			}
			RegexSave, RegexClearRegister, RegexPopModifiers, RegexNop {
				suffix_start = prev_pc
				pc = prev_pc
			}
			else {
				break
			}
		}
	}
	if trailing_code_points.len == 0 || !regex_suffix_has_linear_tail(instructions, suffix_start) {
		return none
	}
	trailing_code_points.reverse_in_place()
	mut suffix := []u16{}
	for code_point in trailing_code_points {
		regex_append_code_point_wtf16(mut suffix, code_point)?
	}
	return suffix
}

fn regex_leading_start_anchor_at(instructions []RegexInstruction, pc uint) ?bool {
	instruction := regex_instruction_at(instructions, pc)?
	return match instruction {
		RegexAssertStart {
			instruction.multiline
		}
		RegexSave, RegexNop, RegexClearRegister, RegexPushModifiers {
			regex_leading_start_anchor_at(instructions, pc + 1)
		}
		RegexLookStart {
			if instruction.positive && instruction.forward {
				regex_leading_start_anchor_at(instructions, pc + 1)
			} else {
				none
			}
		}
		else {
			none
		}
	}
}

fn regex_first_char_at(instructions []RegexInstruction, pc uint) ?RegexFirstChar {
	instruction := regex_instruction_at(instructions, pc)?
	return match instruction {
		RegexLiteral {
			RegexFirstChar{
				code_point: instruction.code_point
			}
		}
		RegexCharNoCase {
			RegexFirstChar{
				code_point:       instruction.first
				case_insensitive: true
			}
		}
		RegexSave {
			regex_first_char_at(instructions, pc + 1)
		}
		else {
			none
		}
	}
}

fn regex_find_common_first_char(instructions []RegexInstruction, start u32) ?RegexFirstChar {
	mut common := ?RegexFirstChar(none)
	mut pc := uint(start)
	for {
		instruction := regex_instruction_at(instructions, pc)?
		match instruction {
			RegexSplit {
				prefer_char := regex_first_char_at(instructions, uint(instruction.prefer))?
				if current := common {
					if current.code_point != prefer_char.code_point { return none }
				} else {
					common = prefer_char
				}
				pc = uint(instruction.other)
			}
			else {
				last_char := regex_first_char_at(instructions, pc)?
				if current := common {
					if current.code_point == last_char.code_point { return common }
					return none
				}
				return last_char
			}
		}
	}
	return none
}

fn regex_leading_alternative_start_at(instructions []RegexInstruction, pc uint) ?RegexLeadingAlternativeStart {
	instruction := regex_instruction_at(instructions, pc)?
	return match instruction {
		RegexAssertStart {
			if !instruction.multiline {
				RegexLeadingAlternativeStart(RegexInputStart{})
			} else {
				none
			}
		}
		RegexLiteral {
			if instruction.code_point <= 0xffff {
				RegexLeadingAlternativeStart(RegexLiteralCodeUnit{
					unit: u16(instruction.code_point)
				})
			} else {
				none
			}
		}
		RegexSave, RegexNop {
			regex_leading_alternative_start_at(instructions, pc + 1)
		}
		else {
			none
		}
	}
}

fn regex_analyze_start_position_hint(instructions []RegexInstruction, start uint) ?RegexStartPositionHint {
	first := regex_instruction_at(instructions, start)?
	if first !is RegexSplit { return none }
	mut hint := RegexStartPositionHint{}
	mut pc := start
	for {
		instruction := regex_instruction_at(instructions, pc)?
		branch := if instruction is RegexSplit { uint(instruction.prefer) } else { pc }
		leading := regex_leading_alternative_start_at(instructions, branch)?
		match leading {
			RegexInputStart {
				hint.includes_input_start = true
			}
			RegexLiteralCodeUnit {
				if leading.unit !in hint.literal_code_units {
					hint.literal_code_units << leading.unit
				}
			}
		}

		if instruction is RegexSplit {
			pc = uint(instruction.other)
		} else {
			break
		}
	}
	if hint.literal_code_units.len >= 1 && hint.literal_code_units.len <= 2 { return hint }
	return none
}

fn regex_pick_more_selective_required_literal(left ?RegexRequiredLiteralHint, right ?RegexRequiredLiteralHint) ?RegexRequiredLiteralHint {
	if lhs := left {
		if rhs := right {
			if rhs.literal.len > lhs.literal.len
				|| (rhs.literal.len == lhs.literal.len && !rhs.ascii_case_insensitive
				&& lhs.ascii_case_insensitive) {
				return rhs
			}
		}
		return lhs
	}
	return right
}

pub fn regex_analyze_pattern(program RegexProgram, can_match_empty bool, ast_required_literal ?RegexRequiredLiteralHint) RegexPatternHints {
	instructions := program.instructions
	skip := if instructions.len > 0 && instructions[0] == RegexInstruction(RegexSave{
		reg: 0
	}) {
		uint(1)
	} else {
		uint(0)
	}
	first_inst := regex_instruction_at(instructions, skip)
	mut filter_offset := skip
	if instruction := first_inst {
		if instruction is RegexAssertWordBoundary || instruction is RegexAssertNonWordBoundary {
			filter_offset++
		}
	}
	filter_inst := regex_instruction_at(instructions, filter_offset)
	mut first_char := ?RegexFirstChar(none)
	mut first_filter := ?RegexSimpleMatch(none)
	if instruction := filter_inst {
		first_char = match instruction {
			RegexLiteral {
				RegexFirstChar{
					code_point: instruction.code_point
				}
			}
			RegexCharNoCase {
				RegexFirstChar{
					code_point:       instruction.first
					case_insensitive: true
				}
			}
			RegexSplit {
				regex_find_common_first_char(instructions, u32(filter_offset))
			}
			else {
				none
			}
		}

		if first_char == none && !program.ignore_case {
			first_filter = match instruction {
				RegexBuiltinCharacterClass {
					RegexSimpleMatch(instruction)
				}
				RegexBytecodeCharClass {
					RegexSimpleMatch(instruction.clone())
				}
				RegexGreedyLoop {
					if instruction.min >= 1 { instruction.matcher.clone() } else { none }
				}
				else {
					none
				}
			}
		}
	}
	start_position_hint := if !program.unicode {
		regex_analyze_start_position_hint(instructions, filter_offset)
	} else {
		?RegexStartPositionHint(none)
	}
	mut starts_with_anchor := false
	mut anchor_multiline := false
	if multiline := regex_leading_start_anchor_at(instructions, skip) {
		starts_with_anchor = true
		anchor_multiline = multiline || program.multiline
	}
	mut trailing_literal := ?[]u16(none)
	mut bytecode_required_literal := ?RegexRequiredLiteralHint(none)
	count := instructions.len
	ends_with_match := count >= 2 && instructions[count - 2] == RegexInstruction(RegexSave{
		reg: 1
	}) && instructions[count - 1] is RegexMatch
	if ends_with_match && count >= 3 {
		anchor := instructions[count - 3]
		if anchor is RegexAssertEnd && !(program.ignore_case || anchor.multiline
			|| program.multiline) {
			trailing_literal = regex_extract_trailing_literal(instructions, uint(count - 3))
		}
	}
	if ends_with_match && !program.ignore_case {
		// Preserve source match-arm order: the broad Save(1),Match arm wins
		// even when AssertEnd precedes it, so an end anchor blocks this hint.
		if literal := regex_extract_trailing_literal(instructions, uint(count - 2)) { bytecode_required_literal = RegexRequiredLiteralHint{
				literal: literal
			} }
	}
	// Rust moves the optional AST hint into the result; V callers retain their
	// argument, so copy its mutable vector before selecting an owned hint.
	mut owned_ast_literal := ?RegexRequiredLiteralHint(none)
	if literal := ast_required_literal { owned_ast_literal = RegexRequiredLiteralHint{
			...literal
			literal: literal.literal.clone()
		} }
	required_literal := regex_pick_more_selective_required_literal(owned_ast_literal,
		bytecode_required_literal)
	mut simple_scan := ?RegexSimpleScan(none)
	if !program.ignore_case && count == 4 && instructions[0] == RegexInstruction(RegexSave{
		reg: 0
	}) && ends_with_match {
		instruction := instructions[1]
		simple_scan = match instruction {
			RegexBytecodeCharClass {
				RegexSimpleScan(instruction.clone())
			}
			RegexBuiltinCharacterClass {
				RegexSimpleScan(instruction)
			}
			RegexLiteral {
				RegexSimpleScan(instruction)
			}
			RegexGreedyLoop {
				if instruction.min >= 1 { RegexSimpleScan(RegexGreedyLoop{
						...instruction
						matcher: instruction.matcher.clone()
					}) } else { none }
			}
			else {
				none
			}
		}
	}
	return RegexPatternHints{
		first_char:          first_char
		first_filter:        first_filter
		start_position_hint: start_position_hint
		starts_with_anchor:  starts_with_anchor
		anchor_multiline:    anchor_multiline
		trailing_literal:    trailing_literal
		required_literal:    required_literal
		simple_scan:         simple_scan
		can_match_empty:     can_match_empty
	}
}
