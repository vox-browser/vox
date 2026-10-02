module libjs

fn test_regex_assertion_endpoints_increment_only_the_instruction() {
	mut scratch := RegexVmScratch.new()
	mut vm := RegexVm.new(&RegexProgram{}, RegexAsciiInput{ bytes: [u8(65), 66] }, 0, mut scratch)
	vm.pc = 8
	vm.steps = 13
	vm.backward = true
	assert vm.handle_assert_start(false) == none
	assert vm.pc == 9 && vm.pos == 0 && vm.steps == 13 && vm.backward
	vm.pos = 1
	assert vm.handle_assert_start(false)? == .no_match
	assert vm.pc == 9 && vm.pos == 1
	assert vm.handle_assert_end(false, 2)? == .no_match
	assert vm.pc == 9 && vm.pos == 1
	vm.pos = 2
	assert vm.handle_assert_end(false, 2) == none
	assert vm.pc == 10 && vm.pos == 2
	vm.pos = 3
	assert vm.handle_assert_end(false, 2) == none
	assert vm.pc == 11 && vm.pos == 3
	// The fast loop supplies its cached length rather than rereading the input.
	vm.pos = 1
	assert vm.handle_assert_end(false, 1) == none
	assert vm.pc == 12 && vm.pos == 1 && vm.steps == 13 && vm.backward
}

fn test_regex_assertion_multiline_payload_and_active_scope_accept_exact_line_terminators() {
	for unit in [u16(9), 10, 13, 32, 0x85, 0x2028, 0x2029, 0xd800, 0xdc00] {
		for use_active in [false, true] {
			mut scratch := RegexVmScratch.new()
			mut vm := RegexVm.new(&RegexProgram{}, RegexUtf16Input{ units: [u16(65), unit, 66] }, 2, mut scratch)
			vm.modifiers.multiline = use_active
			vm.pc = 7
			is_line := unit in [u16(10), 13, 0x2028, 0x2029]
			result := vm.handle_assert_start(!use_active)
			assert (result == none) == is_line
			assert vm.pc == if is_line { u32(8) } else { u32(7) }
			vm.pc = 7
			vm.pos = 1
			end_result := vm.handle_assert_end(!use_active, 3)
			assert (end_result == none) == is_line
			assert vm.pc == if is_line { u32(8) } else { u32(7) }
			vm.modifiers.multiline = false
			vm.pos = 2
			assert vm.handle_assert_start(false)? == .no_match
		}
	}
}

fn test_regex_assertion_failure_restores_a_saved_choice_and_respects_the_floor() {
	mut scratch := RegexVmScratch.new()
	mut vm := RegexVm.new(&RegexProgram{}, RegexAsciiInput{ bytes: [u8(65), 66] }, 0, mut scratch)
	scratch.registers = [i32(1), 2]
	vm.push_backtrack(17, 0)
	vm.pos = 1
	vm.pc = 9
	scratch.registers = [i32(3), 4]
	vm.modifiers.dot_all = true
	vm.bt_floor = 1
	assert vm.handle_assert_start(false)? == .no_match
	assert vm.pc == 9 && vm.pos == 1 && scratch.registers == [i32(3), 4]
	assert scratch.backtrack_stack.len == 1 && vm.modifiers.dot_all
	vm.bt_floor = 0
	assert vm.handle_assert_start(false) == none
	assert vm.pc == 17 && vm.pos == 0 && scratch.registers == [i32(1), 2]
	assert !vm.modifiers.dot_all && scratch.register_pool.len == 0
	assert vm.fail_current_path()? == .no_match
}

fn test_regex_word_boundary_assertion_preserves_unicode_word_rules_and_choice_resume() {
	for unicode in [false, true] {
		program := &RegexProgram{ unicode: unicode, ignore_case: true }
		mut scratch := RegexVmScratch.new()
		mut vm := RegexVm.new(program, RegexUtf16Input{ units: [u16(0x17f)] }, 0, mut scratch)
		vm.pc = 3
		vm.steps = 7
		assert vm.handle_word_boundary_assert(unicode) == none
		assert vm.pc == 4 && vm.pos == 0 && vm.steps == 7
		vm.push_backtrack(12, 1)
		assert vm.handle_word_boundary_assert(!unicode) == none
		assert vm.pc == 12 && vm.pos == 1 && scratch.backtrack_stack.len == 0
		assert vm.handle_word_boundary_assert(!unicode)? == .no_match
		assert vm.pc == 12 && vm.pos == 1
	}
}
