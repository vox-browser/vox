// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
// LibRegex/Rust/src/vm.rs: fast/general instruction execution. Shared handlers
// use the same instruction steps; direction/Unicode helpers select traversal.
module libjs

pub fn (mut vm RegexVm) run() RegexVmResult {
	for {
		vm.steps++
		if vm.steps >= regex_match_limit { return .limit_exceeded }
		if uint(vm.pc) >= uint(vm.program.instructions.len) {
			if !vm.backtrack() { return .no_match }
			continue
		}
		instruction := vm.program.instructions[int(vm.pc)]
		match instruction {
			RegexLiteral {
				if vm.match_char(instruction.code_point) {
					vm.pc++
				} else if !vm.backtrack() {
					return .no_match
				}
			}
			RegexCharNoCase {
				if point := vm.current_code_point() {
					if regex_case_fold_eq(point, instruction.first, vm.program.unicode) {
						vm.advance_char()
						vm.pc++
						continue
					}
				}
				if !vm.backtrack() { return .no_match }
			}
			RegexAnyChar {
				if point := vm.current_code_point() {
					if instruction.dot_all || vm.modifiers.dot_all || !regex_is_line_terminator(point) {
						vm.advance_char()
						vm.pc++
						continue
					}
				}
				if !vm.backtrack() { return .no_match }
			}
			RegexBytecodeCharClass {
				if point := vm.current_code_point() {
					if regex_match_char_class(point, instruction.ranges, vm.modifiers.ignore_case, vm.program.unicode, vm.program.unicode_sets) != instruction.negated {
						vm.advance_char()
						vm.pc++
						continue
					}
				}
				if !vm.backtrack() { return .no_match }
			}
			RegexBuiltinCharacterClass {
				if point := vm.current_code_point() {
					if regex_match_builtin_class(point, instruction, vm.modifiers.ignore_case && vm.program.unicode) {
						vm.advance_char()
						vm.pc++
						continue
					}
				}
				if !vm.backtrack() { return .no_match }
			}
			RegexUnicodePropertyData {
				if point := vm.current_code_point() {
					mut matched := false
					if vm.modifiers.ignore_case && vm.program.unicode {
						if instruction.negated && !vm.program.unicode_sets {
							matched = !regex_match_unicode_property_all_case_equivalents(point, instruction.name, instruction.value)
						} else {
							matched = regex_match_unicode_property_case_insensitive(point, instruction.name, instruction.value) != instruction.negated
						}
					} else {
						matched = regex_match_unicode_property_resolved(point, instruction.name, instruction.value, instruction.resolved) != instruction.negated
					}
					if matched {
						vm.advance_char()
						vm.pc++
						continue
					}
				}
				if !vm.backtrack() { return .no_match }
			}
			RegexJump { vm.pc = instruction.target }
			RegexSplit {
				if !vm.program.unicode && !vm.program.unicode_sets && !vm.backward
					&& !vm.modifiers.ignore_case && vm.fails_at_first_code_unit(instruction.prefer) {
					vm.pc = instruction.other
					continue
				}
				vm.push_backtrack(instruction.other, vm.pos)
				vm.pc = instruction.prefer
			}
			RegexSave {
				mut register := instruction.reg
				if vm.backward && register < (vm.program.capture_count + 1) * 2 { register ^= 1 }
				if uint(register) < uint(vm.scratch.registers.len) {
					vm.scratch.registers[int(register)] = i32(vm.pos)
				}
				vm.pc++
			}
			RegexClearRegister {
				if uint(instruction.reg) < uint(vm.scratch.registers.len) {
					vm.scratch.registers[int(instruction.reg)] = -1
				}
				vm.pc++
			}
			RegexAssertStart {
				if result := vm.handle_assert_start(instruction.multiline) { return result }
			}
			RegexAssertEnd {
				if result := vm.handle_assert_end(instruction.multiline, vm.input_len()) {
					return result
				}
			}
			RegexAssertWordBoundary {
				if result := vm.handle_word_boundary_assert(true) { return result }
			}
			RegexAssertNonWordBoundary {
				if result := vm.handle_word_boundary_assert(false) { return result }
			}
			RegexIndexedBackreference {
				if vm.match_backref(instruction.index) {
					vm.pc++
				} else if !vm.backtrack() {
					return .no_match
				}
			}
			RegexNamedBackreference {
				if vm.match_backref_named(instruction.name) {
					vm.pc++
				} else if !vm.backtrack() {
					return .no_match
				}
			}
			RegexRepeatStart { vm.handle_repeat_start(instruction.counter_reg) }
			RegexRepeatCheck {
				vm.handle_repeat_check(instruction.counter_reg, instruction.min, instruction.max, instruction.body, instruction.greedy)
			}
			RegexLookStart {
				if result := vm.handle_look_start(instruction.positive, instruction.forward, instruction.end) {
					return result
				}
			}
			RegexMatch, RegexLookEnd { return .match }
			RegexFail {
				if !vm.backtrack() { return .no_match }
			}
			RegexPushModifiers {
				vm.handle_push_modifiers(instruction.ignore_case, instruction.multiline, instruction.dot_all)
			}
			RegexPopModifiers { vm.handle_pop_modifiers() }
			RegexNop { vm.pc++ }
			RegexStringPropertyMatch {
				if result := vm.handle_string_property_match(instruction.strings, instruction.property) {
					return result
				}
			}
			RegexProgressCheck {
				register := int(instruction.reg)
				if vm.scratch.registers[register] == i32(vm.pos) {
					for capture in instruction.clear_captures {
						if uint(capture) < uint(vm.scratch.registers.len) {
							vm.scratch.registers[int(capture)] = -1
						}
					}
					if !vm.backtrack() { return .no_match }
				} else {
					vm.scratch.registers[register] = i32(vm.pos)
					vm.pc++
				}
			}
			RegexGreedyLoop {
				start := vm.pos
				mut count := u32(0)
				if !vm.program.unicode && !vm.backward {
					consumed, position := regex_greedy_consume_fast(vm.input, vm.pos, instruction.matcher, vm.modifiers, instruction.max)
					count = consumed
					vm.pos = position
				} else {
					for {
						if maximum := instruction.max {
							if count >= maximum { break }
						}
						point := vm.current_code_point() or { break }
						if !vm.match_simple(point, instruction.matcher) { break }
						vm.advance_char()
						count++
					}
				}
				if count < instruction.min {
					vm.pos = start
					if !vm.backtrack() { return .no_match }
				} else {
					if count > instruction.min {
						vm.push_greedy_backtrack(vm.pc, start, vm.pos, instruction.min)
					}
					vm.pc++
				}
			}
			RegexLazyLoop {
				start := vm.pos
				mut failed := false
				for _ in 0 .. instruction.min {
					point := vm.current_code_point() or {
						failed = true
						break
					}
					if !vm.match_simple(point, instruction.matcher) {
						failed = true
						break
					}
					vm.advance_char()
				}
				if failed {
					vm.pos = start
					if !vm.backtrack() { return .no_match }
				} else {
					vm.push_lazy_backtrack(vm.pc, vm.pos, instruction.max, instruction.min)
					vm.pc++
				}
			}
		}
	}
	return .no_match
}

// Before saving registers for an alternative, reject a leading literal or
// character class that cannot match. Saves and clears would be undone on failure.
fn (vm &RegexVm) fails_at_first_code_unit(start u32) bool {
	mut pc := uint(start)
	mut position := vm.pos
	mut checked := 0
	for checked < 4 {
		instruction := regex_instruction_at(vm.program.instructions, pc) or { return false }
		match instruction {
			RegexLiteral {
				if position >= vm.input_len()
					|| u32(vm.input_code_unit(position)) != instruction.code_point { return true }
			}
			RegexBytecodeCharClass {
				if position >= vm.input_len()
					|| regex_char_in_ranges(u32(vm.input_code_unit(position)), instruction.ranges) == instruction.negated {
					return true
				}
			}
			RegexSave, RegexClearRegister {
				pc++
				continue
			}
			else { return false }
		}
		pc++
		position++
		checked++
	}
	return false
}
