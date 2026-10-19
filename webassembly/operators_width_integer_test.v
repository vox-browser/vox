module webassembly

import libjs
import os
import strconv

fn source_integer_width_case(name string, bits u64) u64 {
	return match name {
		'wrap_i64_i32' { u64(binary_wrap_i64_to_i32(i64(bits))) }
		'extend_i32_i64' { u64(binary_extend_i32_to_i64(i32(u32(bits)))) }
		'extend_u32_i64' { u64(binary_extend_u32_to_i64(u32(bits))) }
		'sign_i8_i32' { u64(binary_sign_extend_i8_to_i32(i32(u32(bits)))) }
		'sign_i16_i32' { u64(binary_sign_extend_i16_to_i32(i32(u32(bits)))) }
		'sign_i8_i64' { u64(binary_sign_extend_i8_to_i64(i64(bits))) }
		'sign_i16_i64' { u64(binary_sign_extend_i16_to_i64(i64(bits))) }
		'sign_i32_i64' { u64(binary_sign_extend_i32_to_i64(i64(bits))) }
		else { panic('Unknown Source integer width fixture: ${name}') }
	}
}

fn test_integer_width_operators_match_source_wrapping_signed_and_unsigned_bit_patterns() {
	rows := os.read_lines(os.dir(@DIR) + '/webassembly/fixtures/width_integer_operators.tsv')!
	mut count := 0
	for row in rows {
		if row.starts_with('#') || row.len == 0 { continue }
		parts := row.split('\t')
		assert parts.len == 3
		bits := strconv.parse_uint(parts[1], 16, 64)!
		actual := source_integer_width_case(parts[0], bits)
		assert parts[2] == '${actual:016x}', row
		count++
	}
	assert count == 3216
}

fn source_integer_width_wrap_value(value BinaryMachineValue) !BinaryMachineValue {
	return BinaryMachineValue.from_i32(binary_wrap_i64_to_i32(value.to_i64()))
}

fn source_integer_width_extend_unsigned_value(value BinaryMachineValue) !BinaryMachineValue {
	return BinaryMachineValue.from_i64(binary_extend_u32_to_i64(value.to_u32()))
}

fn source_integer_width_sign_extend_value(value BinaryMachineValue) !BinaryMachineValue {
	return BinaryMachineValue.from_i64(binary_sign_extend_i16_to_i64(value.to_i64()))
}

fn test_source_integer_width_helpers_preserve_slot_and_result_width_without_destination_or_trap_changes() {
	stack_info := libjs.StackInfo.new()
	mut interpreter := BinaryMachineBytecodeInterpreter.create(&stack_info)
	mut store := BinaryMachineStore.create()
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer { configuration.destroy() }
	addresses := BinarySourcesAndDestination{
		operands: BinarySourcesAndDestinationFields{
			sources:     [BinaryRegisterOrStack.r2, .r3, .r4]!
			destination: .r7
		}
	}
	configuration.regs[2] = BinaryMachineValue{ low: 0x1234567880000000, high: 991 }
	configuration.regs[3] = BinaryMachineValue{ low: 0xffffffff80000000, high: 992 }
	configuration.regs[4] = BinaryMachineValue{ low: 0xa5a5deadbeef8001, high: 993 }
	configuration.regs[7] = BinaryMachineValue.from_i64(719)
	interpreter.set_trap_message('Retained earlier trap')
	assert !interpreter.unary_operation(configuration, &addresses, .all_registers, 0, source_integer_width_wrap_value)
	assert configuration.regs[2] == BinaryMachineValue{ low: 0xffffffff80000000 }
	assert !interpreter.unary_operation(configuration, &addresses, .all_registers, 1, source_integer_width_extend_unsigned_value)
	assert configuration.regs[3] == BinaryMachineValue{ low: 0x80000000 }
	assert !interpreter.unary_operation(configuration, &addresses, .all_registers, 2, source_integer_width_sign_extend_value)
	assert configuration.regs[4] == BinaryMachineValue{ low: 0xffffffffffff8001 }
	assert configuration.regs[7].to_i64() == 719
	assert configuration.value_stack_.is_empty()
	assert interpreter.trap().format() == 'Retained earlier trap'
}
