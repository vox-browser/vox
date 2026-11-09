// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
// LibRegex/Rust/src/vm.rs: anchored/search/bulk execution with scratch reuse.
module libjs

fn regex_execution_candidate(program RegexProgram, input RegexInput, hints RegexPatternHints, start uint) ?uint {
	if !program.unicode {
		if hint := hints.start_position_hint {
			return regex_next_literal_start_from_hint(input, start, hint)
		}
		if first := hints.first_char {
			if !first.case_insensitive && first.code_point <= 0xffff {
				return input.next_literal_start(start, u16(first.code_point))
			}
		}
	}
	return regex_next_candidate_start(program, input, hints, start)
}

pub fn regex_execute_into_with_scratch(program &RegexProgram, input RegexInput, start uint, hints RegexPatternHints, mut output []i32, mut scratch RegexVmScratch) RegexVmResult {
	if regex_fails_trailing_literal_hint(input, hints) || regex_fails_required_literal_hint(input, start, hints) {
		return .no_match
	}
	if scan := hints.simple_scan {
		return if regex_execute_simple_scan_into(program, input, start, scan, mut output) {
			.match
		} else {
			.no_match
		}
	}
	mut vm := RegexVm.new(program, input, start, mut scratch)
	if hints.starts_with_anchor && !hints.anchor_multiline {
		result := vm.run()
		if result == .match {
			regex_copy_captures_to_out(scratch.registers, program.capture_count, mut output)
		}
		return result
	}
	mut position := start
	mut hit_limit := false
	for {
		candidate := regex_execution_candidate(program, input, hints, position) or { break }
		vm.reset(candidate)
		result := vm.run()
		if result == .match {
			regex_copy_captures_to_out(scratch.registers, program.capture_count, mut output)
			return result
		}
		if result == .limit_exceeded { hit_limit = true }
		position = candidate + 1
	}
	return if hit_limit { .limit_exceeded } else { .no_match }
}

pub fn regex_execute_anchored_into_with_scratch(program &RegexProgram, input RegexInput, start uint, hints RegexPatternHints, mut output []i32, mut scratch RegexVmScratch) RegexVmResult {
	if regex_fails_trailing_literal_hint(input, hints) || regex_fails_required_literal_hint(input, start, hints) {
		return .no_match
	}
	mut vm := RegexVm.new(program, input, start, mut scratch)
	result := vm.run()
	if result == .match {
		regex_copy_captures_to_out(scratch.registers, program.capture_count, mut output)
	}
	return result
}

pub fn regex_find_all_with_scratch(program &RegexProgram, input RegexInput, start uint, hints RegexPatternHints, mut output []i32, mut scratch RegexVmScratch) i32 {
	if regex_fails_trailing_literal_hint(input, hints) || regex_fails_required_literal_hint(input, start, hints) {
		return 0
	}
	if scan := hints.simple_scan {
		return regex_find_all_simple_scan(program, input, start, scan, mut output)
	}
	mut vm := RegexVm.new(program, input, start, mut scratch)
	mut count := i32(0)
	mut position := start
	// The source bulk path considers a literal-start hint before the anchor gate.
	anchored := hints.starts_with_anchor && !hints.anchor_multiline
	use_start_hint := !program.unicode && hints.start_position_hint != none
	for {
		candidate := if anchored && !use_start_hint {
			position
		} else {
			regex_execution_candidate(program, input, hints, position) or { break }
		}
		vm.reset(candidate)
		result := vm.run()
		if result == .limit_exceeded { return -2 }
		if result == .match {
			index := int(count) * 2
			if index + 1 >= output.len { return -1 }
			output[index] = scratch.registers[0]
			output[index + 1] = scratch.registers[1]
			count++
			position = regex_next_search_position(scratch.registers[0], scratch.registers[1])
		} else {
			position = candidate + 1
		}
		if anchored && !use_start_hint { break }
	}
	return count
}
