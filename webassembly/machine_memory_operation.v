// Copyright (c) 2021-2025, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// BytecodeInterpreter.cpp::memory_base_address and store_to_memory.
module webassembly

// Source memory32 addresses must undo Value's sign extension. Memory64 keeps
// the full u64; the reservation limit does not narrow an instruction operand.
fn binary_machine_memory_base_address(memory &BinaryMachineMemoryInstance, entry BinaryMachineValue) u64 {
	base := entry.to_u64()
	if memory.type_().address_type == .i32 {
		return u64(u32(base))
	}
	return base
}

// The ReadonlyBytes specialization of Source's templated overload. Typed
// stores and opcode dispatch are separate consumers of this actual helper.
pub fn (mut interpreter BinaryMachineBytecodeInterpreter) store_to_memory_instance(mut memory BinaryMachineMemoryInstance, address u64, data BinaryMachineBytes) bool {
	// Lower Checked<u64>::operator+= without changing its overflow branch.
	if u64(data.size) > u64(-1) - address || address + u64(data.size) > u64(memory.size()) {
		interpreter.trap_ = BinaryMachineTrap.from_string('Memory access out of bounds')
		return true
	}
	mut buffer := memory.data()
	buffer.overwrite(uint(address), data.data, data.size)
	return false
}

// Source resolves the selected module memory before adding its offset.
pub fn (mut interpreter BinaryMachineBytecodeInterpreter) store_to_memory(mut configuration BinaryMachineConfiguration, arg BinaryMemoryArgument, data BinaryMachineBytes, base_value BinaryMachineValue) bool {
	address := configuration.frame().module().memories()[int(arg.memory_index)]
	mut memory := configuration.store().unsafe_get_memory(address)
	base := binary_machine_memory_base_address(memory, base_value)
	if arg.offset > u64(-1) - base {
		interpreter.trap_ = BinaryMachineTrap.from_string('Memory access out of bounds')
		return true
	}
	return interpreter.store_to_memory_instance(mut memory, base + arg.offset, data)
}
