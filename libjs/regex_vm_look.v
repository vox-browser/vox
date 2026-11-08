// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
// LibRegex/Rust/src/vm.rs: isolated lookaround and atomic string properties.
module libjs

pub fn (mut vm RegexVm) handle_look_start(positive bool, forward bool, end u32) ?RegexVmResult {
	if vm.look_depth >= 128 { return .limit_exceeded }
	saved_pos := vm.pos
	saved_choices := vm.scratch.backtrack_stack.len
	saved_pool := vm.scratch.register_pool.len
	saved_floor := vm.bt_floor
	saved_backward := vm.backward
	register_offset := vm.snapshot_registers()
	vm.bt_floor = uint(saved_choices)
	vm.pc++
	vm.backward = !forward
	vm.look_depth++
	result := vm.run()
	vm.look_depth--
	vm.bt_floor = saved_floor
	vm.backward = saved_backward
	vm.pos = saved_pos
	vm.scratch.backtrack_stack.trim(saved_choices)
	if result == .limit_exceeded { return result }
	matched := result == .match
	if !positive || !matched { vm.restore_registers(register_offset) }
	vm.scratch.register_pool.trim(saved_pool)
	if matched == positive {
		vm.pc = end
		return none
	}
	return vm.fail_current_path()
}

pub fn (mut vm RegexVm) handle_string_property_match(strings []u32, property RegexUnicodePropertyData) ?RegexVmResult {
	mut offset := 0
	for offset < strings.len {
		length := int(strings[offset])
		offset++
		if length > strings.len - offset { break }
		mut position := vm.pos
		mut matched := true
		for index in 0 .. length {
			mut point := u32(0)
			if vm.backward {
				if position == 0 {
					matched = false
					break
				}
				position--
				point = u32(vm.input_code_unit(position))
				if vm.program.unicode && is_utf16_low_surrogate(u16(point)) && position > 0
					&& is_utf16_high_surrogate(vm.input_code_unit(position - 1)) {
					position--
					point = 0x10000 + ((u32(vm.input_code_unit(position)) - 0xd800) << 10) + point - 0xdc00
				}
			} else {
				if position >= vm.input_len() {
					matched = false
					break
				}
				point = regex_decode_code_point(vm.program.unicode, vm.input, position)
				position += regex_code_point_len(vm.program.unicode, vm.input, position)
			}
			if point != strings[offset + index] {
				matched = false
				break
			}
		}
		if matched && length > 0 {
			vm.pos = position
			vm.pc++
			return none
		}
		offset += length
	}
	if point := vm.current_code_point() {
		if regex_match_unicode_property_resolved(point, property.name, property.value, property.resolved) {
			vm.advance_char()
			vm.pc++
			return none
		}
	}
	return vm.fail_current_path()
}
