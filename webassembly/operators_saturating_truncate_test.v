module webassembly

import libjs
import math
import os
import strconv

#include <fenv.h>

fn C.fegetround() int
fn C.fesetround(int) int

fn source_saturating_truncate_rounding(mode string) int {
	return match mode {
		'nearest' { int(C.FE_TONEAREST) }
		'down' { int(C.FE_DOWNWARD) }
		'up' { int(C.FE_UPWARD) }
		'zero' { int(C.FE_TOWARDZERO) }
		else { panic('Unknown Source rounding mode: ${mode}') }
	}
}

fn source_saturating_truncate_case(name string, bits u64) u64 {
	match name {
		'saturating_f32_i32' {
			return u64(binary_saturating_truncate_f32_to_i32(math.f32_from_bits(u32(bits))))
		}
		'saturating_f32_u32' {
			return u64(binary_saturating_truncate_f32_to_u32(math.f32_from_bits(u32(bits))))
		}
		'saturating_f32_i64' {
			return u64(binary_saturating_truncate_f32_to_i64(math.f32_from_bits(u32(bits))))
		}
		'saturating_f32_u64' {
			return u64(binary_saturating_truncate_f32_to_u64(math.f32_from_bits(u32(bits))))
		}
		'saturating_f64_i32' {
			return u64(binary_saturating_truncate_f64_to_i32(math.f64_from_bits(bits)))
		}
		'saturating_f64_u32' {
			return u64(binary_saturating_truncate_f64_to_u32(math.f64_from_bits(bits)))
		}
		'saturating_f64_i64' {
			return u64(binary_saturating_truncate_f64_to_i64(math.f64_from_bits(bits)))
		}
		'saturating_f64_u64' {
			return u64(binary_saturating_truncate_f64_to_u64(math.f64_from_bits(bits)))
		}
		else { panic('Unknown Source saturating truncation fixture: ${name}') }
	}
}

fn test_saturating_truncate_operators_match_exact_source_in_all_native_rounding_modes() {
	previous := C.fegetround()
	defer { C.fesetround(previous) }
	rows := os.read_lines(os.dir(@DIR) + '/webassembly/fixtures/saturating_truncate_operators.tsv')!
	mut count := 0
	for row in rows {
		if row.starts_with('#') || row.len == 0 { continue }
		parts := row.split('\t')
		assert parts.len == 3
		names := parts[0].split('/')
		assert names.len == 2
		changed := C.fesetround(source_saturating_truncate_rounding(names[0]))
		assert changed == 0
		bits := strconv.parse_uint(parts[1], 16, 64)!
		actual := source_saturating_truncate_case(names[1], bits)
		assert '${actual:016x}' == parts[2], row
		count++
	}
	assert count == 1312
}

fn source_saturating_truncate_f64_u64_value(value BinaryMachineValue) !BinaryMachineValue {
	return BinaryMachineValue.from_u64(binary_saturating_truncate_f64_to_u64(value.to_f64()))
}

fn test_source_saturating_truncate_helper_writes_zero_or_full_unsigned_limit_without_a_new_trap() {
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
	configuration.regs[2] = BinaryMachineValue{ low: 0xfff0000000004321, high: 991 }
	configuration.regs[3] = BinaryMachineValue{ low: 0xfff0000000000000, high: 992 }
	configuration.regs[4] = BinaryMachineValue{ low: 0x7ff0000000000000, high: 993 }
	configuration.regs[7] = BinaryMachineValue.from_i64(719)
	interpreter.set_trap_message('Retained earlier trap')
	for index in 0 .. 3 {
		assert !interpreter.unary_operation(configuration, &addresses, .all_registers, index, source_saturating_truncate_f64_u64_value)
	}
	assert configuration.regs[2] == BinaryMachineValue{ low: 0 }
	assert configuration.regs[3] == BinaryMachineValue{ low: 0 }
	assert configuration.regs[4] == BinaryMachineValue{ low: 0xffffffffffffffff }
	assert configuration.regs[7].to_i64() == 719
	assert configuration.value_stack_.is_empty()
	assert interpreter.trap().format() == 'Retained earlier trap'
}
