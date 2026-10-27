module webassembly

import encoding.hex
import libjs
import os
import strconv

fn execute_source_lane_load(width int, mut interpreter BinaryMachineBytecodeInterpreter, mut configuration BinaryMachineConfiguration, instruction &BinaryInstruction, addresses &BinarySourcesAndDestination) bool {
	return match width {
		8 { interpreter.load_and_push_lane_n[u8](mut configuration, instruction, addresses) }
		16 { interpreter.load_and_push_lane_n[u16](mut configuration, instruction, addresses) }
		32 { interpreter.load_and_push_lane_n[u32](mut configuration, instruction, addresses) }
		64 { interpreter.load_and_push_lane_n[u64](mut configuration, instruction, addresses) }
		else { panic('unexpected Source lane width') }
	}
}

fn test_source_lane_load_native_vector_bytes_and_actual_source_destination_owners() {
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
	base_call := unsafe { BinaryRegisterOrStack(int(BinaryRegisterOrStack.call_record) + 1) }
	destination_call := unsafe { BinaryRegisterOrStack(int(BinaryRegisterOrStack.call_record) + 2) }
	mut buffer := second.data()
	mut observations := 0
	for line in os.read_file('${os.dir(@DIR)}/webassembly/fixtures/memory_lane_load.tsv')!.split_into_lines() {
		if line.starts_with('#') || line.len == 0 { continue }
		fields := line.split('\t')
		assert fields.len == 7
		width := fields[0].int()
		vector := BinaryMachineValue{ low: strconv.parse_uint(fields[2], 16, 64)!, high: strconv.parse_uint(fields[3], 16, 64)! }
		incoming := hex.decode(fields[4])!
		expected := BinaryMachineValue{ low: strconv.parse_uint(fields[5], 16, 64)!, high: strconv.parse_uint(fields[6], 16, 64)! }
		instruction := &BinaryInstruction{ arguments: BinaryMemoryLaneArgument{ memory: BinaryMemoryArgument{ memory_index: 0, offset: 3, align: 31 }, lane: u8(fields[1].int()) } }
		for vector_source in [BinaryRegisterOrStack.r2, .stack, .call_record] {
			for base_source in [BinaryRegisterOrStack.r3, .stack, base_call] {
				for destination in [BinaryRegisterOrStack.r7, .stack, destination_call, vector_source] {
					addresses := &BinarySourcesAndDestination{ operands: BinarySourcesAndDestinationFields{ sources: [
						vector_source,
						base_source,
						.r4,
					]!, destination: destination } }
					sources := unsafe { &addresses.operands.sources[0] }
					configuration.regs[7] = BinaryMachineValue.from_i64(97)
					mut output_call := configuration.call_record_entry(2)
					unsafe { *output_call = BinaryMachineValue.from_i64(98) }
					if base_source == .stack {
						configuration.value_stack_.append(base)
					} else {
						mut slot := configuration.source_value(.any, 1, sources)
						unsafe { *slot = base }
					}
					if vector_source == .stack {
						configuration.value_stack_.append(vector)
					} else {
						mut slot := configuration.source_value(.any, 0, sources)
						unsafe { *slot = vector }
					}
					before_regs := configuration.regs
					before_call0 := *configuration.call_record_entry(0)
					before_call1 := *configuration.call_record_entry(1)
					buffer.fill(0, u8(0x79), 32)
					buffer.overwrite(5, incoming.data, uint(incoming.len))
					interpreter.set_trap_message('Earlier trap')
					assert !execute_source_lane_load(width, mut interpreter, mut configuration, instruction, addresses)
					if destination == .stack {
						assert configuration.value_stack_.size() == 2
						assert configuration.value_stack_.unsafe_take_last() == expected, line
					} else if destination == .r7 || destination == .r2 {
						assert configuration.regs[int(destination)] == expected, line
					} else {
						assert *configuration.call_record_entry(uint(int(destination) - int(BinaryRegisterOrStack.call_record))) == expected, line
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
						assert configuration.call_record_entry(2).to_i64() == 98
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
	}
	assert observations == 21600
}

fn test_source_lane_load_consumes_both_stack_operands_on_memory64_bounds_trap_and_supports_exact_end() {
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
	configuration.regs[7] = BinaryMachineValue.from_i64(97)
	configuration.ip_ = 73
	addresses := &BinarySourcesAndDestination{ operands: BinarySourcesAndDestinationFields{ sources: [
		BinaryRegisterOrStack.stack,
		.stack,
		.r0,
	]!, destination: .r7 } }
	mut buffer := memory.data()
	buffer.fill(0, u8(0x79), memory.size())
	for width in [8, 16, 32, 64] {
		for lane in 0 .. 128 / width {
			for base in [u64(memory.size()), u64(0x100000002), u64(-1)] {
				for offset in [u64(0), 1, u64(-1)] {
					configuration.value_stack_.append(BinaryMachineValue.from_u64(base))
					configuration.value_stack_.append(BinaryMachineValue{ low: 0x0123456789abcdef, high: 0xfedcba9876543210 })
					instruction := &BinaryInstruction{ arguments: BinaryMemoryLaneArgument{ memory: BinaryMemoryArgument{ offset: offset }, lane: u8(lane) } }
					assert execute_source_lane_load(width, mut interpreter, mut configuration, instruction, addresses)
					assert interpreter.trap().format() == 'Memory access out of bounds'
					assert configuration.value_stack_.size() == 1 && configuration.value_stack_.last().to_i64() == 91
					assert configuration.regs[7].to_i64() == 97 && configuration.ip_ == 73
				}
			}
		}
	}
	for index in 0 .. int(memory.size()) {
		assert unsafe { buffer.data()[index] } == 0x79
	}
	configuration.value_stack_.append(BinaryMachineValue.from_u64(u64(memory.size()) - 8))
	configuration.value_stack_.append(BinaryMachineValue{ low: 0x0123456789abcdef, high: 0xfedcba9876543210 })
	instruction := &BinaryInstruction{ arguments: BinaryMemoryLaneArgument{ lane: 1 } }
	assert !interpreter.load_and_push_lane_n[u64](mut configuration, instruction, addresses)
	assert configuration.regs[7] == BinaryMachineValue{ low: 0x0123456789abcdef, high: 0x7979797979797979 }
	assert configuration.value_stack_.size() == 1
}

fn test_source_lane_load_argument_guard_precedes_frame_and_stack_access_in_production() {
	if os.getenv('VOX2_WASM_INVALID_LANE_LOAD_ARGUMENT') == '1' {
		stack_info := libjs.StackInfo.new()
		mut interpreter := BinaryMachineBytecodeInterpreter.create(&stack_info)
		mut store := BinaryMachineStore.create()
		mut configuration := BinaryMachineConfiguration.create(mut store)
		// No frame and no operands: Source unsafe_get must fail first.
		addresses := &BinarySourcesAndDestination{ operands: BinarySourcesAndDestinationFields{ sources: [
			BinaryRegisterOrStack.stack,
			.stack,
			.r0,
		]! } }
		interpreter.load_and_push_lane_n[u64](mut configuration, &BinaryInstruction{}, addresses)
		panic('Source lane load guard unexpectedly returned')
	}
	mut process := os.new_process(os.executable())
	defer { process.close() }
	mut environment := os.environ()
	environment['VOX2_WASM_INVALID_LANE_LOAD_ARGUMENT'] = '1'
	process.set_environment(environment)
	process.set_redirect_stdio()
	process.run()
	process.wait()
	output := process.stdout_slurp() + process.stderr_slurp()
	assert process.code != 0 && output.contains('Source unsafe_get: load_and_push_lane_n requires MemoryAndLaneArgument'), output
}
