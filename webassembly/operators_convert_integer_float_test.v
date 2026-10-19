module webassembly

import libjs
import math
import os
import strconv

#include <fenv.h>

fn C.fegetround() int
fn C.fesetround(int) int

fn source_integer_float_rounding(mode string) int {
	return match mode {
		'nearest' { int(C.FE_TONEAREST) }
		'down' { int(C.FE_DOWNWARD) }
		'up' { int(C.FE_UPWARD) }
		'zero' { int(C.FE_TOWARDZERO) }
		else { panic('Unknown Source rounding mode: ${mode}') }
	}
}

fn source_integer_float_case(name string, bits u64) u64 {
	return match name {
		'convert_i32_f32' { u64(math.f32_bits(binary_convert_i32_to_f32(i32(u32(bits))))) }
		'convert_u32_f32' { u64(math.f32_bits(binary_convert_u32_to_f32(u32(bits)))) }
		'convert_i64_f32' { u64(math.f32_bits(binary_convert_i64_to_f32(i64(bits)))) }
		'convert_u64_f32' { u64(math.f32_bits(binary_convert_u64_to_f32(bits))) }
		'convert_i32_f64' { math.f64_bits(binary_convert_i32_to_f64(i32(u32(bits)))) }
		'convert_u32_f64' { math.f64_bits(binary_convert_u32_to_f64(u32(bits))) }
		'convert_i64_f64' { math.f64_bits(binary_convert_i64_to_f64(i64(bits))) }
		'convert_u64_f64' { math.f64_bits(binary_convert_u64_to_f64(bits)) }
		else { panic('Unknown Source integer-to-floating fixture: ${name}') }
	}
}

fn test_integer_to_floating_operators_match_source_native_cast_bits_in_all_rounding_modes() {
	previous := C.fegetround()
	defer { C.fesetround(previous) }
	rows := os.read_lines(os.dir(@DIR) + '/webassembly/fixtures/convert_integer_float_operators.tsv')!
	mut count := 0
	for row in rows {
		if row.starts_with('#') || row.len == 0 { continue }
		parts := row.split('\t')
		assert parts.len == 3
		names := parts[0].split('/')
		assert names.len == 2
		changed := C.fesetround(source_integer_float_rounding(names[0]))
		assert changed == 0
		bits := strconv.parse_uint(parts[1], 16, 64)!
		actual := source_integer_float_case(names[1], bits)
		assert parts[2] == '${actual:016x}', row
		count++
	}
	assert count == 8512
}

fn source_integer_float_u64_f32_value(value BinaryMachineValue) !BinaryMachineValue {
	return BinaryMachineValue.from_f32(binary_convert_u64_to_f32(value.to_u64()))
}

fn source_integer_float_i32_f64_value(value BinaryMachineValue) !BinaryMachineValue {
	return BinaryMachineValue.from_f64(binary_convert_i32_to_f64(value.to_i32()))
}

fn test_source_integer_float_helpers_keep_original_interpretation_and_clear_high_half() {
	previous := C.fegetround()
	defer { C.fesetround(previous) }
	changed := C.fesetround(int(C.FE_TONEAREST))
	assert changed == 0
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
	configuration.regs[2] = BinaryMachineValue{ low: 0xffffffffffffffff, high: 991 }
	configuration.regs[3] = BinaryMachineValue{ low: 0xffffffff80000000, high: 992 }
	configuration.regs[4] = BinaryMachineValue{ low: 991, high: 993 }
	configuration.regs[7] = BinaryMachineValue.from_i64(719)
	interpreter.set_trap_message('Retained earlier trap')
	assert !interpreter.unary_operation(configuration, &addresses, .all_registers, 0, source_integer_float_u64_f32_value)
	assert configuration.regs[2] == BinaryMachineValue{ low: 0x5f800000 }
	assert !interpreter.unary_operation(configuration, &addresses, .all_registers, 1, source_integer_float_i32_f64_value)
	assert configuration.regs[3] == BinaryMachineValue{ low: 0xc1e0000000000000 }
	assert configuration.regs[4] == BinaryMachineValue{ low: 991, high: 993 }
	assert configuration.regs[7].to_i64() == 719
	assert configuration.value_stack_.is_empty()
	assert interpreter.trap().format() == 'Retained earlier trap'
}
