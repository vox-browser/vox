// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// BytecodeInterpreter.cpp:6569–6589, load_and_push_zero_n.
module webassembly

pub fn (mut interpreter BinaryMachineBytecodeInterpreter) load_and_push_zero_n[T](mut configuration BinaryMachineConfiguration, instruction &BinaryInstruction, addresses &BinarySourcesAndDestination) bool {
	$if T is u32 || T is u64 {
	} $else {
		$compile_error('Source zero loads instantiate only widths 32 and 64')
	}
	if instruction.arguments !is BinaryMemoryArgument {
		panic('Source unsafe_get: load_and_push_zero_n requires MemoryArgument')
	}
	arg := instruction.arguments as BinaryMemoryArgument
	address := configuration.frame().module().memories()[int(arg.memory_index)]
	memory := configuration.store().unsafe_get_memory(address)
	sources := unsafe { &addresses.operands.sources[0] }
	base := binary_machine_memory_base_address(memory, configuration.take_source(.any, 0, sources))
	if arg.offset > u64(-1) - base || u64(sizeof(T)) > u64(-1) - (base + arg.offset)
		|| base + arg.offset + u64(sizeof(T)) > u64(memory.size()) {
		interpreter.trap_ = BinaryMachineTrap.from_string('Memory access out of bounds')
		return true
	}
	instance_address := base + arg.offset
	mut bytes := [16]u8{}
	memory.data().copy_to(uint(instance_address), BinaryMachineBytes{ data: unsafe { &bytes[0] }, size: uint(sizeof(T)) })
	vector := binary_machine_read_value[BinaryMachineValue](BinaryMachineBytes{ data: unsafe { &bytes[0] }, size: 16 })
	configuration.push_to_destination(.any, vector, unsafe { addresses.operands.destination })
	return false
}
