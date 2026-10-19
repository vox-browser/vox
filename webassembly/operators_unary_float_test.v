module webassembly

import libjs
import math
import os
import strconv

#include <fenv.h>

fn C.fegetround() int
fn C.fesetround(int) int

fn source_float_unary_case(name string, bits u64) u64 {
	match name {
		'abs_f32' { return u64(math.f32_bits(binary_absolute_f32(math.f32_from_bits(u32(bits))))) }
		'abs_f64' { return math.f64_bits(binary_absolute_f64(math.f64_from_bits(bits))) }
		'neg_f32' { return u64(math.f32_bits(binary_negate_f32(math.f32_from_bits(u32(bits))))) }
		'neg_f64' { return math.f64_bits(binary_negate_f64(math.f64_from_bits(bits))) }
		'ceil_f32' { return u64(math.f32_bits(binary_ceil_f32(math.f32_from_bits(u32(bits))))) }
		'ceil_f64' { return math.f64_bits(binary_ceil_f64(math.f64_from_bits(bits))) }
		'floor_f32' { return u64(math.f32_bits(binary_floor_f32(math.f32_from_bits(u32(bits))))) }
		'floor_f64' { return math.f64_bits(binary_floor_f64(math.f64_from_bits(bits))) }
		'trunc_f32' {
			return u64(math.f32_bits(binary_truncate_f32(math.f32_from_bits(u32(bits)))))
		}
		'trunc_f64' { return math.f64_bits(binary_truncate_f64(math.f64_from_bits(bits))) }
		'nearest_f32' {
			return u64(math.f32_bits(binary_nearby_integral_f32(math.f32_from_bits(u32(bits)))))
		}
		'nearest_f64' { return math.f64_bits(binary_nearby_integral_f64(math.f64_from_bits(bits))) }
		'sqrt_f32' {
			return u64(math.f32_bits(binary_square_root_f32(math.f32_from_bits(u32(bits)))))
		}
		'sqrt_f64' { return math.f64_bits(binary_square_root_f64(math.f64_from_bits(bits))) }
		else { panic('Unknown Source floating unary fixture: ${name}') }
	}
}

fn source_float_unary_rounding(mode string) int {
	return match mode {
		'nearest' { int(C.FE_TONEAREST) }
		'down' { int(C.FE_DOWNWARD) }
		'up' { int(C.FE_UPWARD) }
		'zero' { int(C.FE_TOWARDZERO) }
		else { panic('Unknown Source rounding mode: ${mode}') }
	}
}

fn test_float_unary_operators_match_exact_source_bits_in_all_native_rounding_modes() {
	previous_rounding := C.fegetround()
	defer { C.fesetround(previous_rounding) }
	rows := os.read_lines(os.dir(@DIR) + '/webassembly/fixtures/unary_float_operators.tsv')!
	mut count := 0
	for row in rows {
		if row.starts_with('#') || row.len == 0 { continue }
		parts := row.split('\t')
		assert parts.len == 3
		names := parts[0].split('/')
		assert names.len == 2
		changed := C.fesetround(source_float_unary_rounding(names[0]))
		assert changed == 0
		bits := strconv.parse_uint(parts[1], 16, 64)!
		actual := source_float_unary_case(names[1], bits)
		assert parts[2] == '${actual:016x}', row
		count++
	}
	assert count == 1568
}

fn source_float_unary_ceil_value(value BinaryMachineValue) !BinaryMachineValue {
	return BinaryMachineValue.from_f32(binary_ceil_f32(value.to_f32()))
}

fn source_double_unary_negate_value(value BinaryMachineValue) !BinaryMachineValue {
	return BinaryMachineValue.from_f64(binary_negate_f64(value.to_f64()))
}

fn source_float_unary_square_root_value(value BinaryMachineValue) !BinaryMachineValue {
	return BinaryMachineValue.from_f32(binary_square_root_f32(value.to_f32()))
}

fn test_source_float_unary_helper_rewrites_selected_slot_without_losing_width_or_signaling_payload() {
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
	configuration.regs[3] = BinaryMachineValue{ low: 0x7ff0123456789abc, high: 993 }
	configuration.regs[4] = BinaryMachineValue{ low: 0x80000000, high: 994 }
	configuration.regs[7] = BinaryMachineValue.from_i64(719)
	interpreter.set_trap_message('Retained earlier trap')
	assert !interpreter.unary_operation(configuration, &addresses, .all_registers, 0, source_float_unary_ceil_value)
	assert configuration.regs[2] == BinaryMachineValue{ low: 0x7fc00000 }
	assert !interpreter.unary_operation(configuration, &addresses, .all_registers, 1, source_double_unary_negate_value)
	assert configuration.regs[3] == BinaryMachineValue{ low: 0xfff0123456789abc }
	assert !interpreter.unary_operation(configuration, &addresses, .all_registers, 2, source_float_unary_square_root_value)
	// Source Value(float) sign-extends bit_cast<i32>(raw_value) into its low u64.
	assert configuration.regs[4] == BinaryMachineValue{ low: 0xffffffff80000000 }
	assert configuration.regs[7].to_i64() == 719
	assert configuration.value_stack_.is_empty()
	assert interpreter.trap().format() == 'Retained earlier trap'
}
