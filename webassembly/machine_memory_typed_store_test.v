module webassembly

import encoding.hex
import libjs
import os
import strconv

fn execute_source_typed_store(kind string, mut interpreter BinaryMachineBytecodeInterpreter, mut configuration BinaryMachineConfiguration, instruction &BinaryInstruction, addresses &BinarySourcesAndDestination) bool {
	return match kind {
		'i32_i32' { interpreter.pop_and_store[i32, i32](mut configuration, instruction, addresses) }
		'i64_i64' { interpreter.pop_and_store[i64, i64](mut configuration, instruction, addresses) }
		'f32_f32' { interpreter.pop_and_store[f32, f32](mut configuration, instruction, addresses) }
		'f64_f64' { interpreter.pop_and_store[f64, f64](mut configuration, instruction, addresses) }
		'i32_i8' { interpreter.pop_and_store[i32, i8](mut configuration, instruction, addresses) }
		'i32_i16' { interpreter.pop_and_store[i32, i16](mut configuration, instruction, addresses) }
		'i64_i8' { interpreter.pop_and_store[i64, i8](mut configuration, instruction, addresses) }
		'i64_i16' { interpreter.pop_and_store[i64, i16](mut configuration, instruction, addresses) }
		'i64_i32' { interpreter.pop_and_store[i64, i32](mut configuration, instruction, addresses) }
		'u128_u128' {
			interpreter.pop_and_store[BinaryMachineValue, BinaryMachineValue](mut configuration, instruction, addresses)
		}
		else { panic('unexpected actual Source store instantiation') }
	}
}

fn test_source_typed_stores_match_actual_cpp_temporaries_through_all_operand_sources() {
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
	owner := BinaryMachineModuleInstance.create_with_contents(BinaryMachineModuleConstruction{
		memories: [
			second_address,
			first_address,
		]
	})
	expression := &BinaryExpression{ instructions: [BinaryInstruction{ opcode: binary_op_synthetic_end_expression }] }
	configuration.set_frame_lightweight(owner, unsafe { nil }, expression, 0, 0)
	configuration.setup_call_record(2)
	configuration.value_stack_.append(BinaryMachineValue.from_i64(91))
	configuration.regs[7] = BinaryMachineValue.from_i64(97)
	configuration.ip_ = 73
	instruction := &BinaryInstruction{ arguments: BinaryMemoryArgument{ memory_index: 0, offset: 3, align: 31 } }
	base := BinaryMachineValue.from_u64(0x100000002)
	base_call := unsafe { BinaryRegisterOrStack(int(BinaryRegisterOrStack.call_record) + 1) }
	mut buffer := second.data()
	mut observations := 0
	for line in os.read_file('${os.dir(@DIR)}/webassembly/fixtures/memory_store.tsv')!.split_into_lines() {
		if line.starts_with('#') || line.len == 0 { continue }
		fields := line.split('\t')
		assert fields.len == 4
		value := BinaryMachineValue{ low: strconv.parse_uint(fields[1], 16, 64)!, high: strconv.parse_uint(fields[2], 16, 64)! }
		expected := hex.decode(fields[3])!
		for value_source in [BinaryRegisterOrStack.r2, .stack, .call_record] {
			for base_source in [BinaryRegisterOrStack.r3, .stack, base_call] {
				addresses := &BinarySourcesAndDestination{
					operands: BinarySourcesAndDestinationFields{
						sources:     [
							value_source,
							base_source,
							.r4,
						]!
						destination: .stack
					}
				}
				sources := unsafe { &addresses.operands.sources[0] }
				// Stack address precedes stack value. Non-stack operands remain
				// in their original register/call-record slots after the store.
				if base_source == .stack {
					configuration.value_stack_.append(base)
				} else {
					mut slot := configuration.source_value(.any, 1, sources)
					unsafe { *slot = base }
				}
				if value_source == .stack {
					configuration.value_stack_.append(value)
				} else {
					mut slot := configuration.source_value(.any, 0, sources)
					unsafe { *slot = value }
				}
				before_regs := configuration.regs
				before_call0 := *configuration.call_record_entry(0)
				before_call1 := *configuration.call_record_entry(1)
				buffer.fill(0, u8(0x79), 32)
				interpreter.set_trap_message('Earlier trap')
				assert !execute_source_typed_store(fields[0], mut interpreter, mut configuration, instruction, addresses)
				for index in 0 .. 32 {
					wanted := if index >= 5 && index < 5 + expected.len {
						expected[index - 5]
					} else {
						u8(0x79)
					}
					assert unsafe { buffer.data()[index] } == wanted, line
					assert unsafe { first.data().data()[index] } == 0
				}
				assert configuration.value_stack_.size() == 1
				assert configuration.value_stack_.last().to_i64() == 91
				assert configuration.regs == before_regs
				assert *configuration.call_record_entry(0) == before_call0
				assert *configuration.call_record_entry(1) == before_call1
				assert configuration.ip_ == 73
				assert interpreter.trap().format() == 'Earlier trap'
				observations++
			}
		}
	}
	assert observations == 1800
}

