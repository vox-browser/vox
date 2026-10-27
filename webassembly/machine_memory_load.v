// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// BytecodeInterpreter.cpp:6480–6502,6864–6886: load_and_push/read_value.
module webassembly

import encoding.binary
import math

// Source LittleEndian reads use the standard endian primitive here. Its V
// byte view also accepts unaligned pointers, replacing Source's aligned local
// memcpy branch without changing the bytes or floating-point bit casts.
fn binary_machine_read_value[T](data BinaryMachineBytes) T {
	if data.size < uint(sizeof(T)) {
		panic('Source VERIFY: read_value requires sizeof(T) <= data.size()')
	}
	bytes := unsafe { data.data.vbytes(int(sizeof(T))) }
	$if T is i8 {
		return i8(bytes[0])
	} $else $if T is u8 {
		return bytes[0]
	} $else $if T is i16 {
		return i16(binary.little_endian_u16(bytes))
	} $else $if T is u16 {
		return binary.little_endian_u16(bytes)
	} $else $if T is i32 {
		return i32(binary.little_endian_u32(bytes))
	} $else $if T is u32 {
		return binary.little_endian_u32(bytes)
	} $else $if T is i64 {
		return i64(binary.little_endian_u64(bytes))
	} $else $if T is u64 {
		return binary.little_endian_u64(bytes)
	} $else $if T is f32 {
		return math.f32_from_bits(binary.little_endian_u32(bytes))
	} $else $if T is f64 {
		return math.f64_from_bits(binary.little_endian_u64(bytes))
	} $else $if T is BinaryMachineValue {
		// The actual machine record is the translated Source u128 pair.
		return BinaryMachineValue{
			low:  binary.little_endian_u64(bytes[..8])
			high: binary.little_endian_u64(bytes[8..])
		}
	} $else {
		$compile_error('Source read_value supports only the translated numeric memory types')
	}
}

pub fn (mut interpreter BinaryMachineBytecodeInterpreter) load_and_push[R, P](mut configuration BinaryMachineConfiguration, instruction &BinaryInstruction, addresses &BinarySourcesAndDestination, mix BinarySourceAddressMix) bool {
	if instruction.arguments !is BinaryMemoryArgument {
		panic('Source unsafe_get: load_and_push requires MemoryArgument')
	}
	arg := instruction.arguments as BinaryMemoryArgument
	address := configuration.frame().module().memories()[int(arg.memory_index)]
	memory := configuration.store().unsafe_get_memory(address)
	sources := unsafe { &addresses.operands.sources[0] }
	mut entry := configuration.source_value(mix, 0, sources)
	base := binary_machine_memory_base_address(memory, *entry)
	// Source Checked<u64> adds the offset and then sizeof(R).
	if arg.offset > u64(-1) - base || u64(sizeof(R)) > u64(-1) - (base + arg.offset)
		|| base + arg.offset + u64(sizeof(R)) > u64(memory.size()) {
		interpreter.trap_ = BinaryMachineTrap.from_string('Memory access out of bounds')
		return true
	}
	instance_address := base + arg.offset
	value := binary_machine_read_value[R](BinaryMachineBytes{
		data: memory.data().offset_pointer(uint(instance_address))
		size: uint(sizeof(R))
	})
	// Source overwrites the borrowed address operand itself. Its destination
	// mapping is intentionally not read, and a stack operand is not popped.
	$if P is i32 {
		unsafe { *entry = BinaryMachineValue.from_i32(i32(value)) }
	} $else $if P is i64 {
		unsafe { *entry = BinaryMachineValue.from_i64(i64(value)) }
	} $else $if P is f32 {
		unsafe { *entry = BinaryMachineValue.from_f32(f32(value)) }
	} $else $if P is f64 {
		unsafe { *entry = BinaryMachineValue.from_f64(f64(value)) }
	} $else $if P is BinaryMachineValue {
		unsafe { *entry = value }
	} $else {
		$compile_error('Source load_and_push requires a translated machine result type')
	}
	return false
}
