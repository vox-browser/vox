module libjs

fn regex_backreference_test_vm(units []u16, registers []i32, pos uint, backward bool, unicode bool, ignore_case bool, groups []RegexNamedGroupEntry) &RegexVm {
	program := &RegexProgram{
		register_count: u32(registers.len)
		unicode:        unicode
		ignore_case:    ignore_case
		named_groups:   groups
	}
	mut scratch := RegexVmScratch.new()
	mut vm := RegexVm.new(program, RegexUtf16Input{ units: units }, pos, mut scratch)
	for index, value in registers {
		scratch.registers[index] = value
	}
	vm.backward = backward
	return vm
}

fn test_regex_backreferences_missing_unmatched_and_empty_captures_consume_nothing() {
	for registers in [[]i32{}, [i32(0)], [i32(-1), 1], [i32(0), -1],
		[i32(-1), -1], [i32(1), 1]] {
		for unicode in [false, true] {
			for backward in [false, true] {
				mut vm := regex_backreference_test_vm([u16(0x61)], registers, 1, backward, unicode,
					true, [])
				assert vm.match_backref(0) && vm.pos == 1
				assert vm.match_backref(0xffffffff) && vm.pos == 1
				assert vm.scratch.registers == registers
			}
		}
	}
}

fn test_regex_legacy_backreferences_preserve_position_on_mismatch_and_compare_raw_units() {
	for backward in [false, true] {
		for ignore_case in [false, true] {
			start := if backward { uint(4) } else { uint(2) }
			mut vm := regex_backreference_test_vm([u16(0x61), 0xe9, 0x41, 0xc9], [
				i32(0),
				2,
			], start, backward, false, ignore_case, [])
			assert vm.match_backref(0) == ignore_case
			assert vm.pos == if ignore_case {
				if backward {
					uint(2)
				} else {
					uint(4)
				}
			} else {
				start
			}
			assert vm.pc == 0 && vm.scratch.registers == [i32(0), 2]
			mut failed := regex_backreference_test_vm([u16(0x61), 0x62, 0x61, 0x63], [
				i32(0),
				2,
			], start, backward, false, ignore_case, [])
			assert !failed.match_backref(0) && failed.pos == start
		}
		mut short := regex_backreference_test_vm([u16(0x61), 0x62], [i32(0), 2], 1, backward,
			false, false, [])
		assert !short.match_backref(0) && short.pos == 1
	}
	program := &RegexProgram{
		register_count: 2
	}
	mut scratch := RegexVmScratch.new()
	mut bytes := RegexVm.new(program, RegexAsciiInput{ bytes: [u8(0x80), 0xff, 0x80, 0xff] }, 2, mut
		scratch)
	scratch.registers[0] = 0
	scratch.registers[1] = 2
	assert bytes.match_backref(0) && bytes.pos == 4
}

fn test_regex_unicode_backreferences_compare_pairs_in_both_directions_and_commit_after_success() {
	units := [u16(0xd801), 0xdc00, 0x212a, 0xd801, 0xdc28, 0x6b]
	for backward in [false, true] {
		start := if backward { uint(6) } else { uint(3) }
		mut vm := regex_backreference_test_vm(units, [i32(0), 3], start, backward, true, true, [])
		assert vm.match_backref(0)
		assert vm.pos == if backward {
			uint(3)
		} else {
			uint(6)
		}
		mut sensitive := regex_backreference_test_vm(units, [i32(0), 3], start, backward, true,
			false, [])
		assert !sensitive.match_backref(0) && sensitive.pos == start
		mut legacy :=
			regex_backreference_test_vm(units, [i32(0), 3], start, backward, false, true, [])
		assert !legacy.match_backref(0) && legacy.pos == start
		mut failed := regex_backreference_test_vm([u16(0xd801), 0xdc00, 0x61, 0xd801, 0xdc28, 0x62], [
			i32(0),
			3,
		], start, backward, true, true, [])
		assert !failed.match_backref(0) && failed.pos == start
	}
	// The source decoder reads the complete pair even when cap_end cuts it;
	// a capture starting on a low half instead reads that half as a code point.
	mut clipped := regex_backreference_test_vm([u16(0xd800), 0xdc00, 0xd800, 0xdc00], [
		i32(0),
		1,
	], 2, false, true, false, [])
	assert clipped.match_backref(0) && clipped.pos == 4
	mut low := regex_backreference_test_vm([u16(0xd800), 0xdc00, 0xd800, 0xdc00], [
		i32(1),
		2,
	], 3, false, true, false, [])
	assert low.current_code_point() == none
	assert low.match_backref(0) && low.pos == 4
}

fn test_regex_named_backreferences_select_the_first_participating_duplicate_and_keep_names_exact() {
	groups := [RegexNamedGroupEntry{ name: 'same', index: 1 },
		RegexNamedGroupEntry{ name: 'same', index: 2 }, RegexNamedGroupEntry{ name: 'β', index: 2 }]
	units := [u16(0x61), 0x62, 0x62]
	mut skipped := regex_backreference_test_vm(units, [i32(-1), -1, -1, -1, 1, 2], 2, false, false,
		false, groups)
	assert skipped.match_backref_named('same') && skipped.pos == 3
	skipped.pos = 2
	assert skipped.match_backref_named('β') && skipped.pos == 3
	mut first := regex_backreference_test_vm(units, [i32(-1), -1, 0, 1, 1, 2], 2, false, false,
		false, groups)
	assert !first.match_backref_named('same') && first.pos == 2
	assert first.match_backref_named('Same') && first.pos == 2
	assert first.match_backref_named('missing') && first.pos == 2
	mut empty := regex_backreference_test_vm(units, [i32(-1), -1, 1, 1, 1, 2], 2, false, false,
		false, groups)
	assert empty.match_backref_named('same') && empty.pos == 2
	mut unmatched := regex_backreference_test_vm(units, [i32(-1), -1, -1, -1], 2, false, false,
		false, groups)
	assert unmatched.match_backref_named('same') && unmatched.pos == 2
}
