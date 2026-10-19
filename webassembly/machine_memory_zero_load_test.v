module webassembly

import encoding.hex
import libjs
import os
import strconv

fn execute_source_zero_load(width int, mut interpreter BinaryMachineBytecodeInterpreter, mut configuration BinaryMachineConfiguration, instruction &BinaryInstruction, addresses &BinarySourcesAndDestination) bool {
	return match width {
		32 { interpreter.load_and_push_zero_n[u32](mut configuration, instruction, addresses) }
		64 { interpreter.load_and_push_zero_n[u64](mut configuration, instruction, addresses) }
		else { panic('unexpected Source zero load width') }
	}
}

fn test_source_zero_load_preserves_native_low_bytes_and_clears_every_upper_vector_byte() {
	stack_info := libjs.StackInfo.new()
	mut interpreter := BinaryMachineBytecodeInterpreter.create(&stack_info)
	mut store := BinaryMachineStore.create()
	first_address := store.allocate_memory(WasmLimits{ address_type: .i64, minimum: 1, maximum: u64(1) })?
	second_address := store.allocate_memory(WasmLimits{ minimum: 1, maximum: u64(1) })?
	mut first := store.unsafe_get_memory(first_address)
	mut second := store.unsafe_get_memory(second_address)
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer {
		configuration.destroy()
		first.destroy()
		second.destroy()
	}
	owner := BinaryMachineModuleInstance.create_with_contents(BinaryMachineModuleConstruction{ memories: [
		second_address,
		first_address,
	] })
	expression := &BinaryExpression{ instructions: [BinaryInstruction{ opcode: binary_op_synthetic_end_expression }] }
	configuration.set_frame_lightweight(owner, unsafe { nil }, expression, 0, 0)
	configuration.setup_call_record(3)
	configuration.value_stack_.append(BinaryMachineValue.from_i64(91))
	configuration.ip_ = 73
	base := BinaryMachineValue.from_u64(0x100000002)
	destination_call := unsafe { BinaryRegisterOrStack(int(BinaryRegisterOrStack.call_record) + 2) }
	mut buffer := second.data()
	mut observations := 0
	for line in os.read_file('${os.dir(@DIR)}/webassembly/fixtures/memory_zero_load.tsv')!.split_into_lines() {
		if line.starts_with('#') || line.len == 0 { continue }
		fields := line.split('\t')
		assert fields.len == 4
		width := fields[0].int()
		incoming := hex.decode(fields[1])!
		expected := BinaryMachineValue{ low: strconv.parse_uint(fields[2], 16, 64)!, high: strconv.parse_uint(fields[3], 16, 64)! }
		instruction := &BinaryInstruction{ arguments: BinaryMemoryArgument{ memory_index: 0, offset: 3, align: 31 } }
		for source in [BinaryRegisterOrStack.r2, .stack, .call_record] {
			for destination in [BinaryRegisterOrStack.r7, .stack, destination_call, source] {
				addresses := &BinarySourcesAndDestination{ operands: BinarySourcesAndDestinationFields{ sources: [
					source,
					.r4,
					.r5,
				]!, destination: destination } }
				sources := unsafe { &addresses.operands.sources[0] }
				configuration.regs[7] = BinaryMachineValue{ low: u64(-1), high: u64(-1) }
				mut output_call := configuration.call_record_entry(2)
				unsafe { *output_call = BinaryMachineValue{ low: u64(-1), high: u64(-1) } }
				if source == .stack {
					configuration.value_stack_.append(base)
				} else {
					mut slot := configuration.source_value(.any, 0, sources)
					unsafe { *slot = base }
				}
				before_regs := configuration.regs
				before_call0 := *configuration.call_record_entry(0)
				before_call1 := *configuration.call_record_entry(1)
				buffer.fill(0, u8(0x79), 32)
				buffer.overwrite(5, incoming.data, usize(incoming.len))
				interpreter.set_trap_message('Earlier trap')
				assert !execute_source_zero_load(width, mut interpreter, mut configuration, instruction, addresses)
				if destination == .stack {
					assert configuration.value_stack_.size() == 2
					assert configuration.value_stack_.unsafe_take_last() == expected, line
				} else if destination == .r7 || destination == .r2 {
					assert configuration.regs[int(destination)] == expected, line
				} else {
					assert *configuration.call_record_entry(usize(int(destination) - int(BinaryRegisterOrStack.call_record))) == expected, line
				}
				assert configuration.value_stack_.size() == 1 && configuration.value_stack_.last().to_i64() == 91
				for index in 0 .. 8 {
					if int(destination) != index {
						assert configuration.regs[index] == before_regs[index]
					}
				}
				if destination != .call_record {
					assert *configuration.call_record_entry(0) == before_call0
				}
				assert *configuration.call_record_entry(1) == before_call1
				if destination != destination_call {
					assert configuration.call_record_entry(2).high == u64(-1)
				}
				for index in 0 .. 32 {
					wanted := if index >= 5 && index < 5 + incoming.len {
						incoming[index - 5]
					} else {
						u8(0x79)
					}
					assert unsafe { buffer.data()[index] } == wanted
					assert unsafe { first.data().data()[index] } == 0
				}
				assert configuration.ip_ == 73 && interpreter.trap().format() == 'Earlier trap'
				observations++
			}
		}
	}
	assert observations == 480
}

