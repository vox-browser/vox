module webassembly

import libjs
import os
import strconv

fn source_integer_comparison_case(name string, lhs u64, rhs u64) bool {
	return match name {
		'eq_i32' { binary_equals_i32(i32(lhs), i32(rhs)) }
		'eq_i64' { binary_equals_i64(i64(lhs), i64(rhs)) }
		'ne_i32' { binary_not_equals_i32(i32(lhs), i32(rhs)) }
		'ne_i64' { binary_not_equals_i64(i64(lhs), i64(rhs)) }
		'lt_i32' { binary_less_than_i32(i32(lhs), i32(rhs)) }
		'lt_u32' { binary_less_than_u32(u32(lhs), u32(rhs)) }
		'lt_i64' { binary_less_than_i64(i64(lhs), i64(rhs)) }
		'lt_u64' { binary_less_than_u64(lhs, rhs) }
		'gt_i32' { binary_greater_than_i32(i32(lhs), i32(rhs)) }
		'gt_u32' { binary_greater_than_u32(u32(lhs), u32(rhs)) }
		'gt_i64' { binary_greater_than_i64(i64(lhs), i64(rhs)) }
		'gt_u64' { binary_greater_than_u64(lhs, rhs) }
		'le_i32' { binary_less_than_or_equals_i32(i32(lhs), i32(rhs)) }
		'le_u32' { binary_less_than_or_equals_u32(u32(lhs), u32(rhs)) }
		'le_i64' { binary_less_than_or_equals_i64(i64(lhs), i64(rhs)) }
		'le_u64' { binary_less_than_or_equals_u64(lhs, rhs) }
		'ge_i32' { binary_greater_than_or_equals_i32(i32(lhs), i32(rhs)) }
		'ge_u32' { binary_greater_than_or_equals_u32(u32(lhs), u32(rhs)) }
		'ge_i64' { binary_greater_than_or_equals_i64(i64(lhs), i64(rhs)) }
		'ge_u64' { binary_greater_than_or_equals_u64(lhs, rhs) }
		else { panic('Unknown Source integer comparison fixture: ${name}') }
	}
}

fn test_integer_comparisons_match_pinned_cpp_signed_and_unsigned_boundary_corpus() {
	rows := os.read_lines(os.dir(@DIR) + '/webassembly/fixtures/comparison_integer_operators.tsv')!
	mut count := 0
	for row in rows {
		if row.starts_with('#') || row.len == 0 { continue }
		parts := row.split('\t')
		assert parts.len == 4
		lhs := strconv.parse_uint(parts[1], 16, 64)!
		rhs := strconv.parse_uint(parts[2], 16, 64)!
		actual := source_integer_comparison_case(parts[0], lhs, rhs)
		expected := if actual { '0000000000000001' } else { '0000000000000000' }
		assert parts[3] == expected, row
		count++
	}
	assert count == 2880
}

fn source_less_than_u64_value(lhs BinaryMachineValue, rhs BinaryMachineValue) !BinaryMachineValue {
	if binary_less_than_u64(lhs.to_u64(), rhs.to_u64()) { return BinaryMachineValue.from_i32(1) }
	return BinaryMachineValue.from_i32(0)
}

fn source_less_than_i64_value(lhs BinaryMachineValue, rhs BinaryMachineValue) !BinaryMachineValue {
	if binary_less_than_i64(lhs.to_i64(), rhs.to_i64()) { return BinaryMachineValue.from_i32(1) }
	return BinaryMachineValue.from_i32(0)
}

fn test_source_i64_comparisons_keep_operand_signedness_and_i32_result_slot() {
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
	configuration.regs[2] = BinaryMachineValue.from_i64(7)
	configuration.regs[3] = BinaryMachineValue{ low: 0x8000000000000000, high: 771 }
	configuration.regs[7] = BinaryMachineValue.from_i64(791)
	interpreter.set_trap_message('Retained earlier trap')
	assert !interpreter.binary_numeric_operation(mut configuration, &addresses, .all_registers, source_less_than_u64_value)
	assert configuration.regs[3] == BinaryMachineValue.from_i32(0)
	configuration.regs[3] = BinaryMachineValue{ low: 0x8000000000000000, high: 771 }
	assert !interpreter.binary_numeric_operation(mut configuration, &addresses, .all_registers, source_less_than_i64_value)
	assert configuration.regs[3] == BinaryMachineValue.from_i32(1)
	assert configuration.regs[2] == BinaryMachineValue.from_i64(7)
	assert configuration.regs[7].to_i64() == 791
	assert configuration.value_stack_.is_empty()
	assert interpreter.trap().format() == 'Retained earlier trap'
}
