module libjs

import os

fn test_regex_vm_construction_resizes_scratch_and_borrows_the_owning_storage() {
	for count in [u32(0), 1, 2, 5, 12] {
		program := &RegexProgram{
			register_count: count
			ignore_case:    true
			dot_all:        true
		}
		for initial in [0, 2, 8] {
			mut scratch := RegexVmScratch.new()
			scratch.registers = []i32{len: initial, cap: 16, init: 99}
			scratch.register_pool << i32(9)
			scratch.modifier_stack << RegexActiveModifiers{
				multiline: true
			}
			scratch.backtrack_stack << RegexSavedNormal{
				pc: 9
			}
			vm := RegexVm.new(program, RegexAsciiInput{ bytes: [u8(0x61), 0x80] }, 7, mut scratch)
			assert voidptr(vm.scratch) == voidptr(scratch)
				&& voidptr(vm.program) == voidptr(program)
			assert scratch.registers == []i32{len: int(count), init: -1}
			assert scratch.register_pool.len == 0 && scratch.modifier_stack.len == 0
				&& scratch.backtrack_stack.len == 0
			assert scratch.registers.cap >= 16
			assert vm.pc == 0 && vm.pos == 7 && vm.steps == 0 && !vm.backward && vm.bt_floor == 0
			assert vm.modifiers == RegexActiveModifiers{
				ignore_case: true
				dot_all:     true
			}
			assert vm.input_len() == 2 && vm.input_code_unit(1) == 0x80
		}
	}
}

fn test_regex_vm_reset_reuses_all_arrays_and_clears_per_attempt_state() {
	program := &RegexProgram{
		register_count: 4
		multiline:      true
	}
	mut scratch := RegexVmScratch.new()
	mut vm := RegexVm.new(program, RegexUtf16Input{}, 0, mut scratch)
	vm.scratch.registers[0] = 42
	vm.handle_push_modifiers(true, false, true)
	vm.push_backtrack(5, 7)
	vm.pc = 99
	vm.steps = 100
	vm.backward = true
	vm.bt_floor = 1
	registers_data := scratch.registers.data
	pool_data := scratch.register_pool.data
	backtrack_data := scratch.backtrack_stack.data
	modifier_data := scratch.modifier_stack.data
	vm.reset(3)
	assert scratch.registers.data == registers_data && scratch.register_pool.data == pool_data
	assert scratch.backtrack_stack.data == backtrack_data
		&& scratch.modifier_stack.data == modifier_data
	assert scratch.registers == [i32(-1), -1, -1, -1]
	assert scratch.register_pool.len == 0 && scratch.backtrack_stack.len == 0
		&& scratch.modifier_stack.len == 0
	assert vm.pc == 0 && vm.pos == 3 && vm.steps == 0 && !vm.backward && vm.bt_floor == 0
	assert vm.modifiers == RegexActiveModifiers{
		multiline: true
	}
}

fn test_regex_vm_snapshots_are_flat_copies_and_saved_choices_retain_all_metadata() {
	program := &RegexProgram{
		register_count: 3
	}
	mut scratch := RegexVmScratch.new()
	mut vm := RegexVm.new(program, RegexAsciiInput{}, 0, mut scratch)
	scratch.registers[0] = 10
	scratch.registers[1] = 20
	scratch.registers[2] = 30
	assert vm.snapshot_registers() == 0
	vm.handle_push_modifiers(true, none, true)
	vm.push_backtrack(7, 9)
	vm.push_backtrack_modified(11, 12, 1, 99)
	assert scratch.registers == [i32(10), 20, 30]
	assert scratch.register_pool == [i32(10), 20, 30, 10, 20, 30, 10, 99, 30]
	assert scratch.backtrack_stack[0] == RegexSavedState(RegexSavedNormal{
		pc:                  7
		pos:                 9
		reg_snapshot_offset: 3
		modifiers:           RegexActiveModifiers{
			ignore_case: true
			dot_all:     true
		}
		modifier_stack_len:  1
	})
	vm.backward = true
	vm.push_greedy_backtrack(13, 1, 8, 2)
	vm.push_lazy_backtrack(14, 4, none, 3)
	assert scratch.backtrack_stack[2] == RegexSavedState(RegexSavedGreedy{
		pc:                  13
		start_pos:           1
		current_pos:         8
		reg_snapshot_offset: 9
		min:                 2
		backward:            true
		modifiers:           vm.modifiers
		modifier_stack_len:  1
	})
	assert scratch.backtrack_stack[3] == RegexSavedState(RegexSavedLazy{
		pc:                  14
		pos:                 4
		reg_snapshot_offset: 12
		max:                 none
		consumed:            3
		modifiers:           vm.modifiers
		modifier_stack_len:  1
	})
	vm.restore_registers(6)
	assert scratch.registers == [i32(10), 99, 30]
	vm.restore_registers(0)
	assert scratch.registers == [i32(10), 20, 30]
	assert scratch.register_pool.len == 15
}

fn test_regex_vm_modifier_stack_preserves_false_none_and_empty_pop_semantics() {
	program := &RegexProgram{
		ignore_case: true
		multiline:   true
	}
	mut scratch := RegexVmScratch.new()
	mut vm := RegexVm.new(program, RegexAsciiInput{}, 0, mut scratch)
	vm.handle_push_modifiers(false, none, true)
	assert vm.pc == 1 && vm.modifiers == RegexActiveModifiers{
		ignore_case: false
		multiline:   true
		dot_all:     true
	}
	vm.handle_push_modifiers(none, false, none)
	assert vm.pc == 2 && vm.modifiers == RegexActiveModifiers{
		dot_all: true
	}
	vm.handle_pop_modifiers()
	assert vm.pc == 3 && vm.modifiers == RegexActiveModifiers{
		multiline: true
		dot_all:   true
	}
	vm.handle_pop_modifiers()
	vm.handle_pop_modifiers()
	assert vm.pc == 5 && vm.modifiers == RegexActiveModifiers{
		ignore_case: true
		multiline:   true
	}
	assert scratch.modifier_stack.len == 0
}

fn test_regex_vm_invalid_snapshot_ranges_keep_the_source_panic_boundary() {
	mode := os.getenv('VOX2_REGEX_SNAPSHOT_PANIC')
	if mode != '' {
		count := if mode == 'empty' { u32(0) } else { u32(2) }
		program := &RegexProgram{
			register_count: count
		}
		mut scratch := RegexVmScratch.new()
		mut vm := RegexVm.new(program, RegexAsciiInput{}, 0, mut scratch)
		if mode == 'modified' {
			vm.push_backtrack_modified(0, 0, 2, 7)
		} else {
			vm.snapshot_registers()
			vm.restore_registers(1)
		}
		assert false
		return
	}
	for probe in ['empty', 'short', 'modified'] {
		mut environment := os.environ()
		environment['VOX2_REGEX_SNAPSHOT_PANIC'] = probe
		mut process := os.new_process(os.executable())
		process.set_environment(environment)
		process.set_redirect_stdio()
		process.run()
		process.wait()
		output := process.stdout_slurp() + process.stderr_slurp()
		assert process.code != 0 && output.contains('snapshot index out of bounds'), output
		process.close()
	}
}