fn test_source_zero_load_consumes_only_the_address_before_memory64_bounds_trap() {
	stack_info := libjs.StackInfo.new()
	mut interpreter := BinaryMachineBytecodeInterpreter.create(&stack_info)
	mut store := BinaryMachineStore.create()
	address := store.allocate_memory(WasmLimits{ address_type: .i64, minimum: 1, maximum: u64(1) })?
	mut memory := store.unsafe_get_memory(address)
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer {
		configuration.destroy()
		memory.destroy()
	}
	owner := BinaryMachineModuleInstance.create_with_contents(BinaryMachineModuleConstruction{ memories: [address] })
	expression := &BinaryExpression{ instructions: [BinaryInstruction{ opcode: binary_op_synthetic_end_expression }] }
	configuration.set_frame_lightweight(owner, unsafe { nil }, expression, 0, 0)
	configuration.value_stack_.append(BinaryMachineValue.from_i64(91))
	configuration.regs[7] = BinaryMachineValue{ low: u64(-1), high: u64(-1) }
	configuration.ip_ = 73
	addresses := &BinarySourcesAndDestination{ operands: BinarySourcesAndDestinationFields{ sources: [
		BinaryRegisterOrStack.stack,
		.r0,
		.r1,
	]!, destination: .r7 } }
	mut buffer := memory.data()
	buffer.fill(0, u8(0x79), memory.size())
	for width in [32, 64] {
		for base in [u64(memory.size()), u64(0x100000002), u64(-1)] {
			for offset in [u64(0), 1, u64(-1)] {
				configuration.value_stack_.append(BinaryMachineValue.from_u64(base))
				instruction := &BinaryInstruction{ arguments: BinaryMemoryArgument{ offset: offset } }
				assert execute_source_zero_load(width, mut interpreter, mut configuration, instruction, addresses)
				assert interpreter.trap().format() == 'Memory access out of bounds'
				assert configuration.value_stack_.size() == 1 && configuration.value_stack_.last().to_i64() == 91
				assert configuration.regs[7] == BinaryMachineValue{ low: u64(-1), high: u64(-1) }
				assert configuration.ip_ == 73
			}
		}
	}
	for index in 0 .. int(memory.size()) {
		assert unsafe { buffer.data()[index] } == 0x79
	}
	configuration.value_stack_.append(BinaryMachineValue.from_u64(u64(memory.size()) - 7))
	instruction := &BinaryInstruction{ arguments: BinaryMemoryArgument{ offset: 3 } }
	assert !interpreter.load_and_push_zero_n[u32](mut configuration, instruction, addresses)
	assert configuration.regs[7] == BinaryMachineValue{ low: 0x79797979, high: 0 }
	assert configuration.value_stack_.size() == 1
}

fn test_source_zero_load_argument_guard_precedes_frame_and_operand_access_in_production() {
	if os.getenv('VOX2_WASM_INVALID_ZERO_LOAD_ARGUMENT') == '1' {
		stack_info := libjs.StackInfo.new()
		mut interpreter := BinaryMachineBytecodeInterpreter.create(&stack_info)
		mut store := BinaryMachineStore.create()
		mut configuration := BinaryMachineConfiguration.create(mut store)
		addresses := &BinarySourcesAndDestination{ operands: BinarySourcesAndDestinationFields{ sources: [
			BinaryRegisterOrStack.stack,
			.r0,
			.r1,
		]! } }
		instruction := &BinaryInstruction{ arguments: BinaryMemoryLaneArgument{} }
		interpreter.load_and_push_zero_n[u32](mut configuration, instruction, addresses)
		panic('Source zero load guard unexpectedly returned')
	}
	mut process := os.new_process(os.executable())
	defer { process.close() }
	mut environment := os.environ()
	environment['VOX2_WASM_INVALID_ZERO_LOAD_ARGUMENT'] = '1'
	process.set_environment(environment)
	process.set_redirect_stdio()
	process.run()
	process.wait()
	output := process.stdout_slurp() + process.stderr_slurp()
	assert process.code != 0 && output.contains('Source unsafe_get: load_and_push_zero_n requires MemoryArgument'), output
}
