module webassembly

import encoding.hex
import libjs
import math
import os
import strconv

fn test_source_memory_read_aligned_and_unaligned_values_match_verbatim_cpp_bodies() {
	text := os.read_file('${os.dir(@DIR)}/webassembly/fixtures/memory_read.tsv')!
	mut count := 0
	for line in text.split_into_lines() {
		if line.starts_with('#') || line.len == 0 { continue }
		fields := line.split('\t')
		assert fields.len == 5
		offset := fields[1].int()
		bytes := hex.decode(fields[2])!
		low := strconv.parse_uint(fields[3], 16, 64)!
		high := strconv.parse_uint(fields[4], 16, 64)!
		mut data := [32]u8{}
		unsafe { C.memcpy(&data[offset], bytes.data, bytes.len) }
		view := BinaryMachineBytes{ data: unsafe { &data[offset] }, size: uint(bytes.len) }
		actual := match fields[0] {
			'i8' { BinaryMachineValue.from_i8(binary_machine_read_value[i8](view)) }
			'u8' { BinaryMachineValue.from_u8(binary_machine_read_value[u8](view)) }
			'i16' { BinaryMachineValue.from_i16(binary_machine_read_value[i16](view)) }
			'u16' { BinaryMachineValue.from_u16(binary_machine_read_value[u16](view)) }
			'i32' { BinaryMachineValue.from_i32(binary_machine_read_value[i32](view)) }
			// This observation is the raw unsigned read, before Source's
			// separate selected P/Value construction.
			'u32' { BinaryMachineValue.from_u64(u64(binary_machine_read_value[u32](view))) }
			'i64' { BinaryMachineValue.from_i64(binary_machine_read_value[i64](view)) }
			'u64' { BinaryMachineValue.from_u64(binary_machine_read_value[u64](view)) }
			'f32' { BinaryMachineValue.from_f32(binary_machine_read_value[f32](view)) }
			'f64' { BinaryMachineValue.from_f64(binary_machine_read_value[f64](view)) }
			'u128' { binary_machine_read_value[BinaryMachineValue](view) }
			else { panic('unexpected Source read type') }
		}
		assert actual == BinaryMachineValue{ low: low, high: high }, line
		count++
	}
	assert count == 3520
}

fn check_source_typed_load[R, P](mut interpreter BinaryMachineBytecodeInterpreter, mut configuration BinaryMachineConfiguration, instruction &BinaryInstruction, addresses &BinarySourcesAndDestination, mix BinarySourceAddressMix, expected BinaryMachineValue) {
	sources := unsafe { &addresses.operands.sources[0] }
	mut slot := configuration.source_value(mix, 0, sources)
	unsafe { *slot = BinaryMachineValue.from_u64(0x100000002) }
	interpreter.set_trap_message('Earlier trap')
	stack_size := configuration.value_stack_.size()
	assert !interpreter.load_and_push[R, P](mut configuration, instruction, addresses, mix)
	assert *slot == expected
	assert configuration.value_stack_.size() == stack_size
	assert interpreter.trap().format() == 'Earlier trap'
	assert configuration.regs[7] == BinaryMachineValue.from_i64(97)
	assert configuration.ip_ == 73
}

