module libjs

$if test {
	__global native_dynamic_dispatch_disabled bool
	__global compact_reference_reads_disabled bool
	pub fn set_compact_reference_reads_for_testing(enabled bool) { compact_reference_reads_disabled = !enabled }
	pub fn set_native_dynamic_dispatch_for_testing(enabled bool) { native_dynamic_dispatch_disabled = !enabled }
}
fn use_native_dynamic_dispatch() bool {
	$if test { if native_dynamic_dispatch_disabled { return false } }
	return true
}

fn use_compact_reference_reads() bool {
	$if test { if compact_reference_reads_disabled { return false } }
	return true
}
fn (mut vm VM) record_compact_reference_read() {
	if mut tier := vm.native_tier { if tier.diagnostics { tier.activity.compact_reference_reads++ } }
}

// Shared with the interpreter: native dynamic operations retain the same
// conversions, argument ownership and error paths without entering its large
// all-opcode switch. Budget and exception dispatch stay in native_slow_step.
fn (mut vm VM) execute_call_instruction(instruction &Instruction, executable &Executable, left Value, right Value) !Value {
	frame := vm.current_context()
	// These concrete callees copy their arguments into owned frames before
	// executing user code. Custom callables and constructors may retain
	// their input slice and therefore keep the owning allocation path.
	mut local_arguments := [8]Value{}
	borrow := instruction.op == .call && instruction.arguments.len <= 8
		&& can_borrow_call_arguments(left)
	mut call_arguments := if borrow { unsafe { borrow_argument_values(&local_arguments[0], instruction.arguments.len) } }
		else { []Value{len: instruction.arguments.len} }
	if instruction.op == .super_construct && instruction.strict {
		call_arguments = []Value{cap: int(frame.passed_argument_count) + instruction.arguments.len}
	}
	if instruction.op == .super_construct && instruction.strict {
		for index in 0 .. frame.passed_argument_count { call_arguments << frame.argument(index) }
	}
	for argument_index, operand in instruction.arguments {
		argument := frame.checked_dispatch_value(operand.slot(executable, frame.argument_count, false)!)!
		if argument.is_special_empty_value() {
			return vm.throw_error(.internal_error,
				'Bytecode read an uninitialized argument')
		}
		if instruction.op == .super_construct && instruction.strict { call_arguments << argument }
		else { call_arguments[argument_index] = argument }
	}
	if instruction.op == .super_construct {
		return construct_super(mut vm, left, call_arguments)
	} else if instruction.op == .construct {
		// Interpreter/SlowPaths.cpp::execute_asm_call, Construct branch.
		object := construct(mut vm, left, call_arguments, none)!
		return Value.from_object(object)
	} else {
		return call(mut vm, left, right, call_arguments)
	}
}

fn (mut vm VM) execute_property_read(left Value, right Value, strict bool) !Value {
	// Nullish bases fail before invoking the key's coercion hooks.
	if left.is_nullish() {
		name := if right.is_string() { right.as_string().str() } else { right.str() }
		return vm.throw_error_type(.type_error, .to_object_null_or_undefined_with_property,
			name, left.str())
	}
	key := right.to_property_key(mut vm)!
	if left.is_string() {
		if own := left.as_string().get_own_property(mut vm, key) { return own }
	}
	if left.is_object() && use_compact_reference_reads() {
		vm.record_compact_reference_read()
		return left.as_object().internal_get(mut vm, key, left)
	}
	return Reference.for_value(left, key, none, strict).get_value(mut vm)
}

fn (mut vm VM) execute_binding_read(instruction &Instruction, executable &Executable) !Value {
	if use_compact_reference_reads() {
		value, _ := vm.resolve_compact_read(executable.get_identifier(instruction.identifier), instruction.strict, false, instruction.op == .typeof_binding)!
		return if instruction.op == .typeof_binding { Value.from_string(vm.create_string_from_str(typeof_value(value))) } else { value }
	}
	reference := vm.resolve_binding(executable.get_identifier(instruction.identifier),
		instruction.strict, none)!
	if instruction.op == .typeof_binding && reference.is_unresolvable() {
		return Value.from_string(vm.create_string_from_str('undefined'))
	} else {
		value := reference.get_value(mut vm)!
		return if instruction.op == .typeof_binding {
			Value.from_string(vm.create_string_from_str(typeof_value(value)))
		} else {
			value
		}
	}
}

