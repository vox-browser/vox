module libjs

@[heap]
struct InterpreterTestLog {
mut:
	numbers []int
}

fn run_bytecode(mut vm VM, mut frame ExecutionContext, executable &Executable, limits ExecutionLimits) !Value {
	vm.push_execution_context_checked(mut frame)!
	defer { vm.pop_execution_context() }
	return vm.run_executable(mut frame, executable, 0, limits)
}

fn bytecode_frame(mut vm VM, executable &Executable, args []Value) &ExecutionContext {
	mut frame := ExecutionContext.create(executable.registers_and_locals_count,
		executable.constants, u32(args.len))
	frame.realm = vm.realm()
	frame.lexical_environment = Environment(vm.realm().global_environment_record())
	frame.variable_environment = frame.lexical_environment
	for index, value in args {
		frame.values[executable.registers_and_locals_count + u32(executable.constants.len) +
			u32(index)] = value
	}
	return frame
}

fn test_operand_encoding_and_linked_value_layout() {
	executable := &Executable{
		registers_and_locals_count: 8
		local_index_base:           6
		local_variable_names:       [utf16_string('x'), utf16_string('y')]
		constants:                  [Value.from_i32(7)]
	}
	assert Operand.local(1).raw == 0x20000001
	assert Operand.constant(0).raw == 0x40000000
	assert Operand.argument(2).raw == 0x60000002
	assert Operand.local(1).slot(executable, 3, true)! == 7
	assert Operand.constant(0).slot(executable, 3, false)! == 8
	assert Operand.argument(2).slot(executable, 3, true)! == 11
	for operand in [Operand{}, Operand{ raw: 0x80000000 }, Operand.local(2),
		Operand.register(8), Operand.argument(3)] {
		if _ := operand.slot(executable, 3, false) { assert false
		 }
	}
	if _ := Operand.constant(0).slot(executable, 3, true) { assert false
	 }
}

fn test_instruction_loop_uses_locals_constants_arguments_and_restores_vm_state() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	executable := &Executable{
		registers_and_locals_count: 7
		local_index_base:           5
		local_variable_names:       [utf16_string('sum')]
		constants:                  [Value.from_i32(2)]
		instructions:               [
			Instruction{
				op:  .add
				dst: Operand.local(0)
				lhs: Operand.argument(0)
				rhs: Operand.constant(0)
			},
			Instruction{
				op:  .mul
				dst: Operand.register(6)
				lhs: Operand.local(0)
				rhs: Operand.constant(0)
			},
			Instruction{
				op:  .end
				lhs: Operand.register(6)
			},
		]
		bytecode_length:            3
	}
	mut frame := bytecode_frame(mut vm, executable, [Value.from_i32(19)])
	mut checkpoint := &InterpreterTestLog{}
	vm.enqueue_promise_job(fn [mut checkpoint] () !Value {
		checkpoint.numbers << 1
		return js_undefined()
	}, none)
	assert run_bytecode(mut vm, mut frame, executable, ExecutionLimits{})!.number == 42
	assert vm.running_execution_context() == base
	assert vm.run_executable_depth() == 0
	assert vm.execution_generation() == 1
	assert checkpoint.numbers == [1]
}

fn test_instruction_throw_dispatches_to_catch_and_uncaught_throw_stays_a_value() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	executable := &Executable{
		registers_and_locals_count: 6
		constants:                  [Value.from_i32(42)]
		instructions:               [
			Instruction{
				op:  .throw_op
				lhs: Operand.constant(0)
			},
			Instruction{
				op:  .catch_op
				dst: Operand.register(5)
			},
			Instruction{
				op:  .end
				lhs: Operand.register(5)
			},
		]
		bytecode_length:            3
		exception_handlers:         [
			ExceptionHandlers{
				start_offset:      0
				end_offset:        1
				handler_offset:    1
				catches_exception: true
			},
		]
	}
	mut frame := bytecode_frame(mut vm, executable, [])
	assert run_bytecode(mut vm, mut frame, executable, ExecutionLimits{})!.as_i32() == 42
	assert frame.values[register_exception].is_special_empty_value()
	mut uncaught := &Executable{
		registers_and_locals_count: 5
		constants:                  [Value.from_i32(17)]
		instructions:               [
			Instruction{
				op:  .throw_op
				lhs: Operand.constant(0)
			},
		]
		bytecode_length:            1
	}
	mut uncaught_frame := bytecode_frame(mut vm, uncaught, [])
	if _ := run_bytecode(mut vm, mut uncaught_frame, uncaught, ExecutionLimits{}) {
		assert false
	} else {
		assert thrown_value(err).as_i32() == 17
	}
	assert vm.running_execution_context() == base
	assert vm.run_executable_depth() == 0
}

fn test_invalid_bytecode_is_rejected_before_binding_writes() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut executable := &Executable{
		registers_and_locals_count: 5
		constants:                  [Value.from_i32(9)]
		identifier_table:           [utf16_string('unexpected')]
		instructions:               [
			Instruction{
				op:         .set_binding
				lhs:        Operand.constant(0)
				identifier: 0
			},
			Instruction{
				op:     .jump
				target: 2
			},
		]
		bytecode_length:            2
	}
	mut frame := bytecode_frame(mut vm, executable, [])
	if _ := run_bytecode(mut vm, mut frame, executable, ExecutionLimits{}) {
		assert false
	} else {
		assert !is_throw_completion(err) && err.msg().contains('Jump target')
	}
	assert !vm.get_global_object().has_own_property(PropertyName.from_utf16(utf16_string('unexpected')))
	assert vm.run_executable_depth() == 0
	assert vm.execution_generation() == 0
	for bad in [
		Instruction{
			op:  .mov
			dst: Operand.constant(0)
			lhs: Operand.constant(0)
		},
		Instruction{
			op:         .get_binding
			dst:        Operand.register(0)
			identifier: 1
		},
		Instruction{
			op:  .end
			lhs: Operand.register(5)
		},
	] {
		executable.instructions[1] = bad
		executable.validate(0) or { continue }
		assert false
	}
}

fn test_instruction_budget_aborts_a_loop_and_restores_block_environment() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	executable := &Executable{
		registers_and_locals_count: 5
		instructions:               [Instruction{ op: .enter_scope },
			Instruction{ op: .jump, target: 1 }]
		bytecode_length:            2
	}
	mut frame := bytecode_frame(mut vm, executable, [])
	original := frame.lexical_environment or { panic('missing environment') }
	if _ := run_bytecode(mut vm, mut frame, executable, ExecutionLimits{ max_instructions: 10 }) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .internal_error
		assert thrown_value(err).as_object().get(mut vm, PropertyName.from_utf16(utf16_string('message')))!.as_string().str().contains('budget')
	}
	assert same_environment(frame.lexical_environment or { panic('missing environment') }, original)
	assert vm.running_execution_context() == base
	assert vm.run_executable_depth() == 0
}
