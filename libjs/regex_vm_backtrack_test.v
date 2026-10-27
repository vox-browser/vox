module libjs

fn test_regex_backtrack_normal_restores_snapshots_modifiers_and_scopes_without_crossing_floor() {
	mut scratch := RegexVmScratch.new()
	mut vm := RegexVm.new(&RegexProgram{}, RegexAsciiInput{ bytes: [u8(65), 66] }, 0, mut scratch)
	scratch.registers = [i32(1), 2]
	vm.handle_push_modifiers(true, none, true)
	vm.push_backtrack(9, 2)
	vm.handle_push_modifiers(false, true, false)
	scratch.registers = [i32(7), 8]
	vm.pc = 4
	vm.pos = 0
	vm.steps = 13
	vm.backward = true
	vm.bt_floor = 1
	assert !vm.backtrack()
	assert vm.pc == 4 && vm.pos == 0 && scratch.registers == [i32(7), 8]
	assert scratch.register_pool == [i32(1), 2] && scratch.modifier_stack.len == 2
	vm.bt_floor = 0
	assert vm.backtrack()
	assert vm.pc == 9 && vm.pos == 2 && scratch.registers == [i32(1), 2]
	assert vm.modifiers == RegexActiveModifiers{
		ignore_case: true
		dot_all:     true
	}
	assert scratch.register_pool.len == 0 && scratch.modifier_stack.len == 1
	assert vm.steps == 13 && vm.backward
	assert !vm.backtrack() && vm.pc == 9 && vm.pos == 2
}

fn test_regex_backtrack_greedy_requeues_only_above_its_minimum_and_reuses_snapshot_storage() {
	matcher := RegexSimpleMatch(RegexAnyChar{
		dot_all: true
	})
	program := &RegexProgram{
		instructions: [RegexInstruction(RegexGreedyLoop{
			matcher: matcher
			min:     1
		}), RegexNop{}]
	}
	mut scratch := RegexVmScratch.new()
	mut vm := RegexVm.new(program, RegexAsciiInput{ bytes: [u8(65), 66, 67, 68] }, 4, mut scratch)
	scratch.registers = [i32(10), 20]
	vm.push_greedy_backtrack(0, 0, 4, 1)
	scratch.registers = [i32(30), 40]
	for expected in [uint(3), 2, 1] {
		assert vm.backtrack() && vm.pos == expected && vm.pc == 1
		assert scratch.registers == [i32(10), 20]
		assert scratch.backtrack_stack.len == if expected > 1 {
			1
		} else {
			0
		}
		assert scratch.register_pool == if expected > 1 {
			[i32(10), 20]
		} else {
			[]i32{}
		}
	}
	assert !vm.backtrack()
}

fn test_regex_backtrack_greedy_literal_skip_falls_through_to_the_next_saved_choice() {
	program := &RegexProgram{
		instructions: [
			RegexInstruction(RegexGreedyLoop{
				matcher: RegexAnyChar{
					dot_all: true
				}
				min:     0
			}),
			RegexLiteral{
				code_point: 65
			},
		]
	}
	mut scratch := RegexVmScratch.new()
	mut vm := RegexVm.new(program, RegexAsciiInput{ bytes: [u8(66), 65, 66, 66] }, 4, mut scratch)
	scratch.registers = [i32(1), 2]
	vm.push_backtrack(9, 0)
	scratch.registers = [i32(3), 4]
	vm.push_greedy_backtrack(0, 0, 4, 0)
	assert vm.backtrack() && vm.pc == 1 && vm.pos == 1
	assert scratch.registers == [i32(3), 4] && scratch.backtrack_stack.len == 2
	assert vm.backtrack() && vm.pc == 9 && vm.pos == 0
	assert scratch.registers == [i32(1), 2] && scratch.register_pool.len == 0
	assert scratch.backtrack_stack.len == 0
}