// GetIdentifierReference followed immediately by GetValue need not materialize
// a retained Reference. Keep HasBinding/GetBindingValue/WithBaseObject order;
// the environment remains live across arbitrary proxy and accessor callbacks.
fn (mut vm VM) resolve_compact_read(name Utf16String, strict bool, callee bool, allow_missing bool) !(Value, Value) {
	initial := vm.current_context().lexical_environment or { panic('ResolveBinding: the running execution context has no lexical environment') }
	mut environment := ?Environment(initial)
	for {
		mut current := environment or { break }
		exists, _ := current.has_binding(mut vm, name)!
		if exists {
			value := current.get_binding_value(mut vm, name, strict)!
			mut receiver := js_undefined()
			if callee { if base := current.with_base_object() { receiver = Value.from_object(base) } }
			vm.record_compact_reference_read()
			return value, receiver
		}
		environment = current.outer_environment()
	}
	if allow_missing { return js_undefined(), js_undefined() }
	return vm.throw_error_type(.reference_error, .unknown_identifier, name.str())
}

fn (mut vm VM) execute_callee_read(instruction &Instruction, executable &Executable) !(Value, Value) {
	name := executable.get_identifier(instruction.identifier)
	if use_compact_reference_reads() { return vm.resolve_compact_read(name, instruction.strict, true, false) }
	reference := vm.resolve_binding(name, instruction.strict, none)!
	value := reference.get_value(mut vm)!
	mut receiver := js_undefined()
	if reference.is_property_reference() { receiver = reference.get_this_value() }
	else if reference.is_environment_reference() {
		if base := reference.base_environment_record().with_base_object() { receiver = Value.from_object(base) }
	}
	return value, receiver
}

fn (mut vm VM) execute_native_dynamic(instruction &Instruction, executable &Executable) !u32 {
	mut frame := vm.current_context()
	next := frame.program_counter + 1
	if instruction.op == .get_callee_and_this {
		value, receiver := vm.execute_callee_read(instruction, executable)!
		frame.store_dispatch_value(instruction.dst.slot(executable, frame.argument_count, true)!, value)!
		frame.store_dispatch_value(instruction.rhs.slot(executable, frame.argument_count, true)!, receiver)!
		return next
	}
	mut left := js_undefined()
	mut right := js_undefined()
	if instruction.op in [.call, .construct, .super_construct, .get_property] {
		left = frame.checked_dispatch_value(instruction.lhs.slot(executable, frame.argument_count, false)!)!
		if left.is_special_empty_value() { return vm.throw_error(.internal_error, 'Bytecode read an uninitialized operand') }
		if instruction.op in [.call, .get_property] {
			right = frame.checked_dispatch_value(instruction.rhs.slot(executable, frame.argument_count, false)!)!
			if right.is_special_empty_value() { return vm.throw_error(.internal_error, 'Bytecode read an uninitialized operand') }
		}
	}
	result := match instruction.op {
		.call, .construct, .super_construct { vm.execute_call_instruction(instruction, executable, left, right)! }
		.get_property { vm.execute_property_read(left, right, instruction.strict)! }
		else { vm.execute_binding_read(instruction, executable)! }
	}
	frame.store_dispatch_value(instruction.dst.slot(executable, frame.argument_count, true)!, result)!
	return next
}

// Keep an explicit buffer-length check as well as Operand.slot's checked layout.
// Typed pointer access avoids the generic array setter and its out-of-line
// element copy. No pointer survives a call or a buffer replacement.
@[inline]
fn (frame &ExecutionContext) checked_dispatch_value(slot u32) !Value {
	if u64(slot) >= u64(frame.values.len) { return error('Bytecode frame value index out of range') }
	return unsafe { (&Value(frame.values.data))[slot] }
}

@[inline]
fn (mut frame ExecutionContext) store_dispatch_value(slot u32, value Value) ! {
	if u64(slot) >= u64(frame.values.len) { return error('Bytecode frame value index out of range') }
	unsafe { (&Value(frame.values.data))[slot] = value }
}
