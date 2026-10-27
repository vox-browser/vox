module libjs

fn test_regex_vm_character_matching_advances_only_on_success_and_uses_active_case_modifiers() {
	program := &RegexProgram{}
	mut scratch := RegexVmScratch.new()
	mut vm := RegexVm.new(program, RegexUtf16Input{ units: [u16(0x61), 0xe9, 0x17f, 0xdf] }, 0, mut
		scratch)
	assert !vm.match_char(0x41) && vm.pos == 0
	vm.handle_push_modifiers(true, none, none)
	assert vm.match_char(0x41) && vm.pos == 1
	assert vm.match_char(0xc9) && vm.pos == 2
	assert !vm.match_char(0x53) && vm.pos == 2
	assert vm.match_char(0x17f) && vm.pos == 3
	assert !vm.match_char(0x73) && vm.pos == 3
	assert vm.match_char(0xdf) && vm.pos == 4
	assert !vm.match_char(0x61) && vm.pos == 4
	vm.reset(0)
	assert !vm.modifiers.ignore_case && !vm.match_char(0x41)
}

fn test_regex_vm_unicode_character_matching_retains_pair_boundaries_in_both_directions() {
	program := &RegexProgram{
		unicode:     true
		ignore_case: true
	}
	mut scratch := RegexVmScratch.new()
	mut vm := RegexVm.new(program, RegexUtf16Input{
		units: [u16(0xd801), 0xdc00, 0x212a, 0x17f, 0xd800]
	}, 0, mut scratch)
	assert vm.match_char(0x10428) && vm.pos == 2
	assert vm.match_char(0x6b) && vm.pos == 3
	assert vm.match_char(0x53) && vm.pos == 4
	assert vm.match_char(0xd800) && vm.pos == 5
	vm.backward = true
	assert vm.match_char(0xd800) && vm.pos == 4
	assert vm.match_char(0x73) && vm.pos == 3
	assert vm.match_char(0x4b) && vm.pos == 2
	assert vm.match_char(0x10428) && vm.pos == 0
	assert !vm.match_char(0x10400) && vm.pos == 0
	vm.pos = 1
	assert !vm.match_char(0xd801) && vm.pos == 1
	vm.backward = false
	assert !vm.match_char(0xdc00) && vm.pos == 1
}

fn test_regex_vm_word_boundaries_use_adjacent_code_units_and_ignore_direction() {
	for unicode in [false, true] {
		for ignore_case in [false, true] {
			program := &RegexProgram{
				unicode:     unicode
				ignore_case: ignore_case
			}
			mut scratch := RegexVmScratch.new()
			mut vm := RegexVm.new(program, RegexUtf16Input{
				units: [u16(0x20), 0x212a, 0x17f, 0x61, 0xd801, 0xdc00]
			}, 0, mut scratch)
			expected := if unicode && ignore_case { [false, true, false, false, true, false, false] } else { [
					false,
					false,
					false,
					true,
					true,
					false,
					false,
				] }
			for pos, boundary in expected {
				vm.pos = uint(pos)
				assert vm.at_word_boundary() == boundary
				vm.backward = true
				assert vm.at_word_boundary() == boundary
				vm.backward = false
			}
		}
	}
	mut scratch := RegexVmScratch.new()
	mut vm := RegexVm.new(&RegexProgram{}, RegexAsciiInput{ bytes: [u8(0x5f), 0x80, 0x35] }, 0, mut
		scratch)
	for pos in 0 .. 4 {
		vm.pos = uint(pos)
		assert vm.at_word_boundary()
	}
}
