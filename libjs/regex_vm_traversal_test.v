module libjs

fn test_regex_vm_current_code_point_rejects_positions_inside_unicode_pairs_in_both_directions() {
	input := RegexInput(RegexUtf16Input{
		units: [u16(0x61), 0xd83d, 0xde00, 0xd800, 0x62, 0xdc00]
	})
	program := &RegexProgram{
		unicode: true
	}
	mut scratch := RegexVmScratch.new()
	mut vm := RegexVm.new(program, input, 0, mut scratch)
	for pos, expected in [u32(0x61), 0x1f600, 0xffffffff, 0xd800, 0x62, 0xdc00, 0xffffffff] {
		vm.pos = uint(pos)
		if expected == 0xffffffff {
			assert vm.current_code_point() == none
		} else {
			assert vm.current_code_point()? == expected
		}
	}
	vm.backward = true
	for pos, expected in [u32(0xffffffff), 0x61, 0xffffffff, 0x1f600, 0xd800, 0x62, 0xdc00] {
		vm.pos = uint(pos)
		if expected == 0xffffffff {
			assert vm.current_code_point() == none
		} else {
			assert vm.current_code_point()? == expected
		}
	}
	// The standalone forward decoder reads a low surrogate verbatim; the VM
	// current-character boundary deliberately rejects that interior position.
	assert regex_decode_code_point(true, input, 2) == 0xde00
}

fn test_regex_vm_advancement_and_retreat_preserve_direction_and_complete_pairs() {
	program := &RegexProgram{
		unicode: true
	}
	mut scratch := RegexVmScratch.new()
	mut vm := RegexVm.new(program, RegexUtf16Input{ units: [u16(0xd800), 0xdc00, 0xd800, 0x61] },
		0, mut scratch)
	vm.advance_char()
	assert vm.pos == 2
	vm.advance_char()
	assert vm.pos == 3
	vm.advance_char()
	vm.advance_char()
	assert vm.pos == 4
	vm.backward = true
	vm.advance_char()
	assert vm.pos == 3
	vm.advance_char()
	assert vm.pos == 2
	vm.advance_char()
	vm.advance_char()
	assert vm.pos == 0
	assert vm.advance_one_char(0) == 2 && vm.retreat_one_char(2) == 0
	assert vm.advance_one_char(1) == 2 && vm.retreat_one_char(1) == 0
	assert vm.advance_n_chars(0, 3)? == 4 && vm.advance_n_chars(0, 4) == none
	assert vm.retreat_n_chars(4, 3)? == 0 && vm.retreat_n_chars(4, 4) == none
	assert vm.advance_n_chars(4, 0)? == 4 && vm.retreat_n_chars(0, 0)? == 0
	assert vm.advance_one_char(99) == 99 && vm.advance_n_chars(99, 1) == none
}

fn test_regex_vm_non_unicode_n_character_steps_use_checked_arithmetic_without_input_clamping() {
	program := &RegexProgram{}
	mut scratch := RegexVmScratch.new()
	mut vm := RegexVm.new(program, RegexUtf16Input{ units: [u16(0xd800), 0xdc00] }, 1, mut scratch)
	assert vm.current_code_point()? == 0xdc00
	vm.backward = true
	assert vm.current_code_point()? == 0xd800
	vm.advance_char()
	assert vm.pos == 0
	assert vm.advance_n_chars(0, 9)? == 9
	assert vm.advance_n_chars(0, 0xffffffff)? == uint(0xffffffff)
	assert vm.advance_n_chars(~uint(0), 1) == none
	assert vm.advance_n_chars(~uint(0), 0)? == ~uint(0)
	assert vm.retreat_n_chars(9, 9)? == 0 && vm.retreat_n_chars(8, 9) == none
	assert vm.advance_one_char(9) == 9 && vm.retreat_one_char(9) == 8
}

fn test_regex_vm_byte_input_preserves_raw_code_units_in_unicode_and_non_unicode_modes() {
	for unicode in [false, true] {
		program := &RegexProgram{
			unicode: unicode
		}
		mut scratch := RegexVmScratch.new()
		mut vm := RegexVm.new(program, RegexAsciiInput{ bytes: [u8(0), 0x80, 0xff] }, 0, mut
			scratch)
		for expected in [u32(0), 0x80, 0xff] {
			assert vm.current_code_point()? == expected
			vm.advance_char()
		}
		assert vm.current_code_point() == none
		vm.backward = true
		assert vm.current_code_point()? == 0xff
		vm.advance_char()
		assert vm.current_code_point()? == 0x80
	}
}
