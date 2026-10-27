module libjs

fn reflect_prototype_call(mut vm VM, name string, arguments []Value) !Value {
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [name] (mut vm VM) !Value {
		return match name {
			'getPrototypeOf' { reflect_get_prototype_of(mut vm) }
			'setPrototypeOf' { reflect_set_prototype_of(mut vm) }
			'isExtensible' { reflect_is_extensible(mut vm) }
			'preventExtensions' { reflect_prevent_extensions(mut vm) }
			else { panic('fixture method') }
		}
	}, 1, PropertyName.from_str(name), none)
	return call(mut vm, Value.from_object(function.object), js_undefined(), arguments)
}

fn test_reflect_prototype_operations_validate_target_before_prototype_and_never_box_primitives() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	for name in ['getPrototypeOf', 'setPrototypeOf', 'isExtensible', 'preventExtensions'] {
		for value in [js_null(), js_undefined(), Value.from_i32(42),
			Value.from_bool(true), Value.from_string(vm.create_string_from_str('abc')),
			Value.from_bigint(string_to_bigint(utf16_string('42')) or { panic('invalid BigInt literal') }),
			Value.from_symbol(Symbol.create(none, .unique))] {
			if _ := reflect_prototype_call(mut vm, name, [value, Value.from_i32(42)]) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_message()?.str() == '${value.str()} is not an object'
			}
		}
	}
	object := Object.create(vm.realm(), none)
	for value in [js_undefined(), Value.from_i32(42), Value.from_bool(true),
		Value.from_string(vm.create_string_from_str('ignored'))] {
		if _ := reflect_prototype_call(mut vm, 'setPrototypeOf', [
			Value.from_object(object),
			value,
		])
		{
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == 'Prototype must be an object or null'
		}
	}
	assert object.prototype == none
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_reflect_set_prototype_of_reports_cycles_immutable_prototypes_and_nonextensibility_as_false() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	mut object := Object.create(vm.realm(), none)
	for proposed in [Value.from_object(parent), js_null()] {
		changed := reflect_prototype_call(mut vm, 'setPrototypeOf', [
			Value.from_object(object),
			proposed,
		])!
		assert changed.as_bool()
		actual := reflect_prototype_call(mut vm, 'getPrototypeOf', [
			Value.from_object(object),
		])!
		assert same_value(actual, proposed)
	}
	child := Object.create(vm.realm(), object)
	mut immutable := Object.create(vm.realm(), none)
	immutable.immutable_prototype = true
	mut closed := Object.create(vm.realm(), parent)
	closed.internal_prevent_extensions()
	for index, receiver in [object, object, immutable, closed] {
		proposed := [Value.from_object(object), Value.from_object(child),
			Value.from_object(parent), js_null()][index]
		result := reflect_prototype_call(mut vm, 'setPrototypeOf', [
			Value.from_object(receiver),
			proposed,
		])!
		assert !result.as_bool()
	}
	for index, receiver in [immutable, closed] {
		proposed := [js_null(), Value.from_object(parent)][index]
		result := reflect_prototype_call(mut vm, 'setPrototypeOf', [
			Value.from_object(receiver),
			proposed,
		])!
		assert result.as_bool()
	}
	assert object.prototype == none && immutable.prototype == none
	assert voidptr(closed.prototype?) == voidptr(parent)
}

fn test_reflect_extensibility_retains_typed_array_exotic_refusal_without_throwing() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	ordinary := Object.create(vm.realm(), none)
	fixed_buffer := ArrayBufferObject.create(mut vm, vm.realm(), 4, parent)!
	mut buffer := ArrayBufferObject.create(mut vm, vm.realm(), 4, parent)!
	buffer.maximum_byte_length = uint(8)
	fixed := TypedArray.create(vm.realm(), .uint8, 4, fixed_buffer, parent)
	resizable_fixed := TypedArray.create(vm.realm(), .uint8, 4, buffer, parent)
	mut tracking := TypedArray.create(vm.realm(), .uint8, 4, buffer, parent)
	tracking.array_length = ByteLength.auto_length()
	tracking.byte_length = ByteLength.auto_length()
	for object in [ordinary, fixed.object, resizable_fixed.object, tracking.object] {
		can_prevent := voidptr(object) == voidptr(ordinary)
			|| voidptr(object) == voidptr(fixed.object)
		before := reflect_prototype_call(mut vm, 'isExtensible', [
			Value.from_object(object),
		])!
		assert before.as_bool()
		result := reflect_prototype_call(mut vm, 'preventExtensions', [
			Value.from_object(object),
		])!
		assert result.as_bool() == can_prevent
		after := reflect_prototype_call(mut vm, 'isExtensible', [
			Value.from_object(object),
		])!
		assert after.as_bool() == !can_prevent
	}
}
