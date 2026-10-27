module libjs

// LibRegex/Rust/src/vm.rs::match_backref. Register lookup uses optional reads;
// any missing/unmatched capture succeeds without consuming input.
pub fn (mut vm RegexVm) match_backref(index u32) bool {
	start_index := uint(index) * 2
	end_index := start_index + 1
	start := if start_index < uint(vm.scratch.registers.len) {
		vm.scratch.registers[int(start_index)]
	} else {
		i32(-1)
	}
	end := if end_index < uint(vm.scratch.registers.len) {
		vm.scratch.registers[int(end_index)]
	} else {
		i32(-1)
	}
	if start < 0 || end < 0 { return true }
	cap_start := uint(start)
	cap_end := uint(end)
	if vm.program.unicode { return vm.match_backref_unicode(cap_start, cap_end) }
	length := cap_end - cap_start
	if vm.backward {
		if vm.pos < length { return false }
		if vm.modifiers.ignore_case {
			for offset := uint(0); offset < length; offset++ {
				if !regex_case_fold_eq(u32(vm.input_code_unit(cap_start + offset)), u32(vm.input_code_unit(
					vm.pos - length + offset)), false) {
					return false
				}
			}
		} else if !vm.input.ranges_equal(cap_start, vm.pos - length, length) {
			return false
		}
		vm.pos -= length
	} else {
		if vm.pos + length > vm.input_len() { return false }
		if vm.modifiers.ignore_case {
			for offset := uint(0); offset < length; offset++ {
				if !regex_case_fold_eq(u32(vm.input_code_unit(cap_start + offset)), u32(vm.input_code_unit(
					vm.pos + offset)), false) {
					return false
				}
			}
		} else if !vm.input.ranges_equal(cap_start, vm.pos, length) {
			return false
		}
		vm.pos += length
	}
	return true
}

// Compare code points. A backwards reference first walks back by the capture's
// code-point count, then compares forwards using the same decoder on each side.
pub fn (mut vm RegexVm) match_backref_unicode(cap_start uint, cap_end uint) bool {
	mut cap_pos := cap_start
	mut input_pos := vm.pos
	if vm.backward {
		mut count := 0
		mut pos := cap_start
		for pos < cap_end {
			pos += regex_code_point_len(true, vm.input, pos)
			count++
		}
		mut check_pos := vm.pos
		for _ in 0 .. count {
			if check_pos == 0 { return false }
			check_pos--
			if check_pos > 0 && is_utf16_low_surrogate(vm.input_code_unit(check_pos))
				&& is_utf16_high_surrogate(vm.input_code_unit(check_pos - 1)) {
				check_pos--
			}
		}
		mut a := cap_start
		mut b := check_pos
		for a < cap_end {
			point_a := regex_decode_code_point(true, vm.input, a)
			if b >= vm.pos { return false }
			point_b := regex_decode_code_point(true, vm.input, b)
			if vm.modifiers.ignore_case {
				if !regex_case_fold_eq(point_a, point_b, true) { return false }
			} else if point_a != point_b {
				return false
			}
			a += regex_code_point_len(true, vm.input, a)
			b += regex_code_point_len(true, vm.input, b)
		}
		vm.pos = check_pos
	} else {
		for cap_pos < cap_end {
			if input_pos >= vm.input_len() { return false }
			captured := regex_decode_code_point(true, vm.input, cap_pos)
			current := regex_decode_code_point(true, vm.input, input_pos)
			if vm.modifiers.ignore_case {
				if !regex_case_fold_eq(captured, current, true) { return false }
			} else if captured != current {
				return false
			}
			cap_pos += regex_code_point_len(true, vm.input, cap_pos)
			input_pos += regex_code_point_len(true, vm.input, input_pos)
		}
		vm.pos = input_pos
	}
	return true
}

pub fn (mut vm RegexVm) match_backref_named(name string) bool {
	mut captured_index := ?u32(none)
	mut any_group_exists := false
	for group in vm.program.named_groups {
		if group.name == name {
			any_group_exists = true
			start_index := uint(group.index) * 2
			end_index := start_index + 1
			start := if start_index < uint(vm.scratch.registers.len) {
				vm.scratch.registers[int(start_index)]
			} else {
				i32(-1)
			}
			end := if end_index < uint(vm.scratch.registers.len) {
				vm.scratch.registers[int(end_index)]
			} else {
				i32(-1)
			}
			if start >= 0 && end >= 0 {
				captured_index = group.index
				break
			}
		}
	}
	if !any_group_exists { return true }
	if index := captured_index { return vm.match_backref(index) }
	return true
}
