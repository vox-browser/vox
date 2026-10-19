module webassembly

import libjs
import math
import os
import strconv

fn source_reinterpret_case(name string, bits u64) u64 {
	return match name {
		'reinterpret_f32_i32' { u64(binary_reinterpret_f32_to_i32(math.f32_from_bits(u32(bits)))) }
		'reinterpret_f64_i64' { u64(binary_reinterpret_f64_to_i64(math.f64_from_bits(bits))) }
		'reinterpret_i32_f32' { u64(math.f32_bits(binary_reinterpret_i32_to_f32(i32(u32(bits))))) }
		'reinterpret_i64_f64' { math.f64_bits(binary_reinterpret_i64_to_f64(i64(bits))) }
		else { panic('Unknown Source reinterpret fixture: ${name}') }
	}
}

fn test_reinterpret_operators_match_source_bitcasts_without_nan_or_signed_zero_normalization() {
	rows := os.read_lines(os.dir(@DIR) + '/webassembly/fixtures/reinterpret_operators.tsv')!
	mut count := 0
	for row in rows {
		if row.starts_with('#') || row.len == 0 { continue }
		parts := row.split('\t')
		assert parts.len == 3
		bits := strconv.parse_uint(parts[1], 16, 64)!
		actual := source_reinterpret_case(parts[0], bits)
		assert parts[2] == '${actual:016x}', row
		count++
	}
	assert count == 576
}

fn source_reinterpret_f32_i32_value(value BinaryMachineValue) !BinaryMachineValue {
	return BinaryMachineValue.from_i32(binary_reinterpret_f32_to_i32(value.to_f32()))
}

fn source_reinterpret_i32_f32_value(value BinaryMachineValue) !BinaryMachineValue {
	return BinaryMachineValue.from_f32(binary_reinterpret_i32_to_f32(value.to_i32()))
}

fn source_reinterpret_f64_i64_value(value BinaryMachineValue) !BinaryMachineValue {
	return BinaryMachineValue.from_i64(binary_reinterpret_f64_to_i64(value.to_f64()))
}

fn source_reinterpret_i64_f64_value(value BinaryMachineValue) !BinaryMachineValue {
	return BinaryMachineValue.from_f64(binary_reinterpret_i64_to_f64(value.to_i64()))
}

fn test_source_reinterpret_helpers_preserve_signaling_nan_bits_and_selected_slot_ownership() {
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
	configuration.regs[2] = BinaryMachineValue{ low: 0xff854321, high: 991 }
	configuration.regs[3] = BinaryMachineValue{ low: 0xfff0000000004321, high: 992 }
	configuration.regs[4] = BinaryMachineValue{ low: 0x8000000000000000, high: 993 }
	configuration.regs[7] = BinaryMachineValue.from_i64(719)
	interpreter.set_trap_message('Retained earlier trap')
	assert !interpreter.unary_operation(configuration, &addresses, .all_registers, 0, source_reinterpret_f32_i32_value)
	assert configuration.regs[2] == BinaryMachineValue{ low: 0xffffffffff854321 }
	assert !interpreter.unary_operation(configuration, &addresses, .all_registers, 0, source_reinterpret_i32_f32_value)
	assert configuration.regs[2] == BinaryMachineValue{ low: 0xffffffffff854321 }
	assert !interpreter.unary_operation(configuration, &addresses, .all_registers, 1, source_reinterpret_f64_i64_value)
	assert configuration.regs[3] == BinaryMachineValue{ low: 0xfff0000000004321 }
	assert !interpreter.unary_operation(configuration, &addresses, .all_registers, 2, source_reinterpret_i64_f64_value)
	assert configuration.regs[4] == BinaryMachineValue{ low: 0x8000000000000000 }
	assert configuration.regs[7].to_i64() == 719
	assert configuration.value_stack_.is_empty()
	assert interpreter.trap().format() == 'Retained earlier trap'
}
