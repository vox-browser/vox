module webassembly

import libjs
import os
import strconv

fn source_unary_integer_case(name string, bits u64) i32 {
	match name {
		'eqz_i32' { return i32(binary_equals_zero_i32(i32(bits))) }
		'eqz_i64' { return i32(binary_equals_zero_i64(i64(bits))) }
		'clz_i32' { return binary_count_leading_zeros_i32(i32(bits)) }
		'clz_i64' { return binary_count_leading_zeros_i64(i64(bits)) }
		'ctz_i32' { return binary_count_trailing_zeros_i32(i32(bits)) }
		'ctz_i64' { return binary_count_trailing_zeros_i64(i64(bits)) }
		'pop_i8' { return binary_popcount_i8(i8(bits)) }
		'pop_i16' { return binary_popcount_i16(i16(bits)) }
		'pop_i32' { return binary_popcount_i32(i32(bits)) }
		'pop_i64' { return binary_popcount_i64(i64(bits)) }
		else { panic('Unknown Source unary operator fixture: ${name}') }
	}
}

fn test_unary_integer_operators_match_pinned_native_source_corpus() {
	rows := os.read_lines(os.dir(@DIR) + '/webassembly/fixtures/unary_integer_operators.tsv')!
	mut count := 0
	for row in rows {
		if row.starts_with('#') || row.len == 0 { continue }
		parts := row.split('\t')
		assert parts.len == 3
		bits := strconv.parse_uint(parts[1], 16, 64)!
		assert source_unary_integer_case(parts[0], bits).str() == parts[2], row
		count++
	}
	assert count == 1656
}

// The operator returns i32; the actual Source i64 instruction widens it.
fn source_unary_i64_count(value BinaryMachineValue) !BinaryMachineValue {
	return BinaryMachineValue.from_i64(i64(binary_count_leading_zeros_i64(value.to_i64())))
}

// EqualsZero returns bool; both Source instruction widths push i32.
fn source_unary_i64_equals_zero(value BinaryMachineValue) !BinaryMachineValue {
	return BinaryMachineValue.from_i32(i32(binary_equals_zero_i64(value.to_i64())))
}

fn test_actual_unary_slots_preserve_source_i64_count_and_i32_predicate_result_types() {
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
	configuration.regs[2] = BinaryMachineValue{ low: 1, high: 991 }
	configuration.regs[7] = BinaryMachineValue.from_i64(719)
	assert !interpreter.unary_operation(configuration, &addresses, .all_registers, 0, source_unary_i64_count)
	assert configuration.regs[2] == BinaryMachineValue.from_i64(63)
	assert configuration.regs[7].to_i64() == 719
	configuration.regs[2] = BinaryMachineValue{ low: 0, high: 991 }
	assert !interpreter.unary_operation(configuration, &addresses, .all_registers, 0, source_unary_i64_equals_zero)
	assert configuration.regs[2] == BinaryMachineValue.from_i32(1)
	configuration.regs[2] = BinaryMachineValue.from_u64(u64(1) << 32)
	assert !interpreter.unary_operation(configuration, &addresses, .all_registers, 0, source_unary_i64_equals_zero)
	assert configuration.regs[2] == BinaryMachineValue.from_i32(0)
	assert configuration.value_stack_.is_empty()
	assert !interpreter.did_trap()
}
