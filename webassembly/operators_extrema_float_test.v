module webassembly

import libjs
import math
import os
import strconv

fn source_float_extrema_case(name string, lhs u64, rhs u64) u64 {
	return match name {
		'min_f32' {
			u64(math.f32_bits(binary_minimum_f32(math.f32_from_bits(u32(lhs)), math.f32_from_bits(u32(rhs)))))
		}
		'min_f64' {
			math.f64_bits(binary_minimum_f64(math.f64_from_bits(lhs), math.f64_from_bits(rhs)))
		}
		'max_f32' {
			u64(math.f32_bits(binary_maximum_f32(math.f32_from_bits(u32(lhs)), math.f32_from_bits(u32(rhs)))))
		}
		'max_f64' {
			math.f64_bits(binary_maximum_f64(math.f64_from_bits(lhs), math.f64_from_bits(rhs)))
		}
		'copysign_f32' {
			u64(math.f32_bits(binary_copy_sign_f32(math.f32_from_bits(u32(lhs)), math.f32_from_bits(u32(rhs)))))
		}
		'copysign_f64' {
			math.f64_bits(binary_copy_sign_f64(math.f64_from_bits(lhs), math.f64_from_bits(rhs)))
		}
		else { panic('Unknown Source floating extrema fixture: ${name}') }
	}
}

fn test_float_extrema_match_exact_source_nan_zero_and_sign_bit_results() {
	rows := os.read_lines(os.dir(@DIR) + '/webassembly/fixtures/extrema_float_operators.tsv')!
	mut count := 0
	for row in rows {
		if row.starts_with('#') || row.len == 0 { continue }
		parts := row.split('\t')
		assert parts.len == 4
		lhs := strconv.parse_uint(parts[1], 16, 64)!
		rhs := strconv.parse_uint(parts[2], 16, 64)!
		actual := source_float_extrema_case(parts[0], lhs, rhs)
		assert parts[3] == '${actual:016x}', row
		count++
	}
	assert count == 1536
}

fn source_float_minimum_value(lhs BinaryMachineValue, rhs BinaryMachineValue) !BinaryMachineValue {
	return BinaryMachineValue.from_f32(binary_minimum_f32(lhs.to_f32(), rhs.to_f32()))
}

fn source_double_maximum_value(lhs BinaryMachineValue, rhs BinaryMachineValue) !BinaryMachineValue {
	return BinaryMachineValue.from_f64(binary_maximum_f64(lhs.to_f64(), rhs.to_f64()))
}

fn source_double_copy_sign_value(lhs BinaryMachineValue, rhs BinaryMachineValue) !BinaryMachineValue {
	return BinaryMachineValue.from_f64(binary_copy_sign_f64(lhs.to_f64(), rhs.to_f64()))
}

fn test_source_extrema_helper_writes_canonical_nan_signed_zero_and_original_signaling_payload() {
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
	configuration.regs[2] = BinaryMachineValue.from_f32(1)
	configuration.regs[3] = BinaryMachineValue{ low: 0xff854321, high: 771 }
	configuration.regs[7] = BinaryMachineValue.from_i64(791)
	interpreter.set_trap_message('Retained earlier trap')
	assert !interpreter.binary_numeric_operation(mut configuration, &addresses, .all_registers, source_float_minimum_value)
	assert configuration.regs[3] == BinaryMachineValue{ low: 0x7fc00000 }
	configuration.regs[2] = BinaryMachineValue.from_f64(0)
	configuration.regs[3] = BinaryMachineValue{ low: 0x8000000000000000, high: 771 }
	assert !interpreter.binary_numeric_operation(mut configuration, &addresses, .all_registers, source_double_maximum_value)
	assert configuration.regs[3] == BinaryMachineValue.from_f64(0)
	configuration.regs[2] = BinaryMachineValue.from_f64(math.f64_from_bits(0x8000000000000000))
	configuration.regs[3] = BinaryMachineValue{ low: 0x7ff0123456789abc, high: 771 }
	assert !interpreter.binary_numeric_operation(mut configuration, &addresses, .all_registers, source_double_copy_sign_value)
	assert configuration.regs[3] == BinaryMachineValue{ low: 0xfff0123456789abc }
	assert configuration.regs[2] == BinaryMachineValue.from_f64(math.f64_from_bits(0x8000000000000000))
	assert configuration.regs[7].to_i64() == 791
	assert configuration.value_stack_.is_empty()
	assert interpreter.trap().format() == 'Retained earlier trap'
}
