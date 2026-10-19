module webassembly

import encoding.hex
import libjs
import os
import strconv

fn execute_source_lane_store(width int, mut interpreter BinaryMachineBytecodeInterpreter, mut configuration BinaryMachineConfiguration, instruction &BinaryInstruction, addresses &BinarySourcesAndDestination) bool {
	return match width {
		8 { interpreter.pop_and_store_lane_n[u8](mut configuration, instruction, addresses) }
		16 { interpreter.pop_and_store_lane_n[u16](mut configuration, instruction, addresses) }
		32 { interpreter.pop_and_store_lane_n[u32](mut configuration, instruction, addresses) }
		64 { interpreter.pop_and_store_lane_n[u64](mut configuration, instruction, addresses) }
		else { panic('unexpected Source lane width') }
	}
}

fn test_source_lane_stores_match_native_vector_views_for_all_valid_lanes_and_operands() {
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
	configuration.setup_call_record(2)
	configuration.value_stack_.append(BinaryMachineValue.from_i64(91))
	configuration.regs[7] = BinaryMachineValue.from_i64(97)
	configuration.ip_ = 73
	base := BinaryMachineValue.from_u64(0x100000002)
	base_call := unsafe { BinaryRegisterOrStack(int(BinaryRegisterOrStack.call_record) + 1) }
	mut buffer := second.data()
	mut observations := 0
	for line in os.read_file('${os.dir(@DIR)}/webassembly/fixtures/memory_lane_store.tsv')!.split_into_lines() {
		if line.starts_with('#') || line.len == 0 { continue }
		fields := line.split('\t')
		assert fields.len == 5
		width := fields[0].int()
		vector := BinaryMachineValue{ low: strconv.parse_uint(fields[2], 16, 64)!, high: strconv.parse_uint(fields[3], 16, 64)! }
		expected := hex.decode(fields[4])!
		instruction := &BinaryInstruction{ arguments: BinaryMemoryLaneArgument{ memory: BinaryMemoryArgument{ memory_index: 0, offset: 3, align: 31 }, lane: u8(fields[1].int()) } }
		for vector_source in [BinaryRegisterOrStack.r2, .stack, .call_record] {
			for base_source in [BinaryRegisterOrStack.r3, .stack, base_call] {
				addresses := &BinarySourcesAndDestination{ operands: BinarySourcesAndDestinationFields{ sources: [
					vector_source,
					base_source,
					.r4,
				]!, destination: .stack } }
				sources := unsafe { &addresses.operands.sources[0] }
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
				interpreter.set_trap_message('Earlier trap')
				assert !execute_source_lane_store(width, mut interpreter, mut configuration, instruction, addresses)
				for index in 0 .. 32 {
					wanted := if index >= 5 && index < 5 + expected.len {
						expected[index - 5]
					} else {
						u8(0x79)
					}
					assert unsafe { buffer.data()[index] } == wanted, line
					assert unsafe { first.data().data()[index] } == 0
				}
				assert configuration.value_stack_.size() == 1 && configuration.value_stack_.last().to_i64() == 91
				assert configuration.regs == before_regs
				assert *configuration.call_record_entry(0) == before_call0
				assert *configuration.call_record_entry(1) == before_call1
				assert configuration.ip_ == 73 && interpreter.trap().format() == 'Earlier trap'
				observations++
			}
		}
	}
	assert observations == 5400
}

fn test_source_lane_store_consumes_vector_and_address_before_memory64_checked_failure() {
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
					assert execute_source_lane_store(width, mut interpreter, mut configuration, instruction, addresses)
					assert interpreter.trap().format() == 'Memory access out of bounds'
					assert configuration.value_stack_.size() == 1 && configuration.value_stack_.last().to_i64() == 91
					assert configuration.regs[7].to_i64() == 97 && configuration.ip_ == 73
					for index in 0 .. int(memory.size()) {
						assert unsafe { buffer.data()[index] } == 0x79
					}
				}
			}
		}
	}
	configuration.value_stack_.append(BinaryMachineValue.from_u64(u64(memory.size()) - 8))
	configuration.value_stack_.append(BinaryMachineValue{ low: 0x0123456789abcdef, high: 0xfedcba9876543210 })
	instruction := &BinaryInstruction{ arguments: BinaryMemoryLaneArgument{ lane: 1 } }
	assert !interpreter.pop_and_store_lane_n[u64](mut configuration, instruction, addresses)
	expected := hex.decode('1032547698badcfe')!
	for index in 0 .. 8 {
		assert unsafe { buffer.data()[memory.size() - 8 + usize(index)] } == expected[index]
	}
	assert configuration.value_stack_.size() == 1
}

fn test_source_lane_memory_argument_guard_precedes_any_operand_access_in_production() {
	if os.getenv('VOX2_WASM_INVALID_LANE_STORE_ARGUMENT') == '1' {
		stack_info := libjs.StackInfo.new()
		mut interpreter := BinaryMachineBytecodeInterpreter.create(&stack_info)
		mut store := BinaryMachineStore.create()
		mut configuration := BinaryMachineConfiguration.create(mut store)
		// The stack is intentionally empty: unsafe_get must fail first.
		addresses := &BinarySourcesAndDestination{ operands: BinarySourcesAndDestinationFields{ sources: [
			BinaryRegisterOrStack.stack,
			.stack,
			.r0,
		]! } }
		interpreter.pop_and_store_lane_n[u64](mut configuration, &BinaryInstruction{}, addresses)
		panic('Source lane guard unexpectedly returned')
	}
	mut process := os.new_process(os.executable())
	defer { process.close() }
	mut environment := os.environ()
	environment['VOX2_WASM_INVALID_LANE_STORE_ARGUMENT'] = '1'
	process.set_environment(environment)
	process.set_redirect_stdio()
	process.run()
	process.wait()
	output := process.stdout_slurp() + process.stderr_slurp()
	assert process.code != 0 && output.contains('Source unsafe_get: pop_and_store_lane_n requires MemoryAndLaneArgument'), output
}