fn test_source_typed_load_overwrites_actual_borrowed_operand_for_all_address_modes() {
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
	configuration.setup_call_record(1)
	configuration.value_stack_.append(BinaryMachineValue.from_i64(91))
	configuration.regs[7] = BinaryMachineValue.from_i64(97)
	configuration.ip_ = 73
	bytes := [u8(0x80), 0xff, 0xff, 0x7f, 0x21, 0x43, 0xf8, 0xff, 0x81, 0, 0, 0, 0, 0, 0, 0x80]!
	mut buffer := second.data()
	buffer.overwrite(5, &bytes[0], uint(bytes.len))
	instruction := &BinaryInstruction{ arguments: BinaryMemoryArgument{ memory_index: 0, offset: 3, align: 31 } }
	for mix in [BinarySourceAddressMix.all_registers, .all_call_records, .all_stack, .any] {
		source := match mix {
			.all_registers, .any { BinaryRegisterOrStack.r2 }
			.all_call_records { BinaryRegisterOrStack.call_record }
			.all_stack { BinaryRegisterOrStack.stack }
		}
		addresses := &BinarySourcesAndDestination{
			operands: BinarySourcesAndDestinationFields{
				sources:     [
					source,
					.r3,
					.r4,
				]!
				destination: .r7
			}
		}
		check_source_typed_load[i8, i32](mut interpreter, mut configuration, instruction, addresses, mix, BinaryMachineValue.from_i32(-128))
		check_source_typed_load[u8, i32](mut interpreter, mut configuration, instruction, addresses, mix, BinaryMachineValue.from_i32(128))
		check_source_typed_load[i16, i32](mut interpreter, mut configuration, instruction, addresses, mix, BinaryMachineValue.from_i32(-128))
		check_source_typed_load[u16, i32](mut interpreter, mut configuration, instruction, addresses, mix, BinaryMachineValue.from_i32(65408))
		check_source_typed_load[i32, i32](mut interpreter, mut configuration, instruction, addresses, mix, BinaryMachineValue.from_i32(0x7fffff80))
		check_source_typed_load[i8, i64](mut interpreter, mut configuration, instruction, addresses, mix, BinaryMachineValue.from_i64(-128))
		check_source_typed_load[u8, i64](mut interpreter, mut configuration, instruction, addresses, mix, BinaryMachineValue.from_i64(128))
		check_source_typed_load[i16, i64](mut interpreter, mut configuration, instruction, addresses, mix, BinaryMachineValue.from_i64(-128))
		check_source_typed_load[u16, i64](mut interpreter, mut configuration, instruction, addresses, mix, BinaryMachineValue.from_i64(65408))
		check_source_typed_load[i32, i64](mut interpreter, mut configuration, instruction, addresses, mix, BinaryMachineValue.from_i64(0x7fffff80))
		check_source_typed_load[u32, i64](mut interpreter, mut configuration, instruction, addresses, mix, BinaryMachineValue.from_i64(0x7fffff80))
		check_source_typed_load[i64, i64](mut interpreter, mut configuration, instruction, addresses, mix, BinaryMachineValue.from_u64(0xfff843217fffff80))
		check_source_typed_load[f32, f32](mut interpreter, mut configuration, instruction, addresses, mix, BinaryMachineValue.from_f32(math.f32_from_bits(0x7fffff80)))
		check_source_typed_load[f64, f64](mut interpreter, mut configuration, instruction, addresses, mix, BinaryMachineValue.from_f64(math.f64_from_bits(0xfff843217fffff80)))
		check_source_typed_load[BinaryMachineValue, BinaryMachineValue](mut interpreter, mut configuration, instruction, addresses, mix, BinaryMachineValue{ low: 0xfff843217fffff80, high: 0x8000000000000081 })
	}
	// One raw negative i32 has distinct signed/unsigned i64 extensions.
	negative := [u8(0x80), 0xff, 0xff, 0xff]!
	buffer.overwrite(5, &negative[0], 4)
	addresses := &BinarySourcesAndDestination{ operands: BinarySourcesAndDestinationFields{ sources: [
		BinaryRegisterOrStack.r2,
		.r3,
		.r4,
	]!, destination: .r7 } }
	check_source_typed_load[i32, i64](mut interpreter, mut configuration, instruction, addresses, .any, BinaryMachineValue.from_i64(-128))
	check_source_typed_load[u32, i64](mut interpreter, mut configuration, instruction, addresses, .any, BinaryMachineValue.from_i64(4294967168))
	assert unsafe { first.data().data()[5] } == 0
}

fn test_source_load_checked_bounds_preserve_operand_and_memory_before_trapping() {
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
	addresses := &BinarySourcesAndDestination{
		operands: BinarySourcesAndDestinationFields{
			sources:     [
				BinaryRegisterOrStack.stack,
				.r0,
				.r0,
			]!
			destination: .r7
		}
	}
	for base in [u64(memory.size()) - 7, u64(memory.size()), u64(0x100000002), u64(-1) - 3, u64(-1)] {
		for offset in [u64(0), 1, u64(-1)] {
			original := BinaryMachineValue.from_u64(base)
			mut slot := configuration.value_stack_.unsafe_last()
			unsafe { *slot = original }
			instruction := &BinaryInstruction{ arguments: BinaryMemoryArgument{ offset: offset } }
			assert interpreter.load_and_push[i64, i64](mut configuration, instruction, addresses, .any)
			assert interpreter.trap().format() == 'Memory access out of bounds'
			assert *slot == original && configuration.value_stack_.size() == 1
		}
	}
	mut slot := configuration.value_stack_.unsafe_last()
	unsafe { *slot = BinaryMachineValue.from_u64(u64(memory.size()) - 8) }
	assert !interpreter.load_and_push[i64, i64](mut configuration, &BinaryInstruction{ arguments: BinaryMemoryArgument{} }, addresses, .all_stack)
	assert *slot == BinaryMachineValue{} && configuration.value_stack_.size() == 1
}

fn test_source_read_value_short_span_guard_survives_production() {
	if os.getenv('VOX2_WASM_SHORT_MEMORY_READ') == '1' {
		binary_machine_read_value[u64](BinaryMachineBytes{})
		panic('Source read_value guard unexpectedly returned')
	}
	mut process := os.new_process(os.executable())
	defer { process.close() }
	mut environment := os.environ()
	environment['VOX2_WASM_SHORT_MEMORY_READ'] = '1'
	process.set_environment(environment)
	process.set_redirect_stdio()
	process.run()
	process.wait()
	output := process.stdout_slurp() + process.stderr_slurp()
	assert process.code != 0 && output.contains('Source VERIFY: read_value requires sizeof(T) <= data.size()'), output
}
