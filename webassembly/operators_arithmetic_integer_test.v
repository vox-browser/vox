module webassembly

import libjs
import os
import strconv

fn source_integer_arithmetic_case(name string, lhs u64, rhs u64) u64 {
	return match name {
		'add_u32' { u64(binary_add_u32(u32(lhs), u32(rhs))) }
		'add_u64' { binary_add_u64(lhs, rhs) }
		'sub_u32' { u64(binary_subtract_u32(u32(lhs), u32(rhs))) }
		'sub_u64' { binary_subtract_u64(lhs, rhs) }
		'mul_u32' { u64(binary_multiply_u32(u32(lhs), u32(rhs))) }
		'mul_u64' { binary_multiply_u64(lhs, rhs) }
		'and_i32' { u64(i64(binary_bit_and_i32(i32(lhs), i32(rhs)))) }
		'and_i64' { u64(binary_bit_and_i64(i64(lhs), i64(rhs))) }
		'or_i32' { u64(i64(binary_bit_or_i32(i32(lhs), i32(rhs)))) }
		'or_i64' { u64(binary_bit_or_i64(i64(lhs), i64(rhs))) }
		'xor_i32' { u64(i64(binary_bit_xor_i32(i32(lhs), i32(rhs)))) }
		'xor_i64' { u64(binary_bit_xor_i64(i64(lhs), i64(rhs))) }
		else { panic('Unknown Source integer arithmetic fixture: ${name}') }
	}
}

fn test_integer_arithmetic_and_bitwise_match_exact_pinned_native_cpp_boundaries() {
	rows := os.read_lines(os.dir(@DIR) + '/webassembly/fixtures/arithmetic_integer_operators.tsv')!
	mut count := 0
	for row in rows {
		if row.starts_with('#') || row.len == 0 { continue }
		parts := row.split('\t')
		assert parts.len == 4
		lhs := strconv.parse_uint(parts[1], 16, 64)!
		rhs := strconv.parse_uint(parts[2], 16, 64)!
		actual := source_integer_arithmetic_case(parts[0], lhs, rhs)
		assert parts[3] == '${actual:016x}', row
		count++
	}
	assert count == 1728
}

fn source_add_u32_i32_value(lhs BinaryMachineValue, rhs BinaryMachineValue) !BinaryMachineValue {
	return BinaryMachineValue.from_i32(i32(binary_add_u32(lhs.to_u32(), rhs.to_u32())))
}

fn source_multiply_u64_i64_value(lhs BinaryMachineValue, rhs BinaryMachineValue) !BinaryMachineValue {
	return BinaryMachineValue.from_i64(i64(binary_multiply_u64(lhs.to_u64(), rhs.to_u64())))
}

fn source_bit_xor_i32_value(lhs BinaryMachineValue, rhs BinaryMachineValue) !BinaryMachineValue {
	return BinaryMachineValue.from_i32(binary_bit_xor_i32(lhs.to_i32(), rhs.to_i32()))
}

fn test_source_arithmetic_uses_unsigned_wrap_and_signed_machine_push_types() {
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
	configuration.regs[2] = BinaryMachineValue.from_u32(1)
	configuration.regs[3] = BinaryMachineValue{ low: 0x7fffffff, high: 771 }
	configuration.regs[7] = BinaryMachineValue.from_i64(791)
	assert !interpreter.binary_numeric_operation(mut configuration, &addresses, .all_registers, source_add_u32_i32_value)
	assert configuration.regs[3] == BinaryMachineValue.from_i32(i32(-2147483648))
	configuration.regs[2] = BinaryMachineValue.from_u64(2)
	configuration.regs[3] = BinaryMachineValue{ low: 0x8000000000000001, high: 771 }
	assert !interpreter.binary_numeric_operation(mut configuration, &addresses, .all_registers, source_multiply_u64_i64_value)
	assert configuration.regs[3] == BinaryMachineValue.from_i64(2)
	configuration.regs[2] = BinaryMachineValue.from_i32(-1)
	configuration.regs[3] = BinaryMachineValue{ low: 0x7fffffff, high: 771 }
	assert !interpreter.binary_numeric_operation(mut configuration, &addresses, .all_registers, source_bit_xor_i32_value)
	assert configuration.regs[3] == BinaryMachineValue.from_i32(i32(-2147483648))
	assert configuration.regs[2] == BinaryMachineValue.from_i32(-1)
	assert configuration.regs[7].to_i64() == 791
	assert configuration.value_stack_.is_empty()
	assert !interpreter.did_trap()
}
