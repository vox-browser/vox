module webassembly

import libjs
import math
import os
import strconv

#include <fenv.h>

fn C.fegetround() int
fn C.fesetround(int) int

fn source_float_width_rounding(mode string) int {
	return match mode {
		'nearest' { int(C.FE_TONEAREST) }
		'down' { int(C.FE_DOWNWARD) }
		'up' { int(C.FE_UPWARD) }
		'zero' { int(C.FE_TOWARDZERO) }
		else { panic('Unknown Source rounding mode: ${mode}') }
	}
}

fn source_float_width_case(name string, bits u64) u64 {
	match name {
		'promote_f32' {
			return math.f64_bits(binary_promote_f32_to_f64(math.f32_from_bits(u32(bits))))
		}
		'demote_f64' {
			return u64(math.f32_bits(binary_demote_f64_to_f32(math.f64_from_bits(bits))))
		}
		else { panic('Unknown Source floating width fixture: ${name}') }
	}
}

fn test_float_width_operators_match_source_nan_inf_and_native_rounding_bits() {
	previous_rounding := C.fegetround()
	defer { C.fesetround(previous_rounding) }
	rows := os.read_lines(os.dir(@DIR) + '/webassembly/fixtures/width_float_operators.tsv')!
	mut count := 0
	for row in rows {
		if row.starts_with('#') || row.len == 0 { continue }
		parts := row.split('\t')
		assert parts.len == 3
		names := parts[0].split('/')
		assert names.len == 2
		changed := C.fesetround(source_float_width_rounding(names[0]))
		assert changed == 0
		bits := strconv.parse_uint(parts[1], 16, 64)!
		actual := source_float_width_case(names[1], bits)
		assert parts[2] == '${actual:016x}', row
		count++
	}
	assert count == 272
}

fn source_float_width_promote_value(value BinaryMachineValue) !BinaryMachineValue {
	return BinaryMachineValue.from_f64(binary_promote_f32_to_f64(value.to_f32()))
}

fn source_float_width_demote_value(value BinaryMachineValue) !BinaryMachineValue {
	return BinaryMachineValue.from_f32(binary_demote_f64_to_f32(value.to_f64()))
}

fn test_source_float_width_helper_preserves_push_type_and_does_not_move_operand_or_destination() {
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
	configuration.regs[3] = BinaryMachineValue{ low: 0xfff0000000000000, high: 993 }
	configuration.regs[4] = BinaryMachineValue{ low: 0x80000000, high: 994 }
	configuration.regs[7] = BinaryMachineValue.from_i64(719)
	interpreter.set_trap_message('Retained earlier trap')
	assert !interpreter.unary_operation(configuration, &addresses, .all_registers, 0, source_float_width_promote_value)
	assert configuration.regs[2] == BinaryMachineValue{ low: 0x7ff8000000000000 }
	assert !interpreter.unary_operation(configuration, &addresses, .all_registers, 1, source_float_width_demote_value)
	assert configuration.regs[3] == BinaryMachineValue{ low: 0xffffffffff800000 }
	assert !interpreter.unary_operation(configuration, &addresses, .all_registers, 2, source_float_width_promote_value)
	assert configuration.regs[4] == BinaryMachineValue{ low: 0x8000000000000000 }
	assert configuration.regs[7].to_i64() == 719
	assert configuration.value_stack_.is_empty()
	assert interpreter.trap().format() == 'Retained earlier trap'
}
