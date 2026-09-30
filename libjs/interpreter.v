module libjs

pub struct ExecutionLimits {
pub:
	// Zero permits unlimited instructions, matching upstream execution.
	max_instructions u64
}

fn typeof_value(value Value) string {
	return match value.tag {
		.undefined { 'undefined' }
		.boolean { 'boolean' }
		.int32, .double { 'number' }
		.string { 'string' }
		.symbol { 'symbol' }
		.bigint { 'bigint' }
		else { 'object' }
	}
}

fn (mut vm VM) execute_instruction(instruction Instruction, executable &Executable) !u32 {
	mut frame := vm.running_execution_context()
	mut next := frame.program_counter + 1
	mut left := js_undefined()
	mut right := js_undefined()
	for index in 0 .. instruction.input_count() {
		operand := if index == 0 { instruction.lhs } else { instruction.rhs }
		value := frame.values[operand.slot(executable, frame.argument_count, false)!]
		if value.is_special_empty_value() {
			return vm.throw_error(.internal_error, 'Bytecode read an uninitialized operand')
		}
		if index == 0 {
			left = value
		} else {
			right = value
		}
	}
	mut result := js_undefined()
	match instruction.op {
		.mov {
			result = left
		}
		.add {
			result = add(mut vm, left, right)!
		}
		.sub {
			result = sub(mut vm, left, right)!
		}
		.mul {
			result = mul(mut vm, left, right)!
		}
		.div {
			result = div(mut vm, left, right)!
		}
		.mod_ {
			result = mod_(mut vm, left, right)!
		}
		.exp {
			result = exp(mut vm, left, right)!
		}
		.strict_equals {
			result = Value.from_bool(is_strictly_equal(left, right))
		}
		.strict_inequals {
			result = Value.from_bool(!is_strictly_equal(left, right))
		}
		.loose_equals {
			result = Value.from_bool(is_loosely_equal(mut vm, left, right)!)
		}
		.loose_inequals {
			result = Value.from_bool(!is_loosely_equal(mut vm, left, right)!)
		}
		.less_than, .less_than_equals, .greater_than, .greater_than_equals {
			comparison := compare_primitive_values(mut vm, left, right)!
			result = Value.from_bool(match instruction.op {
				.less_than { comparison == .less }
				.less_than_equals { comparison in [.less, .equal] }
				.greater_than { comparison == .greater }
				else { comparison in [.greater, .equal] }
			})
		}
		.bitwise_and, .bitwise_or, .bitwise_xor, .left_shift, .right_shift, .unsigned_right_shift {
			x := left.to_u32(mut vm)!
			y := right.to_u32(mut vm)!
			bits := match instruction.op {
				.bitwise_and { x & y }
				.bitwise_or { x | y }
				.bitwise_xor { x ^ y }
				.left_shift { x << (y & 31) }
				.right_shift { u32(left.to_i32(mut vm)! >> (y & 31)) }
				else { x >> (y & 31) }
			}

			result = if instruction.op == .unsigned_right_shift {
				Value.from_f64(f64(bits))
			} else {
				Value.from_i32(i32(i64(bits) - if bits >= 0x80000000 { i64(4294967296) } else { 0 }))
			}
		}
		.unary_plus {
			result = left.to_number(mut vm)!
		}
		.unary_minus {
			result = unary_minus(mut vm, left)!
		}
		.to_numeric {
			result = left.to_numeric(mut vm)!
		}
		.bitwise_not {
			result = Value.from_i32(~left.to_i32(mut vm)!)
		}
		.not_op {
			result = Value.from_bool(!left.to_boolean())
		}
		.typeof_op {
			result = Value.from_string(vm.create_string_from_str(typeof_value(left)))
		}
		.get_binding, .typeof_binding {
			reference := vm.resolve_binding(executable.get_identifier(instruction.identifier),
				instruction.strict, none)!
			if instruction.op == .typeof_binding && reference.is_unresolvable() {
				result = Value.from_string(vm.create_string_from_str('undefined'))
			} else {
				value := reference.get_value(mut vm)!
				result = if instruction.op == .typeof_binding {
					Value.from_string(vm.create_string_from_str(typeof_value(value)))
				} else {
					value
				}
			}
		}
		.set_binding, .set_variable, .initialize_binding {
			name := executable.get_identifier(instruction.identifier)
			if instruction.op == .set_variable {
				mut environment := frame.variable_environment or {
					return error('Frame has no variable environment')
				}

				environment.set_mutable_binding(mut vm, name, left, instruction.strict)!
			} else {
				reference := vm.resolve_binding(name, instruction.strict, none)!
				if instruction.op == .initialize_binding {
					reference.initialize_referenced_binding(mut vm, left, .normal)!
				} else {
					reference.put_value(mut vm, left)!
				}
			}
		}
		.create_mutable_binding, .create_immutable_binding {
			mut environment := frame.lexical_environment or {
				return error('Frame has no lexical environment')
			}

			name := executable.get_identifier(instruction.identifier)
			if instruction.op == .create_immutable_binding {
				environment.create_immutable_binding(mut vm, name, true)!
			} else {
				environment.create_mutable_binding(mut vm, name, false)!
			}
		}
		.enter_scope {
			frame.lexical_environment = Environment(DeclarativeEnvironment.create(frame.lexical_environment))
		}
		.leave_scope {
			environment := frame.lexical_environment or {
				return error('Frame has no lexical environment')
			}

			if !environment.is_declarative_environment() || environment.is_function_environment() {
				return error('Cannot leave a non-block environment')
			}
			frame.lexical_environment = environment.outer_environment()
		}
		.resolve_this_binding {
			result = vm.resolve_this_binding()!
		}
		.jump {
			next = instruction.target
		}
		.jump_if_true {
			if left.to_boolean() { next = instruction.target }
		}
		.jump_if_false {
			if !left.to_boolean() { next = instruction.target }
		}
		.jump_if_nullish {
			if left.is_nullish() { next = instruction.target }
		}
		.end {
			vm.do_return(left)
			return executable.bytecode_length
		}
		.throw_op {
			return throw_completion(left)
		}
		.catch_op {
			result = vm.reg(register_exception)
			if result.is_special_empty_value() { return error('Catch without an exception') }
			vm.set_reg(register_exception, js_special_empty_value())
		}
	}

	if instruction.writes_operand() {
		frame.values[instruction.dst.slot(executable, frame.argument_count, true)!] = result
	}
	return next
}

