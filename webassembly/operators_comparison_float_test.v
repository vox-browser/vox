module webassembly

import libjs
import math
import os
import strconv

fn source_float_comparison_case(name string, lhs u64, rhs u64) bool {
	return match name {
		'eq_f32' { binary_equals_f32(math.f32_from_bits(u32(lhs)), math.f32_from_bits(u32(rhs))) }
		'eq_f64' { binary_equals_f64(math.f64_from_bits(lhs), math.f64_from_bits(rhs)) }
		'ne_f32' {
			binary_not_equals_f32(math.f32_from_bits(u32(lhs)), math.f32_from_bits(u32(rhs)))
		}
		'ne_f64' { binary_not_equals_f64(math.f64_from_bits(lhs), math.f64_from_bits(rhs)) }
		'lt_f32' {
			binary_less_than_f32(math.f32_from_bits(u32(lhs)), math.f32_from_bits(u32(rhs)))
		}
		'lt_f64' { binary_less_than_f64(math.f64_from_bits(lhs), math.f64_from_bits(rhs)) }
		'gt_f32' {
			binary_greater_than_f32(math.f32_from_bits(u32(lhs)), math.f32_from_bits(u32(rhs)))
		}
		'gt_f64' { binary_greater_than_f64(math.f64_from_bits(lhs), math.f64_from_bits(rhs)) }
		'le_f32' {
			binary_less_than_or_equals_f32(math.f32_from_bits(u32(lhs)), math.f32_from_bits(u32(rhs)))
		}
		'le_f64' {
			binary_less_than_or_equals_f64(math.f64_from_bits(lhs), math.f64_from_bits(rhs))
		}
		'ge_f32' {
			binary_greater_than_or_equals_f32(math.f32_from_bits(u32(lhs)), math.f32_from_bits(u32(rhs)))
		}
		'ge_f64' {
			binary_greater_than_or_equals_f64(math.f64_from_bits(lhs), math.f64_from_bits(rhs))
		}
		else { panic('Unknown Source floating comparison fixture: ${name}') }
	}
}

fn test_floating_comparisons_match_exact_source_nan_zero_and_subnormal_corpus() {
	rows := os.read_lines(os.dir(@DIR) + '/webassembly/fixtures/comparison_float_operators.tsv')!
	mut count := 0
	for row in rows {
		if row.starts_with('#') || row.len == 0 { continue }
		parts := row.split('\t')
		assert parts.len == 4
		lhs := strconv.parse_uint(parts[1], 16, 64)!
		rhs := strconv.parse_uint(parts[2], 16, 64)!
		actual := source_float_comparison_case(parts[0], lhs, rhs)
		expected := if actual { '0000000000000001' } else { '0000000000000000' }
		assert parts[3] == expected, row
		count++
	}
	assert count == 3072
}

fn source_float_not_equals_i32_value(lhs BinaryMachineValue, rhs BinaryMachineValue) !BinaryMachineValue {
	if binary_not_equals_f32(lhs.to_f32(), rhs.to_f32()) { return BinaryMachineValue.from_i32(1) }
	return BinaryMachineValue.from_i32(0)
}

fn source_double_equals_i32_value(lhs BinaryMachineValue, rhs BinaryMachineValue) !BinaryMachineValue {
	if binary_equals_f64(lhs.to_f64(), rhs.to_f64()) { return BinaryMachineValue.from_i32(1) }
	return BinaryMachineValue.from_i32(0)
}

fn test_source_floating_predicates_write_i32_for_nan_and_signed_zero_with_actual_helper() {
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
	configuration.regs[3] = BinaryMachineValue{ low: 0x7f812345, high: 771 }
	configuration.regs[7] = BinaryMachineValue.from_i64(791)
	interpreter.set_trap_message('Retained earlier trap')
	assert !interpreter.binary_numeric_operation(mut configuration, &addresses, .all_registers, source_float_not_equals_i32_value)
	assert configuration.regs[3] == BinaryMachineValue.from_i32(1)
	configuration.regs[2] = BinaryMachineValue.from_f64(0)
	configuration.regs[3] = BinaryMachineValue{ low: 0x8000000000000000, high: 771 }
	assert !interpreter.binary_numeric_operation(mut configuration, &addresses, .all_registers, source_double_equals_i32_value)
	assert configuration.regs[3] == BinaryMachineValue.from_i32(1)
	assert configuration.regs[2] == BinaryMachineValue.from_f64(0)
	assert configuration.regs[7].to_i64() == 791
	assert configuration.value_stack_.is_empty()
	assert interpreter.trap().format() == 'Retained earlier trap'
}
