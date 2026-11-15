module libjs

// Selected handlers from Interpreter/interpreter.flap. Environment operations
// currently use the frame's lexical environment rather than an environment cell
// operand. Branch targets and source maps are instruction indices in this port.
pub enum OpCode {
	mov
	add
	sub
	mul
	div
	mod_
	exp
	strict_equals
	strict_inequals
	loose_equals
	loose_inequals
	less_than
	less_than_equals
	greater_than
	greater_than_equals
	in_op
	instance_of
	bitwise_and
	bitwise_or
	bitwise_xor
	left_shift
	right_shift
	unsigned_right_shift
	unary_plus
	unary_minus
	bitwise_not
	not_op
	typeof_op
	to_numeric
	increment
	decrement
	get_binding
	get_callee_and_this
	get_property
	put_property
	delete_property
	delete_binding
	call
	construct
	new_function
	new_function_with_name
	new_object
	new_array
	new_regexp
	define_property
	set_object_literal_prototype
	require_object_coercible
	to_property_key
	copy_object_excluding_keys
	typeof_binding
	set_binding
	set_variable
	initialize_binding
	create_mutable_binding
	create_immutable_binding
	enter_scope
	leave_scope
	resolve_this_binding
	get_import_meta
	jump
	jump_if_true
	jump_if_false
	jump_if_nullish
	end
	throw_op
	catch_op
	get_object_property_iterator
	property_name_iterator_next
	get_sync_iterator
	sync_iterator_next
	close_sync_iterator
	close_sync_iterator_throw
	sync_iterator_step_value
	sync_iterator_elide
	sync_iterator_to_array
	new_class
	new_class_method
	define_class_method
	get_argument
	get_rest_arguments
	enter_function_body
	get_new_target
	get_super_constructor
	super_construct
	record_empty_class_field
	initialize_empty_static_fields
	to_string
	new_class_field_initializer
	enter_class_private_environment
	record_private_class_method
	get_private
	put_private
	has_private
	copy_data_properties
	super_construct_with_array
}

pub struct Instruction {
pub mut:
	op         OpCode
	dst        Operand
	lhs        Operand
	rhs        Operand
	src        Operand
	identifier u32
	target     u32
	strict     bool
	arguments  []Operand
}

pub struct GlobalBinding {
pub:
	name        Utf16String
	is_lexical  bool
	is_constant bool
}

fn (instruction Instruction) input_count() int {
	return match instruction.op {
		.add, .sub, .mul, .div, .mod_, .exp, .strict_equals, .strict_inequals, .loose_equals,
		.loose_inequals, .less_than, .less_than_equals, .greater_than, .greater_than_equals,
		.bitwise_and, .bitwise_or, .bitwise_xor, .left_shift, .right_shift, .unsigned_right_shift,
		.in_op, .instance_of, .call {
			2
		}
		.get_property, .get_private, .has_private, .delete_property, .new_regexp, .set_object_literal_prototype, .close_sync_iterator_throw, .new_class_method, .copy_data_properties, .super_construct_with_array {
			2
		}
		.put_property, .put_private, .record_private_class_method, .define_property, .define_class_method, .new_class, .record_empty_class_field {
			3
		}
		.mov, .unary_plus, .unary_minus, .bitwise_not, .not_op, .typeof_op, .to_numeric, .to_string,
		.increment, .decrement, .set_binding, .set_variable, .initialize_binding, .jump_if_true,
		.require_object_coercible, .to_property_key, .copy_object_excluding_keys,
		.initialize_empty_static_fields,
		.new_class_field_initializer,
		.get_object_property_iterator, .property_name_iterator_next,
		.get_sync_iterator, .sync_iterator_next, .close_sync_iterator,
		.sync_iterator_step_value, .sync_iterator_elide, .sync_iterator_to_array,
		.jump_if_false, .jump_if_nullish, .end, .throw_op, .construct, .super_construct, .new_array, .new_function_with_name {
			1
		}
		else {
			0
		}
	}
}

