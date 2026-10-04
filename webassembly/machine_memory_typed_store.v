// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// BytecodeInterpreter.cpp:330–348,6798–6814: ConvertToRaw/pop_and_store/store_value.
module webassembly

import encoding.binary
import math

// Source's LittleEndian temporaries use the existing standard endian primitive
// at the V byte-view boundary. Float specializations preserve raw IEEE bits.
fn binary_machine_store_bytes[T](value T) []u8 {
	$if T is i8 {
		return [u8(value)]
	} $else $if T is i16 {
		return binary.little_endian_get_u16(u16(value))
	} $else $if T is i32 {
		return binary.little_endian_get_u32(u32(value))
	} $else $if T is i64 {
		return binary.little_endian_get_u64(u64(value))
	} $else $if T is f32 {
		return binary.little_endian_get_u32(math.f32_bits(value))
	} $else $if T is f64 {
		return binary.little_endian_get_u64(math.f64_bits(value))
	} $else $if T is BinaryMachineValue {
		mut bytes := binary.little_endian_get_u64(value.low)
		bytes << binary.little_endian_get_u64(value.high)
		return bytes
	} $else {
		$compile_error('Source typed stores require a translated numeric memory type')
	}
}

// Lower the Source StoreT temporary to its original bytes and width. It remains
// live through this immediate call; the memory helper copies those bytes.
pub fn (mut interpreter BinaryMachineBytecodeInterpreter) store_value(mut configuration BinaryMachineConfiguration, instruction &BinaryInstruction, value BinaryMachineBytes, address_source u8, addresses &BinarySourcesAndDestination) bool {
	if instruction.arguments !is BinaryMemoryArgument {
		panic('Source unsafe_get: store_value requires MemoryArgument')
	}
	arg := instruction.arguments as BinaryMemoryArgument
	sources := unsafe { &addresses.operands.sources[0] }
	base := configuration.take_source(.any, address_source, sources)
	return interpreter.store_to_memory(mut configuration, arg, value, base)
}

pub fn (mut interpreter BinaryMachineBytecodeInterpreter) pop_and_store[P, S](mut configuration BinaryMachineConfiguration, instruction &BinaryInstruction, addresses &BinarySourcesAndDestination) bool {
	sources := unsafe { &addresses.operands.sources[0] }
	entry := configuration.take_source(.any, 0, sources)
	mut bytes := []u8{}
	// Source extracts PopT first, then narrows to the ConvertToRaw StoreT
	// argument. Its store_value call consumes address operand1 afterward.
	$if P is i32 {
		bytes = binary_machine_store_bytes[S](S(entry.to_i32()))
	} $else $if P is i64 {
		bytes = binary_machine_store_bytes[S](S(entry.to_i64()))
	} $else $if P is f32 {
		bytes = binary_machine_store_bytes[S](S(entry.to_f32()))
	} $else $if P is f64 {
		bytes = binary_machine_store_bytes[S](S(entry.to_f64()))
	} $else $if P is BinaryMachineValue {
		bytes = binary_machine_store_bytes[S](entry)
	} $else {
		$compile_error('Source pop_and_store requires a translated machine operand type')
	}
	return interpreter.store_value(mut configuration, instruction, BinaryMachineBytes{
		data: bytes.data
		size: usize(bytes.len)
	}, 1, addresses)
}