fn test_regex_backtrack_supplementary_literal_uses_saved_greedy_direction_without_changing_vm_direction() {
	program := &RegexProgram{
		unicode:      true
		instructions: [
			RegexInstruction(RegexGreedyLoop{
				matcher: RegexAnyChar{
					dot_all: true
				}
			}),
			RegexLiteral{
				code_point: 0x10400
			},
		]
	}
	input := RegexInput(RegexUtf16Input{
		units: [u16(0xd801), 0xdc00, 0xd801, 0xdc00]
	})
	for backward in [false, true] {
		mut scratch := RegexVmScratch.new()
		mut vm := RegexVm.new(program, input, 0, mut scratch)
		vm.backward = backward
		vm.push_greedy_backtrack(0, if backward { uint(4) } else { uint(0) }, if backward {
			uint(0)
		} else {
			uint(4)
		}, 0)
		vm.backward = !backward
		assert vm.backtrack() && vm.pos == 2 && vm.pc == 1
		assert vm.backward == !backward
		assert vm.backtrack() && vm.pos == if backward {
			uint(4)
		} else {
			uint(0)
		}
		assert vm.backward == !backward && scratch.backtrack_stack.len == 0
		assert !vm.backtrack()
	}
}

fn test_regex_backtrack_greedy_suffix_deficit_gives_back_the_whole_required_run() {
	matcher := RegexSimpleMatch(RegexAnyChar{
		dot_all: true
	})
	program := &RegexProgram{
		instructions: [RegexInstruction(RegexGreedyLoop{
			matcher: matcher
			min:     1
		}), RegexGreedyLoop{ matcher: matcher.clone(), min: 2 },
			RegexLazyLoop{ matcher: matcher.clone(), min: 1 }, RegexNop{}]
	}
	for backward in [false, true] {
		mut scratch := RegexVmScratch.new()
		mut vm := RegexVm.new(program, RegexAsciiInput{ bytes: [u8(65), 66, 67, 68] }, 0, mut
			scratch)
		vm.backward = backward
		vm.push_greedy_backtrack(0, if backward { uint(4) } else { uint(0) }, if backward {
			uint(0)
		} else {
			uint(4)
		}, 1)
		assert vm.backtrack() && vm.pos == if backward {
			uint(3)
		} else {
			uint(1)
		}
		assert vm.pc == 1 && scratch.backtrack_stack.len == 0
		assert !vm.backtrack()
	}
}

fn test_regex_backtrack_lazy_restores_case_modifiers_consumes_and_falls_back_at_maximum() {
	program := &RegexProgram{
		instructions: [
			RegexInstruction(RegexLazyLoop{
				matcher: RegexLiteral{
					code_point: 65
				}
				max:     u32(2)
			}),
			RegexNop{},
		]
	}
	mut scratch := RegexVmScratch.new()
	mut vm := RegexVm.new(program, RegexAsciiInput{ bytes: [u8(97), 65, 66] }, 0, mut scratch)
	scratch.registers = [i32(1), 2]
	vm.push_backtrack(9, 2)
	vm.handle_push_modifiers(true, none, none)
	scratch.registers = [i32(3), 4]
	vm.push_lazy_backtrack(0, 0, u32(2), 0)
	vm.modifiers.ignore_case = false
	assert vm.backtrack() && vm.pos == 1 && vm.pc == 1 && vm.modifiers.ignore_case
	assert scratch.registers == [i32(3), 4] && scratch.backtrack_stack.len == 2
	assert vm.backtrack() && vm.pos == 2 && vm.pc == 1
	assert vm.backtrack() && vm.pos == 2 && vm.pc == 9 && !vm.modifiers.ignore_case
	assert scratch.registers == [i32(1), 2] && scratch.backtrack_stack.len == 0
	assert scratch.register_pool.len == 0 && scratch.modifier_stack.len == 0
}

fn test_regex_backtrack_lazy_failure_preserves_source_position_update_order() {
	program := &RegexProgram{
		unicode:      true
		instructions: [
			RegexInstruction(RegexLazyLoop{
				matcher: RegexLiteral{
					code_point: 65
				}
			}),
		]
	}
	input := RegexInput(RegexUtf16Input{
		units: [u16(0xd801), 0xdc00, 66]
	})
	for maximum in [?u32(none), ?u32(u32(0))] {
		mut scratch := RegexVmScratch.new()
		mut vm := RegexVm.new(program, input, 2, mut scratch)
		vm.pc = 9
		vm.push_lazy_backtrack(0, 1, maximum, 0)
		assert !vm.backtrack()
		assert vm.pc == 9 && vm.pos == if maximum == none {
			uint(1)
		} else {
			uint(2)
		}
		assert scratch.backtrack_stack.len == 0 && scratch.register_pool.len == 0
	}
}
