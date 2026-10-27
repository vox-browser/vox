// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// BytecodeInterpreter.cpp:6816–6825, pop_and_store_lane_n.
module webassembly

// Source's constant N is represented by the corresponding unsigned lane
// primitive: sizeof(T) == N/8. The verifier owns the lane-index bounds.
pub fn (mut interpreter BinaryMachineBytecodeInterpreter) pop_and_store_lane_n[T](mut configuration BinaryMachineConfiguration, instruction &BinaryInstruction, addresses &BinarySourcesAndDestination) bool {
	$if T is u8 || T is u16 || T is u32 || T is u64 {
	} $else {
		$compile_error('Source lane stores instantiate only widths 8, 16, 32, 64')
	}
	if instruction.arguments !is BinaryMemoryLaneArgument {
		panic('Source unsafe_get: pop_and_store_lane_n requires MemoryAndLaneArgument')
	}
	arg := instruction.arguments as BinaryMemoryLaneArgument
	sources := unsafe { &addresses.operands.sources[0] }
	vector := configuration.take_source(.any, 0, sources)
	bytes := binary_machine_store_bytes[BinaryMachineValue](vector)
	src := unsafe { &bytes[0] + int(arg.lane) * int(sizeof(T)) }
	base := configuration.take_source(.any, 1, sources)
	return interpreter.store_to_memory(mut configuration, arg.memory, BinaryMachineBytes{
		data: src
		size: uint(sizeof(T))
	}, base)
}