// Interpreter/Interpreter.cpp::VM::run_executable, with a V dispatch loop in
// place of the generated assembly interpreter. No calls/inline frames yet.
pub fn (mut vm VM) run_executable(mut frame ExecutionContext, executable &Executable, entry_point u32, limits ExecutionLimits) !Value {
	executable.validate(frame.argument_count)!
	if entry_point >= executable.bytecode_length { return error('Entry point out of range') }
	required := u64(executable.registers_and_locals_count) + u64(executable.constants.len) +
		frame.argument_count
	if u64(frame.values.len) != required {
		return error('Frame does not match executable value layout')
	}
	if frame.caller_frame != none { return error('Inline calls are not translated yet') }
	if vm.execution_context_stack_.len == 0
		|| voidptr(vm.execution_context_stack_.last()) != voidptr(&frame) {
		return error('Executable frame must be pushed on the VM context stack')
	}
	previous_context := vm.running_execution_context_
	previous_environment := frame.lexical_environment
	vm.running_execution_context_ = &frame
	vm.run_executable_depth++
	frame.executable = executable
	frame.program_counter = entry_point
	vm.set_reg(register_exception, js_special_empty_value())
	vm.set_reg(register_return_value, js_special_empty_value())
	if vm.reg(register_this_value).is_special_empty_value() {
		vm.set_reg(register_this_value, frame.this_value or { js_special_empty_value() })
	}
	defer {
		if vm.run_executable_depth == 1 && !vm.is_executing_module() {
			vm.run_queued_promise_jobs()
			vm.finish_execution_generation()
		}
		frame.lexical_environment = previous_environment
		vm.run_executable_depth--
		vm.running_execution_context_ = previous_context
	}
	mut executed := u64(0)
	for frame.program_counter < executable.bytecode_length {
		if limits.max_instructions != 0 && executed >= limits.max_instructions {
			return vm.throw_error(.internal_error, 'LibJS instruction budget exceeded')
		}
		executed++
		instruction := executable.instructions[frame.program_counter]
		next := vm.execute_instruction(instruction, executable) or {
			if !is_throw_completion(err) { return err }
			if vm.handle_exception(frame.program_counter, thrown_value(err)) == .continue_in_this_executable { continue
			 }
			return err
		}
		frame.program_counter = next
		if instruction.op == .end { return vm.reg(register_return_value) }
	}
	return vm.throw_error(.internal_error, 'Bytecode fell off the end without End')
}
