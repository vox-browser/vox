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
		.get_property, .delete_property, .new_regexp, .set_object_literal_prototype {
			2
		}
		.put_property, .define_property {
			3
		}
		.mov, .unary_plus, .unary_minus, .bitwise_not, .not_op, .typeof_op, .to_numeric,
		.increment, .decrement, .set_binding, .set_variable, .initialize_binding, .jump_if_true,
		.require_object_coercible, .to_property_key, .copy_object_excluding_keys,
		.jump_if_false, .jump_if_nullish, .end, .throw_op, .construct, .new_array, .new_function_with_name {
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
	return instruction.op !in [.put_property, .define_property, .set_binding, .set_variable, .initialize_binding,
		.create_mutable_binding, .create_immutable_binding, .enter_scope, .leave_scope, .jump,
		.require_object_coercible, .set_object_literal_prototype,
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
		for index in 0 .. instruction.input_count() {
			operand := instruction.input_operand(index)
			operand.slot(executable, arguments_count, false)!
		}
		if instruction.writes_operand() { instruction.dst.slot(executable, arguments_count, true)! }
		if instruction.op == .get_callee_and_this {
			instruction.rhs.slot(executable, arguments_count, true)!
		}
		if instruction.op in [.call, .construct, .copy_object_excluding_keys] {
			for argument in instruction.arguments {
				argument.slot(executable, arguments_count, false)!
			}
		}
		if instruction.op in [.new_function, .new_function_with_name] && (executable.parsed_source == unsafe { nil }
			|| instruction.identifier >= u32(executable.parsed_source.function_table.entries.len)) {
			return error('Function index out of range')
		}
		if instruction.op in [.get_binding, .get_callee_and_this, .typeof_binding, .delete_binding, .set_binding, .set_variable, .initialize_binding, .create_mutable_binding, .create_immutable_binding]
			&& instruction.identifier >= u32(executable.identifier_table.len) {
			return error('Identifier out of range')
		}
		if instruction.op in [.jump, .jump_if_true, .jump_if_false, .jump_if_nullish]
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
