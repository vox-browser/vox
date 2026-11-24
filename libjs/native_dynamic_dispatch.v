module libjs

$if test {
	__global fast_binding_reads_disabled bool
	pub fn set_fast_binding_reads_for_testing(enabled bool) { fast_binding_reads_disabled = !enabled }
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

fn use_fast_binding_reads() bool {
	$if test { if fast_binding_reads_disabled { return false } }
	return true
}

fn (mut vm VM) own_global_data_binding(environment Environment, name Utf16String) ?Value {
	if environment is GlobalEnvironment {
		if environment.object_record.with_environment { return none }
		if environment.declarative_record.bindings.len != 0 && environment.declarative_record.has_binding_named(name) { return none }
		object := environment.object_record.binding_object
		if object.proxy_object != none || object.host_properties != none || object.typed_array != none
			|| object.string_object != none || object.arguments_object != none
			|| object.legacy_platform_object != none || object.array_object != none { return none }
		value := vm.live_global_data_binding(object, name) or { return none }
		if mut tier := vm.native_tier { if tier.diagnostics { tier.activity.own_global_binding_reads++ } }
		return value
	}
	return none
}

// Shared with the interpreter: native dynamic operations retain the same
// conversions, argument ownership and error paths without entering its large
// all-opcode switch. Budget and exception dispatch stay in native_slow_step.
fn (mut vm VM) execute_call_instruction(instruction &Instruction, executable &Executable, left Value, right Value) !Value {
	if use_call_argument_workspaces() && instruction.op == .call && instruction.arguments.len <= 8
		&& can_borrow_call_arguments(left) {
		return vm.execute_reused_argument_call(instruction, executable, left, right)
	}
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
		argument := if checked_interpreter_operands {
			frame.checked_dispatch_value(operand.slot(executable, frame.argument_count, false)!)!
		} else {
			// run_executable() validated this executable for the frame.
			unsafe { (&Value(frame.values.data))[operand.validated_slot(executable)] }
		}
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

// execute_property_read() for a get_property instruction with its position hint.
fn (mut vm VM) execute_property_read_at(left Value, right Value, strict bool, hint &u32) !Value {
	if left.is_object() && use_compact_reference_reads() {
		key := right.to_property_key(mut vm)!
		vm.record_compact_reference_read()
		return left.as_object().hinted_get(mut vm, key, left, hint)
	}
	return vm.execute_property_read(left, right, strict)
}

fn (mut vm VM) execute_binding_read(instruction &Instruction, executable &Executable) !Value {
	if instruction.op == .get_binding && instruction.target == static_binding_scope
		&& use_compact_reference_reads() && use_fast_binding_reads() {
		// Executable.validate() bounds every binding identifier.
		name := unsafe { &executable.identifier_table[instruction.identifier] }
		coordinate := executable.binding_hint(vm.current_context().program_counter)
		if mut environment := vm.hinted_binding_environment(unsafe { *coordinate }) {
			index := int(unsafe { *coordinate } & binding_hint_index_mask)
			if mut environment is FunctionEnvironment {
				if environment.DeclarativeEnvironment.hinted_binding_matches(index, name) {
					vm.record_compact_reference_read()
					return environment.get_binding_value_direct(mut vm, index)
				}
			} else if mut environment is DeclarativeEnvironment {
				if environment.hinted_binding_matches(index, name) {
					vm.record_compact_reference_read()
					return environment.get_binding_value_direct(mut vm, index)
				}
			}
		}
		value, _ := vm.resolve_compact_read_recording(*name, instruction.strict, false, false, coordinate)!
		return value
	}
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
	return vm.resolve_compact_read_recording(name, strict, callee, allow_missing, unsafe { nil })
}

// `coordinate`, when given, receives the declarative environment hops and
// binding index of a binding found without passing a non-declarative one.
fn (mut vm VM) resolve_compact_read_recording(name Utf16String, strict bool, callee bool, allow_missing bool, coordinate &u32) !(Value, Value) {
	initial := vm.current_context().lexical_environment or { panic('ResolveBinding: the running execution context has no lexical environment') }
	mut environment := ?Environment(initial)
	mut hops := u32(0)
	mut declarative_path := true
	for {
		mut current := environment or { break }
		if use_fast_binding_reads() {
			if mut current is FunctionEnvironment {
				if current.bindings.len == 0 {
					if mut tier := vm.native_tier { if tier.diagnostics { tier.activity.empty_binding_environments_skipped++ } }
					environment = current.outer_environment()
					hops++
					continue
				}
				if use_direct_declarative_reads() {
					index := current.find_binding_index(name)
					if index >= 0 {
						value := current.get_binding_value_direct(mut vm, index)!
						vm.record_direct_declarative_binding_read()
						vm.record_compact_reference_read()
						record_binding_coordinate(coordinate, declarative_path, hops, index)
						return value, js_undefined()
					}
					environment = current.outer_environment()
					hops++
					continue
				}
			} else if mut current is DeclarativeEnvironment {
				if current.bindings.len == 0 {
					if mut tier := vm.native_tier { if tier.diagnostics { tier.activity.empty_binding_environments_skipped++ } }
					environment = current.outer_environment()
					hops++
					continue
				}
				if use_direct_declarative_reads() {
					index := current.find_binding_index(name)
					if index >= 0 {
						value := current.get_binding_value_direct(mut vm, index)!
						vm.record_direct_declarative_binding_read()
						vm.record_compact_reference_read()
						record_binding_coordinate(coordinate, declarative_path, hops, index)
						return value, js_undefined()
					}
					environment = current.outer_environment()
					hops++
					continue
				}
			} else if mut current is GlobalEnvironment {
				if value := vm.own_global_data_binding(current, name) {
					vm.record_compact_reference_read()
					return value, js_undefined()
				}
			}
		}
		exists, _ := current.has_binding(mut vm, name)!
		if exists {
			value := current.get_binding_value(mut vm, name, strict)!
			mut receiver := js_undefined()
			if callee { if base := current.with_base_object() { receiver = Value.from_object(base) } }
			vm.record_compact_reference_read()
			return value, receiver
		}
		// Object, global and other environments do not keep fixed positions.
		declarative_path = false
		environment = current.outer_environment()
		hops++
	}
	if allow_missing { return js_undefined(), js_undefined() }
	return vm.throw_error_type(.reference_error, .unknown_identifier, name.str())
}

fn (mut vm VM) execute_callee_read(instruction &Instruction, executable &Executable) !(Value, Value) {
	if instruction.target == static_binding_scope && use_compact_reference_reads()
		&& use_fast_binding_reads() {
		// A declarative binding has no with-base receiver.
		name := unsafe { &executable.identifier_table[instruction.identifier] }
		coordinate := executable.binding_hint(vm.current_context().program_counter)
		if mut environment := vm.hinted_binding_environment(unsafe { *coordinate }) {
			index := int(unsafe { *coordinate } & binding_hint_index_mask)
			if mut environment is FunctionEnvironment {
				if environment.DeclarativeEnvironment.hinted_binding_matches(index, name) {
					vm.record_compact_reference_read()
					return environment.get_binding_value_direct(mut vm, index)!, js_undefined()
				}
			} else if mut environment is DeclarativeEnvironment {
				if environment.hinted_binding_matches(index, name) {
					vm.record_compact_reference_read()
					return environment.get_binding_value_direct(mut vm, index)!, js_undefined()
				}
			}
		}
		return vm.resolve_compact_read_recording(*name, instruction.strict, true, false, coordinate)
	}
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
