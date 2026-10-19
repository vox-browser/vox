module webassembly

import libjs
import os
import strconv

fn source_shift_integer_case(name string, lhs u64, rhs u64) u64 {
	return match name {
		'shl_u32' { u64(binary_shift_left_u32(u32(lhs), u32(rhs))) }
		'shl_u64' { binary_shift_left_u64(lhs, rhs) }
		'shr_i32' { u64(i64(binary_shift_right_i32(i32(lhs), i32(rhs)))) }
		'shr_u32' { u64(binary_shift_right_u32(u32(lhs), u32(rhs))) }
		'shr_i64' { u64(binary_shift_right_i64(i64(lhs), i64(rhs))) }
		'shr_u64' { binary_shift_right_u64(lhs, rhs) }
		else { panic('Unknown Source shift fixture: ${name}') }
	}
}

fn test_scalar_shifts_match_verbatim_pinned_cpp_for_signed_counts_and_every_bit_position() {
	rows := os.read_lines(os.dir(@DIR) + '/webassembly/fixtures/shift_integer_operators.tsv')!
	mut count := 0
	for row in rows {
		if row.starts_with('#') || row.len == 0 { continue }
		parts := row.split('\t')
		assert parts.len == 4
		lhs := strconv.parse_uint(parts[1], 16, 64)!
		rhs := strconv.parse_uint(parts[2], 16, 64)!
		actual := source_shift_integer_case(parts[0], lhs, rhs)
		assert parts[3] == '${actual:016x}', row
		count++
	}
	assert count == 5760
}

fn source_shift_left_i32_value(lhs BinaryMachineValue, rhs BinaryMachineValue) !BinaryMachineValue {
	return BinaryMachineValue.from_i32(i32(binary_shift_left_u32(lhs.to_u32(), rhs.to_u32())))
}

fn source_shift_right_i64_value(lhs BinaryMachineValue, rhs BinaryMachineValue) !BinaryMachineValue {
	return BinaryMachineValue.from_i64(binary_shift_right_i64(lhs.to_i64(), rhs.to_i64()))
}

fn test_source_shift_pop_push_types_write_actual_slots_with_cleared_high_bits() {
	stack_info := libjs.StackInfo.new()
	mut interpreter := BinaryMachineBytecodeInterpreter.create(&stack_info)
	mut store := BinaryMachineStore.create()
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer { configuration.destroy() }
	addresses := BinarySourcesAndDestination{
		operands: BinarySourcesAndDestinationFields{
			sources:     [BinaryRegisterOrStack.r2, .r3, .r6]!
			destination: .r7
		}
	}
	configuration.regs[2] = BinaryMachineValue.from_i32(-1)
	configuration.regs[3] = BinaryMachineValue{ low: 1, high: 773 }
	configuration.regs[7] = BinaryMachineValue.from_i64(791)
	assert !interpreter.binary_numeric_operation(mut configuration, &addresses, .all_registers, source_shift_left_i32_value)
	assert configuration.regs[3] == BinaryMachineValue.from_i32(i32(-2147483648))
	assert configuration.regs[2] == BinaryMachineValue.from_i32(-1)
	configuration.regs[2] = BinaryMachineValue.from_i64(-1)
	configuration.regs[3] = BinaryMachineValue{ low: u64(i64(-7)), high: 773 }
	assert !interpreter.binary_numeric_operation(mut configuration, &addresses, .all_registers, source_shift_right_i64_value)
	assert configuration.regs[3] == BinaryMachineValue.from_i64(-1)
	assert configuration.regs[7].to_i64() == 791
	assert configuration.value_stack_.is_empty()
	assert !interpreter.did_trap()
}
