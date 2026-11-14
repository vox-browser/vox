module libjs

import math.big

pub struct ExecutionLimits {
pub:
	// Zero permits unlimited instructions, matching upstream execution.
	max_instructions u64
}

fn (mut vm VM) consume_execution_budget() ! {
	if vm.instruction_budget_active {
		if vm.instruction_budget == 0 { return vm.throw_error(.internal_error, 'LibJS instruction budget exceeded') }
		vm.instruction_budget--
	}
}

fn typeof_value(value Value) string {
	if value.is_function() { return 'function' }
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
	mut source := js_undefined()
	for index in 0 .. instruction.input_count() {
		operand := instruction.input_operand(index)
		value := frame.values[operand.slot(executable, frame.argument_count, false)!]
		if value.is_special_empty_value() {
			return vm.throw_error(.internal_error, 'Bytecode read an uninitialized operand')
		}
		if index == 0 {
			left = value
		} else if index == 1 {
			right = value
		} else {
			source = value
		}
	}
	mut result := js_undefined()
	match instruction.op {
		.new_regexp { result = Value.from_object(create_regexp_object(mut vm, left.as_string().utf16, right.as_string().utf16)!) }
		.new_object { result = Value.from_object(Object.create(vm.realm(), vm.realm().object_prototype)) }
		.new_array { result = Value.from_object(ArrayObject.create(mut vm, vm.realm(), u64(left.number), vm.realm().array_prototype_record())!.object) }
		.define_property {
			mut object := left.as_object()
			object.create_data_property_or_throw(mut vm, right.to_property_key(mut vm)!, source)!
		}
		.new_function, .new_function_with_name {
			inferred := if instruction.op == .new_function_with_name { ?Utf16String(left.to_primitive_string(mut vm)!.utf16) } else { none }
			result = Value.from_object(create_ecmascript_function(mut vm, executable, instruction.identifier, instruction.strict, inferred)!)
		}
		.mov {
			result = left
		}
		.call, .construct {
			mut call_arguments := []Value{cap: instruction.arguments.len}
			for operand in instruction.arguments {
				argument := frame.values[operand.slot(executable, frame.argument_count, false)!]
				if argument.is_special_empty_value() {
					return vm.throw_error(.internal_error,
						'Bytecode read an uninitialized argument')
				}
				call_arguments << argument
			}
			if instruction.op == .construct {
				// Interpreter/SlowPaths.cpp::execute_asm_call, Construct branch.
				object := construct(mut vm, left, call_arguments, none)!
				result = Value.from_object(object)
			} else {
				result = call(mut vm, left, right, call_arguments)!
			}
		}
		.get_property {
			// PropertyAccess.h::get_by_id and SlowPaths.cpp::get_by_value.
			// Nullish bases fail before invoking the key's coercion hooks.
			if left.is_nullish() {
				name := if right.is_string() { right.as_string().str() } else { right.str() }
				return vm.throw_error_type(.type_error, .to_object_null_or_undefined_with_property,
					name, left.str())
			}
			key := right.to_property_key(mut vm)!
			if left.is_string() {
				if own := left.as_string().get_own_property(mut vm, key) {
					result = own
					frame.values[instruction.dst.slot(executable, frame.argument_count, true)!] = result
					return next
				}
			}
			result = Reference.for_value(left, key, none, instruction.strict).get_value(mut vm)!
		}
		.put_property {
			// SlowPaths.cpp::asm_slow_path_put_by_value and PropertyAccess.h's
			// PutKind::Normal: coerce the retained key after evaluating the RHS.
			// Ladybird 74a0613d1d79: ToObject rejects a nullish base before
			// ToPropertyKey can execute user code.
			if left.is_nullish() {
				name := if right.is_string() { right.as_string().str() } else { right.str() }
				if instruction.strict {
					return vm.throw_error_type(.type_error, .reference_nullish_set_property, name,
						left.str())
				}
				return vm.throw_error_type(.type_error, .to_object_null_or_undefined_with_property,
					name, left.str())
			}
			key := right.to_property_key(mut vm)!
			Reference.for_value(left, key, none, instruction.strict).put_value(mut vm, source)!
		}
		.delete_property {
			// ToObject precedes ToPropertyKey for DeleteByValue as well.
			if left.is_nullish() {
				return vm.throw_error_type(.type_error, .to_object_null_or_undefined)
			}
			key := right.to_property_key(mut vm)!
			result =
				Value.from_bool(Reference.for_value(left, key, none, instruction.strict).delete_(mut vm)!)
		}
		.delete_binding {
			// SlowPaths.cpp::asm_slow_path_delete_variable.
			reference := vm.resolve_binding(executable.get_identifier(instruction.identifier),
				instruction.strict, none)!
			result = Value.from_bool(reference.delete_(mut vm)!)
		}
		.get_callee_and_this {
			// SlowPaths.cpp::asm_dynamic_get_callee_and_this_from_environment.
			reference := vm.resolve_binding(executable.get_identifier(instruction.identifier),
				instruction.strict, none)!
			result = reference.get_value(mut vm)!
			mut this_value := js_undefined()
			if reference.is_property_reference() {
				this_value = reference.get_this_value()
			} else if reference.is_environment_reference() {
				if base := reference.base_environment_record().with_base_object() {
					this_value = Value.from_object(base)
				}
			}
			frame.values[instruction.dst.slot(executable, frame.argument_count, true)!] = result
			frame.values[instruction.rhs.slot(executable, frame.argument_count, true)!] = this_value
			return next
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
		.in_op {
			// SlowPaths.cpp::asm_slow_path_in.
			result = in_operator(mut vm, left, right)!
		}
		.instance_of {
			// SlowPaths.cpp::asm_slow_path_instance_of.
			result = instance_of(mut vm, left, right)!
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
			result = match instruction.op {
				.bitwise_and { bitwise_and(mut vm, left, right)! }
				.bitwise_or { bitwise_or(mut vm, left, right)! }
				.bitwise_xor { bitwise_xor(mut vm, left, right)! }
				.left_shift { left_shift(mut vm, left, right)! }
				.right_shift { right_shift(mut vm, left, right)! }
				else { unsigned_right_shift(mut vm, left, right)! }
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
		.increment, .decrement {
			// Interpreter/SlowPaths.cpp::{increment,decrement}; the generator
			// preserves the numeric old value separately for postfix updates.
			numeric := left.to_numeric(mut vm)!
			step := if instruction.op == .increment { 1 } else { -1 }
			result = if numeric.is_number() {
				Value.from_f64(numeric.number + step)
			} else {
				Value.from_bigint(BigInt.create(numeric.as_bigint().big_integer +
					big.integer_from_int(step)))
			}
		}
		.bitwise_not {
			result = bitwise_not(mut vm, left)!
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
// place of the generated assembly interpreter. Ordinary calls allocate their
// own checked frames; upstream inline-call frames remain untranslated.
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
	own_budget := vm.run_executable_depth == 0 && vm.external_budget_depth == 0
	previous_budget := vm.instruction_budget
	previous_budget_active := vm.instruction_budget_active
	if own_budget {
		vm.instruction_budget = limits.max_instructions
		vm.instruction_budget_active = limits.max_instructions != 0
	}
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
		if own_budget {
			vm.instruction_budget = previous_budget
			vm.instruction_budget_active = previous_budget_active
		}
	}
	for frame.program_counter < executable.bytecode_length {
		vm.consume_execution_budget()!
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

// Browser events enter a callable directly, including native-only callbacks.
// Give that entire entry (and all its nested functions) one execution budget.
pub fn (mut vm VM) call_with_limits(function Value, this_value Value, arguments []Value, limits ExecutionLimits) !Value {
	outer := vm.run_executable_depth == 0 && vm.external_budget_depth == 0
	previous_budget := vm.instruction_budget
	previous_active := vm.instruction_budget_active
	if outer { vm.instruction_budget = limits.max_instructions; vm.instruction_budget_active = limits.max_instructions != 0 }
	vm.external_budget_depth++
	defer {
		vm.external_budget_depth--
		if outer { vm.instruction_budget = previous_budget; vm.instruction_budget_active = previous_active }
	}
	return call(mut vm, function, this_value, arguments)
}
