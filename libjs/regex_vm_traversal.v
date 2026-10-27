module libjs

// LibRegex/Rust/src/vm.rs position/code-point traversal, including the
// lookbehind boundary between surrogate halves. These do not match characters.
pub fn (vm RegexVm) current_code_point() ?u32 {
	if vm.backward {
		if vm.pos == 0 { return none }
		if vm.program.unicode && vm.pos < vm.input_len()
			&& is_utf16_low_surrogate(vm.input_code_unit(vm.pos))
			&& is_utf16_high_surrogate(vm.input_code_unit(vm.pos - 1)) {
			return none
		}
		unit := vm.input_code_unit(vm.pos - 1)
		if vm.program.unicode && is_utf16_low_surrogate(unit) && vm.pos >= 2
			&& is_utf16_high_surrogate(vm.input_code_unit(vm.pos - 2)) {
			hi := u32(vm.input_code_unit(vm.pos - 2))
			return 0x10000 + ((hi - 0xd800) << 10) + (u32(unit) - 0xdc00)
		}
		return u32(unit)
	}
	if vm.pos >= vm.input_len() { return none }
	unit := vm.input_code_unit(vm.pos)
	if vm.program.unicode && is_utf16_high_surrogate(unit) && vm.pos + 1 < vm.input_len()
		&& is_utf16_low_surrogate(vm.input_code_unit(vm.pos + 1)) {
		return 0x10000 + ((u32(unit) - 0xd800) << 10) + (u32(vm.input_code_unit(vm.pos + 1)) -
			0xdc00)
	}
	if vm.program.unicode && is_utf16_low_surrogate(unit) && vm.pos > 0
		&& is_utf16_high_surrogate(vm.input_code_unit(vm.pos - 1)) {
		return none
	}
	return u32(unit)
}

pub fn (mut vm RegexVm) advance_char() {
	if vm.backward {
		if vm.pos > 0 {
			vm.pos--
			if vm.program.unicode && vm.pos > 0
				&& is_utf16_low_surrogate(vm.input_code_unit(vm.pos))
				&& is_utf16_high_surrogate(vm.input_code_unit(vm.pos - 1)) {
				vm.pos--
			}
		}
	} else if vm.pos < vm.input_len() {
		unit := vm.input_code_unit(vm.pos)
		vm.pos++
		if vm.program.unicode && is_utf16_high_surrogate(unit) && vm.pos < vm.input_len()
			&& is_utf16_low_surrogate(vm.input_code_unit(vm.pos)) {
			vm.pos++
		}
	}
}

pub fn (vm RegexVm) retreat_one_char(pos uint) uint {
	if pos == 0 { return 0 }
	if vm.program.unicode && pos >= 2 && is_utf16_low_surrogate(vm.input_code_unit(pos - 1))
		&& is_utf16_high_surrogate(vm.input_code_unit(pos - 2)) {
		return pos - 2
	}
	return pos - 1
}

pub fn (vm RegexVm) advance_one_char(pos uint) uint {
	if pos >= vm.input_len() { return pos }
	mut next := pos + 1
	if vm.program.unicode && next < vm.input_len()
		&& is_utf16_low_surrogate(vm.input_code_unit(next)) && next >= 1
		&& is_utf16_high_surrogate(vm.input_code_unit(next - 1)) {
		next++
	}
	return next
}

pub fn (vm RegexVm) retreat_n_chars(start uint, count u32) ?uint {
	mut pos := start
	if !vm.program.unicode {
		if uint(count) > pos { return none }
		return pos - uint(count)
	}
	for _ in 0 .. count {
		next := vm.retreat_one_char(pos)
		if next == pos { return none }
		pos = next
	}
	return pos
}

pub fn (vm RegexVm) advance_n_chars(start uint, count u32) ?uint {
	mut pos := start
	if !vm.program.unicode {
		if uint(count) > ~uint(0) - pos { return none }
		return pos + uint(count)
	}
	for _ in 0 .. count {
		next := vm.advance_one_char(pos)
		if next == pos { return none }
		pos = next
	}
	return pos
}
