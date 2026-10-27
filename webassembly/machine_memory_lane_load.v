// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// BytecodeInterpreter.cpp:6542–6565, load_and_push_lane_n.
module webassembly

// Source's constant N is the unsigned lane primitive's sizeof(T) * 8.
// Lane bounds and the module memory index remain verifier-owned.
pub fn (mut interpreter BinaryMachineBytecodeInterpreter) load_and_push_lane_n[T](mut configuration BinaryMachineConfiguration, instruction &BinaryInstruction, addresses &BinarySourcesAndDestination) bool {
	$if T is u8 || T is u16 || T is u32 || T is u64 {
	} $else {
		$compile_error('Source lane loads instantiate only widths 8, 16, 32, 64')
	}
	if instruction.arguments !is BinaryMemoryLaneArgument {
		panic('Source unsafe_get: load_and_push_lane_n requires MemoryAndLaneArgument')
	}
	arg := instruction.arguments as BinaryMemoryLaneArgument
	address := configuration.frame().module().memories()[int(arg.memory.memory_index)]
	memory := configuration.store().unsafe_get_memory(address)
	sources := unsafe { &addresses.operands.sources[0] }
	vector := configuration.take_source(.any, 0, sources)
	base := binary_machine_memory_base_address(memory, configuration.take_source(.any, 1, sources))
	if arg.memory.offset > u64(-1) - base || u64(sizeof(T)) > u64(-1) - (base + arg.memory.offset)
		|| base + arg.memory.offset + u64(sizeof(T)) > u64(memory.size()) {
		interpreter.trap_ = BinaryMachineTrap.from_string('Memory access out of bounds')
		return true
	}
	instance_address := base + arg.memory.offset
	mut bytes := binary_machine_store_bytes[BinaryMachineValue](vector)
	dst := unsafe { &bytes[0] + int(arg.lane) * int(sizeof(T)) }
	memory.data().copy_to(uint(instance_address), BinaryMachineBytes{ data: dst, size: uint(sizeof(T)) })
	loaded := binary_machine_read_value[BinaryMachineValue](BinaryMachineBytes{ data: unsafe { &bytes[0] }, size: 16 })
	configuration.push_to_destination(.any, loaded, unsafe { addresses.operands.destination })
	return false
}
