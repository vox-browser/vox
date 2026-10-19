module webassembly

import libjs
import math
import os
import strconv

fn source_checked_truncate_case(name string, bits u64) string {
	match name {
		'truncate_f32_i32' {
			value := binary_checked_truncate_f32_to_i32(math.f32_from_bits(u32(bits))) or {
				reason := err.msg()
				return 'error:${reason}'
			}
			return '${u64(value):016x}'
		}
		'truncate_f32_u32' {
			value := binary_checked_truncate_f32_to_u32(math.f32_from_bits(u32(bits))) or {
				reason := err.msg()
				return 'error:${reason}'
			}
			return '${u64(value):016x}'
		}
		'truncate_f32_i64' {
			value := binary_checked_truncate_f32_to_i64(math.f32_from_bits(u32(bits))) or {
				reason := err.msg()
				return 'error:${reason}'
			}
			return '${u64(value):016x}'
		}
		'truncate_f32_u64' {
			value := binary_checked_truncate_f32_to_u64(math.f32_from_bits(u32(bits))) or {
				reason := err.msg()
				return 'error:${reason}'
			}
			return '${u64(value):016x}'
		}
		'truncate_f64_i32' {
			value := binary_checked_truncate_f64_to_i32(math.f64_from_bits(bits)) or {
				reason := err.msg()
				return 'error:${reason}'
			}
			return '${u64(value):016x}'
		}
		'truncate_f64_u32' {
			value := binary_checked_truncate_f64_to_u32(math.f64_from_bits(bits)) or {
				reason := err.msg()
				return 'error:${reason}'
			}
			return '${u64(value):016x}'
		}
		'truncate_f64_i64' {
			value := binary_checked_truncate_f64_to_i64(math.f64_from_bits(bits)) or {
				reason := err.msg()
				return 'error:${reason}'
			}
			return '${u64(value):016x}'
		}
		'truncate_f64_u64' {
			value := binary_checked_truncate_f64_to_u64(math.f64_from_bits(bits)) or {
				reason := err.msg()
				return 'error:${reason}'
			}
			return '${u64(value):016x}'
		}
		else { panic('Unknown Source checked truncation fixture: ${name}') }
	}
}

fn test_checked_truncate_operators_match_exact_source_results_and_error_gates() {
	rows := os.read_lines(os.dir(@DIR) + '/webassembly/fixtures/checked_truncate_operators.tsv')!
	mut count := 0
	for row in rows {
		if row.starts_with('#') || row.len == 0 { continue }
		parts := row.split('\t')
		assert parts.len == 3
		bits := strconv.parse_uint(parts[1], 16, 64)!
		assert source_checked_truncate_case(parts[0], bits) == parts[2], row
		count++
	}
	assert count == 328
}

fn source_checked_truncate_f64_i32_value(value BinaryMachineValue) !BinaryMachineValue {
	result := binary_checked_truncate_f64_to_i32(value.to_f64())!
	return BinaryMachineValue.from_i32(result)
}

fn test_source_checked_truncate_helper_replaces_trap_on_error_without_operand_write() {
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
	configuration.regs[2] = BinaryMachineValue{ low: 0x7ff0000000004321, high: 991 }
	configuration.regs[3] = BinaryMachineValue{ low: 0x41e0000000000000, high: 992 }
	configuration.regs[4] = BinaryMachineValue{ low: 0xbffe666666666666, high: 993 }
	configuration.regs[7] = BinaryMachineValue.from_i64(719)
	assert interpreter.unary_operation(configuration, &addresses, .all_registers, 0, source_checked_truncate_f64_i32_value)
	assert configuration.regs[2] == BinaryMachineValue{ low: 0x7ff0000000004321, high: 991 }
	assert interpreter.trap().format() == 'Truncation undefined behavior'
	assert interpreter.unary_operation(configuration, &addresses, .all_registers, 1, source_checked_truncate_f64_i32_value)
	assert configuration.regs[3] == BinaryMachineValue{ low: 0x41e0000000000000, high: 992 }
	assert interpreter.trap().format() == 'Truncation out of range'
	assert !interpreter.unary_operation(configuration, &addresses, .all_registers, 2, source_checked_truncate_f64_i32_value)
	assert configuration.regs[4] == BinaryMachineValue{ low: 0xffffffffffffffff }
	assert configuration.regs[7].to_i64() == 719
	assert configuration.value_stack_.is_empty()
	assert interpreter.trap().format() == 'Truncation out of range'
}
