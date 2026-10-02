module libjs

fn test_regex_repeat_start_ignores_absent_registers_but_always_advances_pc() {
	program := &RegexProgram{
		register_count: 2
	}
	mut scratch := RegexVmScratch.new()
	mut vm := RegexVm.new(program, RegexAsciiInput{}, 0, mut scratch)
	vm.handle_repeat_start(1)
	assert scratch.registers == [i32(-1), 0] && vm.pc == 1
	vm.handle_repeat_start(2)
	vm.handle_repeat_start(0xffffffff)
	assert scratch.registers == [i32(-1), 0] && vm.pc == 3
}

fn test_regex_repeat_check_prioritizes_minimum_then_maximum_without_saving_choices() {
	program := &RegexProgram{
		register_count: 2
	}
	mut scratch := RegexVmScratch.new()
	mut vm := RegexVm.new(program, RegexAsciiInput{}, 9, mut scratch)
	vm.handle_repeat_start(1)
	vm.handle_repeat_check(1, 3, u32(0), 17, false)
	assert scratch.registers[1] == 1 && vm.pc == 17 && scratch.backtrack_stack.len == 0
	scratch.registers[1] = 3
	vm.handle_repeat_check(1, 3, u32(3), 17, true)
	assert scratch.registers[1] == 3 && vm.pc == 18 && scratch.backtrack_stack.len == 0
	// The source casts the initial -1 sentinel to u32 before its comparisons.
	scratch.registers[1] = -1
	vm.handle_repeat_check(1, 3, u32(99), 17, true)
	assert scratch.registers[1] == -1 && vm.pc == 19 && scratch.backtrack_stack.len == 0
}

fn test_regex_repeat_greedy_and_lazy_choices_save_different_counter_values() {
	program := &RegexProgram{
		register_count: 2
		multiline:      true
	}
	mut scratch := RegexVmScratch.new()
	mut vm := RegexVm.new(program, RegexAsciiInput{}, 9, mut scratch)
	vm.pc = 7
	scratch.registers[1] = 3
	vm.handle_repeat_check(1, 2, none, 17, true)
	assert scratch.registers[1] == 4 && vm.pc == 17
	assert scratch.register_pool == [i32(-1), 3]
	assert scratch.backtrack_stack[0] == RegexSavedState(RegexSavedNormal{
		pc:                  8
		pos:                 9
		reg_snapshot_offset: 0
		modifiers:           vm.modifiers
	})
	vm.handle_repeat_check(1, 2, none, 21, false)
	assert scratch.registers[1] == 4 && vm.pc == 18
	assert scratch.register_pool == [i32(-1), 3, -1, 5]
	assert scratch.backtrack_stack[1] == RegexSavedState(RegexSavedNormal{
		pc:                  21
		pos:                 9
		reg_snapshot_offset: 2
		modifiers:           vm.modifiers
	})
	scratch.registers[1] = 0x7fffffff
	vm.handle_repeat_check(1, 0, none, 21, true)
	assert scratch.registers[1] == i32(-2147483648)
	vm.pc = 0xffffffff
	scratch.registers[1] = -1
	vm.handle_repeat_check(1, 0, none, 21, false)
	assert vm.pc == 0 && scratch.registers[1] == -1
	assert scratch.register_pool.last() == 0
}

fn test_regex_same_matcher_loop_minimum_retains_value_equality_stop_and_overflow() {
	matcher := RegexSimpleMatch(RegexSimpleUnion{
		left:  box_regex_simple_match(RegexLiteral{ code_point: 97 })
		right: box_regex_simple_match(RegexBytecodeCharClass{
			ranges: [RegexCharRange{ start: 1, end: 9 }]
		})
	})
	mut program := &RegexProgram{
		instructions: [
			RegexInstruction(RegexGreedyLoop{
				matcher: matcher.clone()
				min:     0
			}),
			RegexLazyLoop{
				matcher: matcher.clone()
				min:     3
			},
			RegexGreedyLoop{
				matcher: matcher.clone()
				min:     5
			},
			RegexNop{},
			RegexGreedyLoop{
				matcher: matcher.clone()
				min:     7
			},
		]
	}
	mut scratch := RegexVmScratch.new()
	vm := RegexVm.new(program, RegexAsciiInput{}, 0, mut scratch)
	assert vm.same_matcher_loop_suffix_min(0, matcher)? == 8
	assert vm.same_matcher_loop_suffix_min(4, matcher)? == 7
	assert vm.same_matcher_loop_suffix_min(5, matcher) == none
	assert vm.same_matcher_loop_suffix_min(0, RegexLiteral{ code_point: 98 }) == none

	for index, minimums in [[u32(0), 0], [u32(0xffffffff), 1],
		[u32(0xffffffff), 0]] {
		next_program := &RegexProgram{
			instructions: [
				RegexInstruction(RegexGreedyLoop{
					matcher: matcher.clone()
					min:     0
				}),
				RegexLazyLoop{
					matcher: matcher.clone()
					min:     minimums[0]
				},
				RegexGreedyLoop{
					matcher: matcher.clone()
					min:     minimums[1]
				},
				RegexNop{},
			]
		}
		mut next_scratch := RegexVmScratch.new()
		next_vm := RegexVm.new(next_program, RegexAsciiInput{}, 0, mut next_scratch)
		if index == 2 {
			assert next_vm.same_matcher_loop_suffix_min(0, matcher)? == u32(0xffffffff)
		} else {
			assert next_vm.same_matcher_loop_suffix_min(0, matcher) == none
		}
		if index == 1 { assert next_vm.same_matcher_loop_suffix_min(1, matcher) == none
		 }
	}
}
