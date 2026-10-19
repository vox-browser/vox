module libjs

fn proto_accessor_call(mut vm VM, setter bool, receiver Value, arguments []Value, prototypes PrimitiveObjectPrototypes) !Value {
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [setter, prototypes] (mut vm VM) !Value {
		if setter { return object_prototype_proto_setter(mut vm) }
		return object_prototype_proto_getter(mut vm, prototypes)
	}, 0, PropertyName.from_str('__proto__'), none)
	return call(mut vm, Value.from_object(function.object), receiver, arguments)
}

fn test_proto_getter_returns_null_or_prototype_and_boxes_current_realm_primitives() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	child := Object.create(Realm.create(), parent)
	getter := fn [parent] (realm &Realm) &Object {
		return parent
	}
	prototypes := PrimitiveObjectPrototypes{
		number: getter
		bigint: getter
		string: getter
	}
	for receiver in [Value.from_object(child), Value.from_i32(42),
		Value.from_bigint(string_to_bigint(utf16_string('42')) or { panic('invalid BigInt literal') }),
		Value.from_string(vm.create_string_from_str('abc'))] {
		result := proto_accessor_call(mut vm, false, receiver, []Value{}, prototypes)!
		assert same_value(result, Value.from_object(parent))
	}
	for receiver in [Value.from_bool(true), Value.from_symbol(Symbol.create(none, .unique))] {
		result := proto_accessor_call(mut vm, false, receiver, []Value{}, prototypes)!
		expected := if receiver.is_boolean() {
			vm.realm().boolean_prototype_record()
		} else {
			vm.realm().symbol_prototype_record()
		}
		assert same_value(result, Value.from_object(expected))
	}
	result := proto_accessor_call(mut vm, false, Value.from_object(parent), []Value{}, prototypes)!
	assert result.is_null()
	for receiver in [js_null(), js_undefined()] {
		if _ := proto_accessor_call(mut vm, false, receiver, []Value{}, prototypes) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == 'ToObject on null or undefined'
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_proto_setter_requires_coercibility_first_and_ignores_primitives_without_boxing() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut parent := Object.create(vm.realm(), none)
	parent.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('toString'), fn (mut vm VM) !Value {
		panic('proto setter does not coerce prototype arguments')
	}, unsafe { nil }, 0, vm.realm().function_prototype)
	for prototype in [js_null(), Value.from_object(parent), js_undefined(),
		Value.from_i32(42)] {
		for receiver in [js_null(), js_undefined()] {
			if _ := proto_accessor_call(mut vm, true, receiver, [prototype], PrimitiveObjectPrototypes{}) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_message()?.str() == '${receiver.str()} cannot be converted to an object'
			}
		}
		for receiver in [Value.from_i32(42), Value.from_string(vm.create_string_from_str('abc')),
			Value.from_bool(true), Value.from_symbol(Symbol.create(none, .unique)),
			Value.from_bigint(string_to_bigint(utf16_string('42')) or { panic('invalid BigInt literal') })] {
			// No primitive dependencies supplied: this path must never box.
			result :=
				proto_accessor_call(mut vm, true, receiver, [prototype], PrimitiveObjectPrototypes{})!
			assert result.is_undefined()
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_proto_setter_mutates_ordinary_prototypes_rejects_cycles_and_respects_immutable_and_closed_objects() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	mut object := Object.create(vm.realm(), none)
	for prototype in [Value.from_object(parent), js_null()] {
		result := proto_accessor_call(mut vm, true, Value.from_object(object), [
			prototype,
		], PrimitiveObjectPrototypes{})!
		assert result.is_undefined()
		actual :=
			proto_accessor_call(mut vm, false, Value.from_object(object), []Value{}, PrimitiveObjectPrototypes{})!
		assert same_value(actual, prototype)
	}
	for prototype in [js_undefined(), Value.from_i32(42),
		Value.from_string(vm.create_string_from_str('ignored'))] {
		result := proto_accessor_call(mut vm, true, Value.from_object(object), [
			prototype,
		], PrimitiveObjectPrototypes{})!
		assert result.is_undefined() && object.prototype == none
	}
	child := Object.create(vm.realm(), object)
	mut closed := Object.create(vm.realm(), parent)
	closed.internal_prevent_extensions()
	mut immutable := Object.create(vm.realm(), none)
	immutable.immutable_prototype = true
	for index, receiver in [object, object, closed, immutable] {
		prototype := [Value.from_object(object), Value.from_object(child),
			js_null(), Value.from_object(parent)][index]
		if _ := proto_accessor_call(mut vm, true, Value.from_object(receiver), [
			prototype,
		], PrimitiveObjectPrototypes{})
		{
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == ErrorType.object_set_prototype_of_returned_false.message().str()
		}
	}
	unchanged := proto_accessor_call(mut vm, true, Value.from_object(closed), [
		Value.from_object(parent),
	], PrimitiveObjectPrototypes{})!
	assert unchanged.is_undefined() && voidptr(closed.prototype?) == voidptr(parent)
	unchanged_root := proto_accessor_call(mut vm, true, Value.from_object(immutable), [
		js_null(),
	], PrimitiveObjectPrototypes{})!
	assert unchanged_root.is_undefined() && immutable.prototype == none && object.prototype == none
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
