module libjs

import math.big
import os

pub struct ExecutionLimits {
pub:
	// Zero permits unlimited instructions, matching upstream execution.
	max_instructions u64
}

// Native host algorithms share the caller's budget with bytecode and callbacks.
pub fn (mut vm VM) consume_execution_budget() ! {
	if vm.instruction_budget_active {
		if vm.instruction_budget == 0 {
			// Unwinding an exhausted entry can revisit this guard through catch or
			// finally. Keep the original failure and traceback at its first site.
			if failure := vm.instruction_budget_error { return failure }
			failure := vm.throw_error(.internal_error, 'LibJS instruction budget exceeded')
			vm.instruction_budget_error = failure
			return failure
		}
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

// Borrow the executable-owned instruction. A value parameter passed on to
// reference-taking slow paths makes V heap-copy it on every dispatched step.
fn (mut vm VM) execute_instruction(instruction &Instruction, executable &Executable) !u32 {
	mut frame := vm.current_context()
	mut next := frame.program_counter + 1
	mut left := js_undefined()
	mut right := js_undefined()
	mut source := js_undefined()
	for index in 0 .. instruction.dispatch_input_count() {
		operand := instruction.input_operand(index)
		value := if checked_interpreter_operands {
			frame.values[operand.slot(executable, frame.argument_count, false)!]
		} else {
			// run_executable() checked frame.values.len against the layout.
			unsafe { (&Value(frame.values.data))[operand.validated_slot(executable)] }
		}
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
	// V emits this match as an if-chain in source order; the most frequent
	// operations that the dispatch loop does not handle inline come first.
	match instruction.op {
		.call, .construct, .super_construct {
			result = vm.execute_call_instruction(instruction, executable, left, right)!
		}
		.get_property {
			result = vm.execute_property_read_at(left, right, instruction.strict,
				executable.property_hint(frame.program_counter))!
		}
		.get_binding, .typeof_binding {
			result = vm.execute_binding_read(instruction, executable)!
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
			vm.execute_property_write(instruction, executable, left, right, source)!
		}
		.get_callee_and_this {
			value, this_value := vm.execute_callee_read(instruction, executable)!
			if checked_interpreter_operands {
				frame.values[instruction.dst.slot(executable, frame.argument_count, true)!] = value
				frame.values[instruction.rhs.slot(executable, frame.argument_count, true)!] = this_value
			} else {
				unsafe {
					mut values := &Value(frame.values.data)
					values[instruction.dst.validated_slot(executable)] = value
					values[instruction.rhs.validated_slot(executable)] = this_value
				}
			}
			return next
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
		.strict_equals {
			result = Value.from_bool(is_strictly_equal(left, right))
		}
		.strict_inequals {
			result = Value.from_bool(!is_strictly_equal(left, right))
		}
		.resolve_this_binding {
			result = vm.resolve_this_binding()!
		}
		.end {
			vm.do_return(left)
			return executable.bytecode_length
		}
		.new_object {
			mut object := Object.create(vm.realm(), vm.realm().object_prototype)
			object.reserve_properties(instruction.identifier)
			result = Value.from_object(object)
		}
		.define_property {
			mut object := left.as_object()
			define_literal_property(mut vm, mut object, right.to_property_key(mut vm)!, source, instruction.annex_b)!
		}
		.new_array {
			mut array := ArrayObject.create(mut vm, vm.realm(), u64(left.number), vm.realm().array_prototype_record())!
			// An array literal defines one element per entry after this instruction.
			if left.number >= 0 && left.number <= f64(literal_property_reservation_limit) {
				array.object.reserve_properties(u32(left.number))
			}
			result = Value.from_object(array.object)
		}
		.set_binding, .set_variable, .initialize_binding {
			name := executable.get_identifier(instruction.identifier)
			if instruction.op == .set_variable {
				mut environment := frame.variable_environment or {
					return error('Frame has no variable environment')
				}
				if instruction.annex_b && environment.is_global_environment() {
					global := unsafe { &GlobalEnvironment(environment_identity(environment)) }
					if global.has_lexical_declaration(name) || !global.can_declare_global_function(name) {
						return next
					}
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
		.not_op {
			result = Value.from_bool(!left.to_boolean())
		}
		.typeof_op {
			result = Value.from_string(vm.create_string_from_str(typeof_value(left)))
		}
		.enter_scope {
			frame.lexical_environment = Environment(DeclarativeEnvironment.create(frame.lexical_environment))
			frame.lexical_scope_depth++
		}
		.leave_scope {
			frame.leave_lexical_scope()!
		}
		.new_function, .new_function_with_name {
			inferred := if instruction.op == .new_function_with_name { ?Utf16String(make_function_name(left.to_property_key(mut vm)!, none)) } else { none }
			result = Value.from_object(create_ecmascript_function(mut vm, executable, instruction.identifier, instruction.strict, inferred, true)!)
		}
		.mov {
			result = left
		}
		.nop {}
		.generator_start {
			mut execution := frame.generator_execution or { return error('Generator start requires a generator frame') }
			function := execution.function or { return error('Generator start requires its creating function') }
			prototype := function.object.get(mut vm, PropertyName.from_str('prototype'))!
			mut object := Object.create(execution.realm, if prototype.is_object() { ?&Object(prototype.as_object()) } else { execution.realm.generator_prototype })
			object.generator_execution = execution
			// The saved frame owns the function while suspended. A completed
			// generator must not retain the creating function's lexical scope.
			execution.function = none
			execution.suspend(mut frame, .suspended_start)
			vm.set_reg(register_return_value, Value.from_object(object))
			return executable.bytecode_length
		}
		.yield_value, .yield_iterator_result {
			mut execution := frame.generator_execution or { return error('Yield requires a generator frame') }
			frame.yield_value_is_iterator_result = instruction.op == .yield_iterator_result
			execution.suspend(mut frame, .suspended_yield)
			vm.set_reg(register_return_value, left)
			return executable.bytecode_length
		}
		.get_generator_resume_kind { result = Value.from_i32(i32(frame.generator_resume_kind)) }
		.get_generator_resume_value { result = frame.generator_resume_value }
		.generator_delegate_step { result = generator_delegate_step(mut vm, left, right, source)! }
		.import_call { result = perform_import_call(mut vm, left, right)! }
		.get_template_object { result = vm.get_template_object(executable, instruction)! }
		.await_value {
			mut execution := frame.async_execution or { return error('Await requires an async function execution context') }
			execution.suspend(mut vm, mut frame, left)!
			return executable.bytecode_length
		}
		.resume_async {
			result = frame.async_resume_value
			rejected := frame.async_resume_rejected
			frame.async_resume_value = js_undefined()
			frame.async_resume_rejected = false
			if rejected { return throw_completion(result) }
		}
		.copy_data_properties {
			if !right.is_nullish() {
				mut target := left.as_object()
				object := right.to_object_with_prototypes(mut vm, realm_primitive_prototypes())!
				copy_enumerable_own_properties(mut vm, mut target, object, [])!
			}
		}
		.to_string { result = Value.from_string(left.to_primitive_string(mut vm)!) }
		.get_new_target { result = vm.get_new_target() }
		.get_super_constructor { result = get_super_constructor(mut vm)! }
		.resolve_super_reference { result = resolve_super_reference(mut vm, left)! }
		.get_super_this { result = super_property_base(mut vm, left)!.receiver }
		.get_super_property, .put_super_property, .delete_super_property {
			base := super_property_base(mut vm, left)!
			if instruction.op == .delete_super_property {
				// Delete rejects a Super Reference before ToObject/ToPropertyKey.
				return vm.throw_error_type(.reference_error, .unsupported_delete_super_property)
			}
			if base.base.is_nullish() {
				return vm.throw_error_type(.type_error, .to_object_null_or_undefined)
			}
			key := right.to_property_key(mut vm)!
			reference := Reference.for_value(base.base, key, base.receiver, instruction.strict)
			if instruction.op == .put_super_property { reference.put_value(mut vm, source)! }
			else { result = reference.get_value(mut vm)! }
		}
		.record_empty_class_field { record_class_field(mut vm, left, right.to_property_key(mut vm)!, source, instruction.identifier == 1, instruction.strict)! }
		.record_class_static_block { record_class_static_block(mut vm, left, right)! }
		.enter_class_private_environment { enter_class_private_environment(mut vm, executable, instruction)! }
		.record_private_class_method { record_private_class_method(mut vm, left, right, source, instruction.identifier, instruction.target == 1)! }
		.get_private { result = make_private_reference(vm, left, resolve_class_private_name(mut vm, right)!.description).get_value(mut vm)! }
		.put_private { make_private_reference(vm, left, resolve_class_private_name(mut vm, right)!.description).put_value(mut vm, source)! }
		.has_private {
			if !left.is_object() { return vm.throw_error(.type_error, 'Private in requires an object') }
			result = Value.from_bool(left.as_object().private_element_find(resolve_class_private_name(mut vm, right)!) != none)
		}
		.new_class_field_initializer { result = Value.from_object(create_class_field_initializer(mut vm, executable, instruction.identifier, left.to_property_key(mut vm)!)!) }
		.initialize_empty_static_fields { initialize_empty_static_fields(mut vm, left)! }
		.get_argument { result = frame.argument(instruction.identifier) }
		.get_rest_arguments {
			mut values := []Value{}
			for index := instruction.identifier; index < frame.passed_argument_count; index++ {
				vm.consume_execution_budget()!
				values << frame.argument(index)
			}
			result = Value.from_object(ArrayObject.create_from(mut vm, vm.realm(), values, vm.realm().array_prototype_record())!.object)
		}
		.enter_function_body { enter_function_body(mut vm, mut frame, executable)! }
		.sync_iterator_step_value, .sync_iterator_elide, .sync_iterator_to_array {
			if !left.is_object() { return vm.throw_error(.internal_error, 'Invalid iterator record') }
			mut record := left.as_object().iterator_record or { return vm.throw_error(.internal_error, 'Invalid iterator record') }
			if instruction.op == .sync_iterator_to_array {
				mut values := []Value{}
				for !record.done {
					vm.consume_execution_budget()!
					step := iterator_step_value(mut vm, mut record)!
					if !step.done { values << step.value }
				}
				result = Value.from_object(ArrayObject.create_from(mut vm, vm.realm(), values, vm.realm().array_prototype_record())!.object)
			} else if !record.done {
				if instruction.op == .sync_iterator_elide { iterator_step(mut vm, mut record)! }
				else {
					step := iterator_step_value(mut vm, mut record)!
					if !step.done { result = step.value }
				}
			}
		}
		.get_sync_iterator {
			mut wrapper := Object.create(vm.realm(), none)
			wrapper.iterator_record = get_iterator_sync_value(mut vm, left)!
			result = Value.from_object(wrapper)
		}
		.sync_iterator_next, .close_sync_iterator, .close_sync_iterator_throw {
			if !left.is_object() { return vm.throw_error(.internal_error, 'Invalid iterator record') }
			mut record := left.as_object().iterator_record or { return vm.throw_error(.internal_error, 'Invalid iterator record') }
			if instruction.op == .sync_iterator_next {
				step := iterator_step_value(mut vm, mut record)!
				if step.done { return instruction.target }
				result = step.value
			} else if !record.done {
				record.done = true
				completion := if instruction.op == .close_sync_iterator_throw { Completion{type_:.throw_,value:right} } else { normal_completion(js_undefined()) }
				closed := iterator_close(mut vm, record, completion)
				if instruction.op == .close_sync_iterator && closed.is_error() { return closed.release_error() }
			}
		}
		.get_object_property_iterator { result = Value.from_object(create_property_name_iterator(mut vm, left)!) }
		.property_name_iterator_next {
			if !left.is_object() { return vm.throw_error(.internal_error, 'Invalid property-name iterator') }
			mut iterator := left.as_object().property_name_iterator or { return vm.throw_error(.internal_error, 'Invalid property-name iterator') }
			step := iterator.next(mut vm)!
			if step.done { return instruction.target }
			result = step.value
		}
		.require_object_coercible {
			if left.is_nullish() { return vm.throw_error_type(.type_error,.to_object_null_or_undefined) }
		}
		.to_property_key { result = property_key_value(mut vm, left)! }
		.copy_object_excluding_keys {
			mut excluded := []PropertyName{cap:instruction.arguments.len}
			for operand in instruction.arguments {
				key := frame.values[operand.slot(executable,frame.argument_count,false)!]
				if key.is_special_empty_value() { return vm.throw_error(.internal_error,'Uninitialized object rest key') }
				excluded << key.to_property_key(mut vm)!
			}
			result=Value.from_object(copy_object_excluding_keys(mut vm,left,excluded)!)
		}
		.new_regexp {
			pattern := left.as_string().utf16
			flags := right.as_string().utf16
			if template := executable.regexp_literal_engine(instruction.lhs.index()) {
				engine := &RegexEngine{ ...template, scratch: RegexVmScratch.new() }
				result = Value.from_object(create_regexp_object_with_engine(mut vm, pattern, flags,
					engine))
			} else {
				result = Value.from_object(create_regexp_object(mut vm, pattern, flags)!)
			}
		}
		.set_object_literal_prototype {
			if right.is_object() || right.is_null() {
				mut object := left.as_object()
				prototype := if right.is_object() { ?&Object(right.as_object()) } else { none }
				if !object.internal_set_prototype_of(prototype) { return vm.throw_error_type(.type_error, .object_set_prototype_of_returned_false) }
			}
		}
		.new_class_method {
			prefix := if right.number == 1 { ?string('get') } else if right.number == 2 { ?string('set') } else { none }
			result = Value.from_object(create_ecmascript_function(mut vm, executable, instruction.identifier, false, make_function_name(left.to_property_key(mut vm)!, prefix), false)!)
		}
		.new_class { result = create_base_class(mut vm, executable, instruction.identifier, left, right, source, instruction.strict)! }
		.define_class_method { define_class_method(mut vm, left, right, source, instruction.identifier, instruction.strict)! }
		.super_construct_with_array {
			arguments := create_argument_list_from_array_like(mut vm, right)!
			result = construct_super(mut vm, left, arguments)!
		}
		.call_with_array, .construct_with_array {
			arguments := create_argument_list_from_array_like(mut vm, source)!
			result = if instruction.op == .construct_with_array {
				Value.from_object(construct(mut vm, left, arguments, none)!)
			} else { call(mut vm, left, right, arguments)! }
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
		.add, .sub, .mul, .div, .mod_, .exp {
			// AsmInterpreter's Number fast paths: no operand needs coercion.
			result = if left.is_number() && right.is_number() {
				Value.from_f64(number_binary_operation(left.number, right.number, instruction.op))
			} else if instruction.op == .add {
				add(mut vm, left, right)!
			} else {
				numeric_binary_operation(mut vm, left, right, instruction.op)!
			}
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
			comparison := if left.is_number() && right.is_number() {
				compare_numbers(left.number, right.number)
			} else {
				compare_primitive_values(mut vm, left, right)!
			}
			result = Value.from_bool(match instruction.op {
				.less_than { comparison == .less }
				.less_than_equals { comparison in [.less, .equal] }
				.greater_than { comparison == .greater }
				else { comparison in [.greater, .equal] }
			})
		}
		.bitwise_and, .bitwise_or, .bitwise_xor, .left_shift, .right_shift, .unsigned_right_shift {
			result = if left.is_number() && right.is_number() {
				bits := number_bitwise_operation(number_to_i32(left.number),
					number_to_i32(right.number), instruction.op)
				if instruction.op == .unsigned_right_shift {
					Value.from_f64(f64(u32(bits)))
				} else {
					Value.from_i32(bits)
				}
			} else { match instruction.op {
				.bitwise_and { bitwise_and(mut vm, left, right)! }
				.bitwise_or { bitwise_or(mut vm, left, right)! }
				.bitwise_xor { bitwise_xor(mut vm, left, right)! }
				.left_shift { left_shift(mut vm, left, right)! }
				.right_shift { right_shift(mut vm, left, right)! }
				else { unsigned_right_shift(mut vm, left, right)! }
			} }
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
			numeric := if left.is_number() { left } else { left.to_numeric(mut vm)! }
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
		.get_binding_reference {
			reference := vm.resolve_binding(executable.get_identifier(instruction.identifier),
				instruction.strict, none)!
			mut holder := Object.create(vm.realm(), none)
			holder.class_name = '#BindingReference'
			holder.binding_reference = &Reference{ ...reference }
			result = Value.from_object(holder)
		}
		.put_binding_reference {
			if !left.is_object() { return vm.throw_error(.internal_error, 'Invalid binding reference') }
			reference := left.as_object().binding_reference or {
				return vm.throw_error(.internal_error, 'Missing binding reference')
			}
			reference.put_value(mut vm, right)!
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
		.get_import_meta {
			if vm.get_active_script_or_module().kind!=.module { return vm.throw_error(.internal_error,'ImportMeta requires an active module') }
			result=Value.from_object(vm.get_import_meta())
		}
		.jump {
			next = instruction.target
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

	if instruction.dispatch_writes_operand() {
		if checked_interpreter_operands {
			frame.values[instruction.dst.slot(executable, frame.argument_count, true)!] = result
		} else {
			unsafe {
				mut values := &Value(frame.values.data)
				values[instruction.dst.validated_slot(executable)] = result
			}
		}
	}
	return next
}

// The dispatch loop's handler for each opcode, from one table lookup: V lowers
// a match on the opcode itself to a long compare chain.
enum InlineHandler as u8 {
	slow
	mov
	jump
	branch
	number_binary
	number_bitwise
	increment
	to_numeric
	nop
	property_read
	call
	binding_read
	property_write
	callee_read
}

const inline_handlers_by_opcode = compute_inline_handlers()

fn compute_inline_handlers() []u8 {
	mut handlers := []u8{len: int(OpCode.nop) + 1}
	for index in 0 .. handlers.len {
		op := unsafe { OpCode(index) }
		handlers[index] = u8(match op {
			.mov { InlineHandler.mov }
			.jump { InlineHandler.jump }
			.jump_if_false, .jump_if_true { InlineHandler.branch }
			.add, .sub, .mul, .less_than, .less_than_equals, .greater_than, .greater_than_equals,
			.strict_equals, .strict_inequals { InlineHandler.number_binary }
			.bitwise_and, .bitwise_or, .bitwise_xor, .left_shift, .right_shift,
			.unsigned_right_shift { InlineHandler.number_bitwise }
			.increment, .decrement { InlineHandler.increment }
			.to_numeric { InlineHandler.to_numeric }
			.nop { InlineHandler.nop }
			.get_property { InlineHandler.property_read }
			.call { InlineHandler.call }
			.get_binding { InlineHandler.binding_read }
			.put_property { InlineHandler.property_write }
			.get_callee_and_this { InlineHandler.callee_read }
			else { InlineHandler.slow }
		})
	}
	return handlers
}

// put_property after the nullish-base check: ToPropertyKey, then the hinted
// store or Reference/[[Set]].
fn (mut vm VM) execute_property_write(instruction &Instruction, executable &Executable, left Value, right Value, source Value) ! {
	key := right.to_property_key(mut vm)!
	hint := executable.property_hint(vm.current_context().program_counter)
	if !left.is_object() || unsafe { *hint } == property_hint_adding
		|| !left.as_object().hinted_set(key, source, hint) {
		Reference.for_value(left, key, none, instruction.strict).put_value(mut vm, source)!
	}
}

// Same-binary control: check every operand slot again while dispatching.
const checked_interpreter_operands = os.getenv('VOX_LIBJS_CHECKED_OPERANDS') != ''

// Same-binary control `VOX_LIBJS_SLOW_DISPATCH`: send every instruction
// through execute_instruction(). Checked operands always take that path.
const inline_interpreter_dispatch = os.getenv('VOX_LIBJS_SLOW_DISPATCH') == ''
	&& !checked_interpreter_operands

// Interpreter/Interpreter.cpp::VM::run_executable, with a V dispatch loop in
// place of the generated assembly interpreter. Ordinary calls allocate their
// own checked frames; upstream inline-call frames remain untranslated.
pub fn (mut vm VM) run_executable(mut frame ExecutionContext, executable &Executable, entry_point u32, limits ExecutionLimits) !Value {
	vm.validate_execution(executable, frame.argument_count)!
	$if test { vm.profile_executable_for_testing(executable, &frame) }
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
	previous_private_environment := frame.private_environment
	previous_scope_depth := frame.lexical_scope_depth
	if !frame.async_resuming && !frame.generator_resuming { frame.lexical_scope_depth=0 }
	own_budget := vm.run_executable_depth == 0 && vm.external_budget_depth == 0
	previous_budget := vm.instruction_budget
	previous_budget_active := vm.instruction_budget_active
	previous_budget_error := vm.instruction_budget_error
	if own_budget {
		vm.instruction_budget_error = none
		vm.instruction_budget = limits.max_instructions
		vm.instruction_budget_active = limits.max_instructions != 0
	}
	vm.running_execution_context_ = &frame
	vm.run_executable_depth++
	frame.executable = executable
	frame.program_counter = entry_point
	// `required` covers the reserved registers of every compiled body; other
	// layouts keep the checked register accessors.
	if frame.values.len >= int(reserved_register_count) {
		unsafe {
			mut registers := &Value(frame.values.data)
			registers[register_exception] = js_special_empty_value()
			registers[register_return_value] = js_special_empty_value()
			if registers[register_this_value].is_special_empty_value() {
				registers[register_this_value] = frame.this_value or { js_special_empty_value() }
			}
		}
	} else {
		vm.set_reg(register_exception, js_special_empty_value())
		vm.set_reg(register_return_value, js_special_empty_value())
		if vm.reg(register_this_value).is_special_empty_value() {
			vm.set_reg(register_this_value, frame.this_value or { js_special_empty_value() })
		}
	}
	defer {
		if vm.run_executable_depth == 1 && vm.external_budget_depth == 0 && !vm.is_executing_module() {
			vm.run_queued_promise_jobs()
			vm.finish_execution_generation()
		}
		frame.lexical_environment = previous_environment
		frame.private_environment = previous_private_environment
		frame.lexical_scope_depth=previous_scope_depth
		vm.run_executable_depth--
		vm.running_execution_context_ = previous_context
		if own_budget {
			vm.instruction_budget_error = previous_budget_error
			vm.instruction_budget = previous_budget
			vm.instruction_budget_active = previous_budget_active
		}
	}
	if mut tier := vm.native_tier {
		if entry := vm.native_entry_for_execution(mut tier, executable) {
			mut fast_steps := &u64(unsafe { nil })
			if tier.diagnostics {
				tier.activity.entries++
				fast_steps = &tier.activity.fast_steps
			}
			return vm.invoke_native_entry(entry, executable, fast_steps)
		}
	}
	// Operand.validated_slot()'s per-type bases, indexed by the operand tag.
	operand_bases := [u32(0), executable.local_index_base, executable.registers_and_locals_count,
		executable.registers_and_locals_count + u32(executable.constants.len)]!
	bases := unsafe { &u32(&operand_bases[0]) }
	if executable.bytecode_length > u32(executable.instructions.len) {
		return error('Bytecode length exceeds the instruction stream')
	}
	instructions := unsafe { &Instruction(executable.instructions.data) }
	for frame.program_counter < executable.bytecode_length {
		// consume_execution_budget(), with its call only for active budgets.
		if vm.instruction_budget_active { vm.consume_execution_budget()! }
		// The loop condition and the check above bound the index.
		instruction := unsafe { &instructions[frame.program_counter] }
		// AsmInterpreter handlers for operations that cannot throw or call out.
		// execute_instruction() still handles every other case, including an
		// uninitialized operand, so its prologue and long opcode chain are
		// skipped only for these steps.
		handler := if inline_interpreter_dispatch {
			unsafe { InlineHandler(inline_handlers_by_opcode[int(instruction.op)]) }
		} else {
			InlineHandler.slow
		}
		if handler != .slow {
			values := unsafe { &Value(frame.values.data) }
			match handler {
				.mov {
					value := unsafe { values[bases[instruction.lhs.raw >> 29] + (instruction.lhs.raw & 0x1fffffff)] }
					if !value.is_special_empty_value() {
						unsafe {
							values[bases[instruction.dst.raw >> 29] + (instruction.dst.raw & 0x1fffffff)] = value
						}
						frame.program_counter++
						continue
					}
				}
				.jump {
					frame.program_counter = instruction.target
					continue
				}
				.branch {
					value := unsafe { values[bases[instruction.lhs.raw >> 29] + (instruction.lhs.raw & 0x1fffffff)] }
					if value.tag == .boolean {
						if (value.number != 0.0) == (instruction.op == .jump_if_true) {
							frame.program_counter = instruction.target
						} else {
							frame.program_counter++
						}
						continue
					}
				}
				.number_binary {
					left := unsafe { values[bases[instruction.lhs.raw >> 29] + (instruction.lhs.raw & 0x1fffffff)] }
					right := unsafe { values[bases[instruction.rhs.raw >> 29] + (instruction.rhs.raw & 0x1fffffff)] }
					if left.is_number() && right.is_number() {
						x, y := left.number, right.number
						result := match instruction.op {
							.add { Value.from_f64(x + y) }
							.sub { Value.from_f64(x - y) }
							.mul { Value.from_f64(x * y) }
							.less_than { Value.from_bool(x < y) }
							.less_than_equals { Value.from_bool(x <= y) }
							.greater_than { Value.from_bool(x > y) }
							.greater_than_equals { Value.from_bool(x >= y) }
							.strict_equals { Value.from_bool(x == y) }
							else { Value.from_bool(x != y) }
						}
						unsafe {
							values[bases[instruction.dst.raw >> 29] + (instruction.dst.raw & 0x1fffffff)] = result
						}
						frame.program_counter++
						continue
					}
				}
				.number_bitwise {
					left := unsafe { values[bases[instruction.lhs.raw >> 29] + (instruction.lhs.raw & 0x1fffffff)] }
					right := unsafe { values[bases[instruction.rhs.raw >> 29] + (instruction.rhs.raw & 0x1fffffff)] }
					if left.is_number() && right.is_number() {
						bits := number_bitwise_operation(number_to_i32(left.number),
							number_to_i32(right.number), instruction.op)
						result := if instruction.op == .unsigned_right_shift {
							Value.from_f64(f64(u32(bits)))
						} else {
							Value.from_i32(bits)
						}
						unsafe {
							values[bases[instruction.dst.raw >> 29] + (instruction.dst.raw & 0x1fffffff)] = result
						}
						frame.program_counter++
						continue
					}
				}
				.increment {
					value := unsafe { values[bases[instruction.lhs.raw >> 29] + (instruction.lhs.raw & 0x1fffffff)] }
					if value.is_number() {
						step := if instruction.op == .increment { 1.0 } else { -1.0 }
						unsafe {
							values[bases[instruction.dst.raw >> 29] + (instruction.dst.raw & 0x1fffffff)] = Value.from_f64(value.number + step)
						}
						frame.program_counter++
						continue
					}
				}
				.to_numeric {
					value := unsafe { values[bases[instruction.lhs.raw >> 29] + (instruction.lhs.raw & 0x1fffffff)] }
					if value.is_number() {
						unsafe {
							values[bases[instruction.dst.raw >> 29] + (instruction.dst.raw & 0x1fffffff)] = value
						}
						frame.program_counter++
						continue
					}
				}
				.nop {
					frame.program_counter++
					continue
				}
				.call {
					left := unsafe { values[bases[instruction.lhs.raw >> 29] + (instruction.lhs.raw & 0x1fffffff)] }
					right := unsafe { values[bases[instruction.rhs.raw >> 29] + (instruction.rhs.raw & 0x1fffffff)] }
					if !left.is_special_empty_value() && !right.is_special_empty_value() {
						result := vm.execute_call_instruction(instruction, executable, left, right) or {
							if !is_throw_completion(err) { return err }
							if vm.handle_exception(frame.program_counter, thrown_value(err)) == .continue_in_this_executable {
								continue
							}
							return err
						}
						current := unsafe { &Value(frame.values.data) }
						unsafe {
							current[bases[instruction.dst.raw >> 29] + (instruction.dst.raw & 0x1fffffff)] = result
						}
						frame.program_counter++
						continue
					}
				}
				.binding_read {
					result := vm.execute_binding_read(instruction, executable) or {
						if !is_throw_completion(err) { return err }
						if vm.handle_exception(frame.program_counter, thrown_value(err)) == .continue_in_this_executable {
							continue
						}
						return err
					}
					current := unsafe { &Value(frame.values.data) }
					unsafe {
						current[bases[instruction.dst.raw >> 29] + (instruction.dst.raw & 0x1fffffff)] = result
					}
					frame.program_counter++
					continue
				}
				.callee_read {
					callee, receiver := vm.execute_callee_read(instruction, executable) or {
						if !is_throw_completion(err) { return err }
						if vm.handle_exception(frame.program_counter, thrown_value(err)) == .continue_in_this_executable {
							continue
						}
						return err
					}
					current := unsafe { &Value(frame.values.data) }
					unsafe {
						current[bases[instruction.dst.raw >> 29] + (instruction.dst.raw & 0x1fffffff)] = callee
						current[bases[instruction.rhs.raw >> 29] + (instruction.rhs.raw & 0x1fffffff)] = receiver
					}
					frame.program_counter++
					continue
				}
				.property_write {
					left := unsafe { values[bases[instruction.lhs.raw >> 29] + (instruction.lhs.raw & 0x1fffffff)] }
					right := unsafe { values[bases[instruction.rhs.raw >> 29] + (instruction.rhs.raw & 0x1fffffff)] }
					source := unsafe { values[bases[instruction.src.raw >> 29] + (instruction.src.raw & 0x1fffffff)] }
					// Nullish bases, uninitialized operands and non-object bases keep
					// execute_instruction()'s messages and coercions.
					if left.is_object() && !right.is_special_empty_value() && !source.is_special_empty_value() {
						vm.execute_property_write(instruction, executable, left, right, source) or {
							if !is_throw_completion(err) { return err }
							if vm.handle_exception(frame.program_counter, thrown_value(err)) == .continue_in_this_executable {
								continue
							}
							return err
						}
						frame.program_counter++
						continue
					}
				}
				.property_read {
					left := unsafe { values[bases[instruction.lhs.raw >> 29] + (instruction.lhs.raw & 0x1fffffff)] }
					right := unsafe { values[bases[instruction.rhs.raw >> 29] + (instruction.rhs.raw & 0x1fffffff)] }
					if left.is_object() && !right.is_special_empty_value() {
						result := vm.execute_property_read_at(left, right, instruction.strict,
							executable.property_hint(frame.program_counter)) or {
							if !is_throw_completion(err) { return err }
							if vm.handle_exception(frame.program_counter, thrown_value(err)) == .continue_in_this_executable {
								continue
							}
							return err
						}
						// A getter may have replaced this frame's value storage.
						current := unsafe { &Value(frame.values.data) }
						unsafe {
							current[bases[instruction.dst.raw >> 29] + (instruction.dst.raw & 0x1fffffff)] = result
						}
						frame.program_counter++
						continue
					}
				}
				else {}
			}
		}
		next := vm.execute_instruction(instruction, executable) or {
			if !is_throw_completion(err) { return err }
			if vm.handle_exception(frame.program_counter, thrown_value(err)) == .continue_in_this_executable { continue
			 }
			return err
		}
		frame.program_counter = next
		if instruction.op in [.end, .await_value, .generator_start, .yield_value, .yield_iterator_result] { return vm.reg(register_return_value) }
	}
	return vm.throw_error(.internal_error, 'Bytecode fell off the end without End')
}

// Browser events enter a callable directly, including native-only callbacks.
// Give that entire entry (and all its nested functions) one execution budget.
pub fn (mut vm VM) call_with_limits(function Value, this_value Value, arguments []Value, limits ExecutionLimits) !Value {
	outer := vm.run_executable_depth == 0 && vm.external_budget_depth == 0
	previous_budget := vm.instruction_budget
	previous_active := vm.instruction_budget_active
	previous_error := vm.instruction_budget_error
	if outer { vm.instruction_budget = limits.max_instructions; vm.instruction_budget_active = limits.max_instructions != 0; vm.instruction_budget_error = none }
	vm.external_budget_depth++
	defer {
		if outer && !vm.is_executing_module() { vm.run_queued_promise_jobs() }
		vm.external_budget_depth--
		if outer { vm.instruction_budget = previous_budget; vm.instruction_budget_active = previous_active; vm.instruction_budget_error = previous_error }
	}
	return call(mut vm, function, this_value, arguments)
}

// Run one embedding-scheduled Promise job with a budget shared by its native
// algorithms and nested author functions. The host owns microtask ordering.
pub fn (mut vm VM) run_promise_job_with_limits(job PromiseJob, limits ExecutionLimits) !Value {
	outer := vm.run_executable_depth == 0 && vm.external_budget_depth == 0
	previous_budget, previous_active := vm.instruction_budget, vm.instruction_budget_active
	previous_error := vm.instruction_budget_error
	if outer { vm.instruction_budget = limits.max_instructions; vm.instruction_budget_active = limits.max_instructions != 0; vm.instruction_budget_error = none }
	vm.external_budget_depth++
	defer {
		vm.external_budget_depth--
		if outer { vm.instruction_budget = previous_budget; vm.instruction_budget_active = previous_active; vm.instruction_budget_error = previous_error }
	}
	vm.consume_execution_budget()!
	return job()
}
