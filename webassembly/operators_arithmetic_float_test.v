module webassembly

import libjs
import math
import os
import strconv

fn source_float_arithmetic_case(name string, lhs u64, rhs u64) u64 {
	return match name {
		'add_f32' {
			u64(math.f32_bits(binary_add_f32(math.f32_from_bits(u32(lhs)), math.f32_from_bits(u32(rhs)))))
		}
		'add_f64' {
			math.f64_bits(binary_add_f64(math.f64_from_bits(lhs), math.f64_from_bits(rhs)))
		}
		'sub_f32' {
			u64(math.f32_bits(binary_subtract_f32(math.f32_from_bits(u32(lhs)), math.f32_from_bits(u32(rhs)))))
		}
		'sub_f64' {
			math.f64_bits(binary_subtract_f64(math.f64_from_bits(lhs), math.f64_from_bits(rhs)))
		}
		'mul_f32' {
			u64(math.f32_bits(binary_multiply_f32(math.f32_from_bits(u32(lhs)), math.f32_from_bits(u32(rhs)))))
		}
		'mul_f64' {
			math.f64_bits(binary_multiply_f64(math.f64_from_bits(lhs), math.f64_from_bits(rhs)))
		}
		'div_f32' {
			u64(math.f32_bits(binary_divide_f32(math.f32_from_bits(u32(lhs)), math.f32_from_bits(u32(rhs)))))
		}
		'div_f64' {
			math.f64_bits(binary_divide_f64(math.f64_from_bits(lhs), math.f64_from_bits(rhs)))
		}
		else { panic('Unknown Source floating arithmetic fixture: ${name}') }
	}
}

fn test_float_arithmetic_preserves_exact_source_results_and_nan_bits() {
	rows := os.read_lines(os.dir(@DIR) + '/webassembly/fixtures/arithmetic_float_operators.tsv')!
	mut count := 0
	for row in rows {
		if row.starts_with('#') || row.len == 0 { continue }
		parts := row.split('\t')
		assert parts.len == 4
		lhs := strconv.parse_uint(parts[1], 16, 64)!
		rhs := strconv.parse_uint(parts[2], 16, 64)!
		actual := source_float_arithmetic_case(parts[0], lhs, rhs)
		assert parts[3] == '${actual:016x}', row
		count++
	}
	assert count == 2048
}

fn source_float_divide_value(lhs BinaryMachineValue, rhs BinaryMachineValue) !BinaryMachineValue {
	return BinaryMachineValue.from_f32(binary_divide_f32(lhs.to_f32(), rhs.to_f32()))
}

fn source_double_add_value(lhs BinaryMachineValue, rhs BinaryMachineValue) !BinaryMachineValue {
	return BinaryMachineValue.from_f64(binary_add_f64(lhs.to_f64(), rhs.to_f64()))
}

fn test_float_arithmetic_writes_float_values_without_integer_zero_divisor_traps() {
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
	// Source borrows LHS from source[1] after popping RHS from source[0].
	configuration.regs[2] = BinaryMachineValue.from_f32(0)
	configuration.regs[3] = BinaryMachineValue{ low: 0x3f800000, high: 771 }
	configuration.regs[7] = BinaryMachineValue.from_i64(791)
	interpreter.set_trap_message('Retained earlier trap')
	assert !interpreter.binary_numeric_operation(mut configuration, &addresses, .all_registers, source_float_divide_value)
	assert configuration.regs[3] == BinaryMachineValue.from_f32(math.f32_from_bits(0x7f800000))
	configuration.regs[2] = BinaryMachineValue.from_f32(math.f32_from_bits(0x80000000))
	configuration.regs[3] = BinaryMachineValue.from_f32(1)
	assert !interpreter.binary_numeric_operation(mut configuration, &addresses, .all_registers, source_float_divide_value)
	assert configuration.regs[3] == BinaryMachineValue.from_f32(math.f32_from_bits(0xff800000))
	configuration.regs[2] = BinaryMachineValue.from_f64(0.5)
	configuration.regs[3] = BinaryMachineValue{ low: math.f64_bits(1.0), high: 771 }
	assert !interpreter.binary_numeric_operation(mut configuration, &addresses, .all_registers, source_double_add_value)
	assert configuration.regs[3] == BinaryMachineValue.from_f64(1.5)
	assert configuration.regs[2] == BinaryMachineValue.from_f64(0.5)
	assert configuration.regs[7].to_i64() == 791
	assert configuration.value_stack_.is_empty()
	assert interpreter.trap().format() == 'Retained earlier trap'
}