fn (instruction Instruction) input_operand(index int) Operand {
	return match index {
		0 { instruction.lhs }
		1 { instruction.rhs }
		else { instruction.src }
	}
}

fn (instruction Instruction) writes_operand() bool {
	return instruction.op !in [.put_property, .define_property, .define_class_method, .set_binding, .set_variable, .initialize_binding,
		.put_private, .record_private_class_method, .enter_class_private_environment,
		.create_mutable_binding, .create_immutable_binding, .enter_scope, .leave_scope, .enter_function_body, .jump,
		.require_object_coercible, .set_object_literal_prototype, .copy_data_properties,
		.record_empty_class_field, .initialize_empty_static_fields,
		.close_sync_iterator, .close_sync_iterator_throw,
		.sync_iterator_elide,
		.jump_if_true, .jump_if_false, .jump_if_nullish, .end, .throw_op]
}

pub fn (executable &Executable) validate(arguments_count u32) ! {
	if executable.instructions.len == 0
		|| executable.bytecode_length != u32(executable.instructions.len) {
		return error('Executable has no valid instruction stream')
	}
	if executable.registers_and_locals_count < reserved_register_count {
		return error('Executable is missing reserved registers')
	}
	if u64(executable.registers_and_locals_count) + u64(executable.constants.len) + arguments_count > 0xffffffff {
		return error('Executable value layout overflows u32')
	}
	if executable.local_variable_names.len > 0
		&& (executable.local_index_base < reserved_register_count
		|| u64(executable.local_index_base) + u64(executable.local_variable_names.len) > executable.registers_and_locals_count) {
		return error('Executable has an invalid local layout')
	}
	for instruction in executable.instructions {
		if instruction.op == .new_class_field_initializer && instruction.identifier >= u32(executable.class_field_initializers.len) {
			return error('Class field initializer index out of range')
		}
		for index in 0 .. instruction.input_count() {
			operand := instruction.input_operand(index)
			operand.slot(executable, arguments_count, false)!
		}
		if instruction.writes_operand() { instruction.dst.slot(executable, arguments_count, true)! }
		if instruction.op == .get_callee_and_this {
			instruction.rhs.slot(executable, arguments_count, true)!
		}
		if instruction.op in [.call, .construct, .super_construct, .copy_object_excluding_keys, .enter_class_private_environment] {
			for argument in instruction.arguments {
				argument.slot(executable, arguments_count, false)!
			}
		}
		if instruction.op in [.new_function, .new_function_with_name, .new_class_method] && (executable.parsed_source == unsafe { nil }
			|| instruction.identifier >= u32(executable.parsed_source.function_table.entries.len)) {
			return error('Function index out of range')
		}
		if instruction.op == .new_class && instruction.identifier >= u32(executable.class_source_spans.len) { return error('Class source index out of range') }
		if instruction.op == .define_class_method && instruction.identifier > 2 { return error('Invalid class method kind') }
		if instruction.op == .record_empty_class_field && instruction.identifier > 1 { return error('Invalid class field kind') }
		if instruction.op == .record_private_class_method && (instruction.identifier > 2 || instruction.target > 1) { return error('Invalid private class method kind') }
		if instruction.op in [.get_binding, .get_callee_and_this, .typeof_binding, .delete_binding, .set_binding, .set_variable, .initialize_binding, .create_mutable_binding, .create_immutable_binding]
			&& instruction.identifier >= u32(executable.identifier_table.len) {
			return error('Identifier out of range')
		}
		if instruction.op in [.jump, .jump_if_true, .jump_if_false, .jump_if_nullish, .property_name_iterator_next, .sync_iterator_next]
			&& instruction.target >= executable.bytecode_length {
			return error('Jump target out of range')
		}
	}
	mut previous_end := u32(0)
	for handler in executable.exception_handlers {
		if handler.start_offset < previous_end || handler.start_offset >= handler.end_offset
			|| handler.end_offset > executable.bytecode_length
			|| handler.handler_offset >= executable.bytecode_length {
			return error('Invalid exception handler range')
		}
		previous_end = handler.end_offset
	}
}