fn test_source_typed_store_consumes_stack_value_then_address_even_when_bounds_trap() {
	stack_info := libjs.StackInfo.new()
	mut interpreter := BinaryMachineBytecodeInterpreter.create(&stack_info)
	mut store := BinaryMachineStore.create()
	address := store.allocate_memory(WasmLimits{ address_type: .i64, minimum: 1, maximum: u64(2) })?
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
	addresses := &BinarySourcesAndDestination{
		operands: BinarySourcesAndDestinationFields{
			sources:     [
				BinaryRegisterOrStack.stack,
				.stack,
				.r4,
			]!
			destination: .r7
		}
	}
	mut buffer := memory.data()
	buffer.fill(0, u8(0x79), memory.size())
	for base in [u64(memory.size()) - 7, u64(memory.size()), u64(0x100000002), u64(-1) - 3, u64(-1)] {
		for offset in [u64(0), 1, u64(-1)] {
			instruction := &BinaryInstruction{ arguments: BinaryMemoryArgument{ offset: offset } }
			configuration.value_stack_.append(BinaryMachineValue.from_u64(base))
			configuration.value_stack_.append(BinaryMachineValue.from_u64(0x0123456789abcdef))
			assert interpreter.pop_and_store[i64, i64](mut configuration, instruction, addresses)
			assert interpreter.trap().format() == 'Memory access out of bounds'
			assert configuration.value_stack_.size() == 1
			assert configuration.value_stack_.last().to_i64() == 91
			assert configuration.regs[7].to_i64() == 97 && configuration.ip_ == 73
			for index in 0 .. int(memory.size()) {
				assert unsafe { buffer.data()[index] } == 0x79
			}
		}
	}
	// An exact end is valid, including after actual MemoryInstance growth.
	for grow in [false, true] {
		if grow {
			assert memory.grow(usize(page_size), .yes, .no)
		}
		configuration.value_stack_.append(BinaryMachineValue.from_u64(u64(memory.size()) - 8))
		configuration.value_stack_.append(BinaryMachineValue.from_u64(0x0123456789abcdef))
		interpreter.set_trap_message('Earlier trap')
		assert !interpreter.pop_and_store[i64, i64](mut configuration, &BinaryInstruction{ arguments: BinaryMemoryArgument{} }, addresses)
		payload := hex.decode('efcdab8967452301')!
		for index in 0 .. payload.len {
			assert unsafe { memory.data().data()[memory.size() - 8 + usize(index)] } == payload[index]
		}
		assert configuration.value_stack_.size() == 1
		assert interpreter.trap().format() == 'Earlier trap'
	}
}

fn test_source_typed_store_memory_argument_guard_survives_production() {
	if os.getenv('VOX2_WASM_INVALID_TYPED_STORE_ARGUMENT') == '1' {
		stack_info := libjs.StackInfo.new()
		mut interpreter := BinaryMachineBytecodeInterpreter.create(&stack_info)
		mut store := BinaryMachineStore.create()
		mut configuration := BinaryMachineConfiguration.create(mut store)
		configuration.value_stack_.append(BinaryMachineValue.from_i64(2))
		configuration.value_stack_.append(BinaryMachineValue.from_i64(9))
		addresses := &BinarySourcesAndDestination{
			operands: BinarySourcesAndDestinationFields{
				sources: [
					BinaryRegisterOrStack.stack,
					.stack,
					.r0,
				]!
			}
		}
		interpreter.pop_and_store[i64, i64](mut configuration, &BinaryInstruction{}, addresses)
		panic('Source unsafe_get guard unexpectedly returned')
	}
	mut process := os.new_process(os.executable())
	defer { process.close() }
	mut environment := os.environ()
	environment['VOX2_WASM_INVALID_TYPED_STORE_ARGUMENT'] = '1'
	process.set_environment(environment)
	process.set_redirect_stdio()
	process.run()
	process.wait()
	output := process.stdout_slurp() + process.stderr_slurp()
	assert process.code != 0 && output.contains('Source unsafe_get: store_value requires MemoryArgument'), output
}

fn test_source_store_value_routes_requested_address_operand_and_copies_borrowed_bytes() {
	stack_info := libjs.StackInfo.new()
	mut interpreter := BinaryMachineBytecodeInterpreter.create(&stack_info)
	mut store := BinaryMachineStore.create()
	address := store.allocate_memory(WasmLimits{ minimum: 1, maximum: u64(1) })?
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
	configuration.value_stack_.append(BinaryMachineValue.from_i64(7))
	configuration.regs[0] = BinaryMachineValue.from_i64(19)
	configuration.regs[1] = BinaryMachineValue.from_i64(31)
	addresses := &BinarySourcesAndDestination{
		operands: BinarySourcesAndDestinationFields{
			sources:     [
				BinaryRegisterOrStack.r0,
				.r1,
				.stack,
			]!
			destination: .stack
		}
	}
	mut borrowed := [u8(0x80), 0, 0xff, 0x41]
	instruction := &BinaryInstruction{ arguments: BinaryMemoryArgument{ offset: 3 } }
	assert !interpreter.store_value(mut configuration, instruction, BinaryMachineBytes{ data: borrowed.data, size: usize(borrowed.len) }, 2, addresses)
	borrowed[0] = 0x11
	assert unsafe { memory.data().data()[10] } == 0x80
	assert unsafe { memory.data().data()[11] } == 0
	assert unsafe { memory.data().data()[12] } == 0xff
	assert unsafe { memory.data().data()[13] } == 0x41
	assert configuration.value_stack_.size() == 1 && configuration.value_stack_.last().to_i64() == 91
	assert configuration.regs[0].to_i64() == 19 && configuration.regs[1].to_i64() == 31
}
