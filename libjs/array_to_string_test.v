module libjs

@[heap]
struct ArrayToStringLog {
mut:
	events []string
}

fn array_string_call(mut vm VM, receiver Value, prototypes PrimitiveObjectPrototypes, fallback IntrinsicPrototypeGetter) !Value {
	method := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [prototypes, fallback] (mut vm VM) !Value {
		return array_prototype_to_string(mut vm, prototypes, fallback)
	}, 0, PropertyName.from_str('toString'), none)
	return call(mut vm, Value.from_object(method.object), receiver, [
		Value.from_i32(99),
	])
}

fn test_array_to_string_calls_observable_join_with_boxed_object_and_no_forwarded_arguments() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut parent := Object.create(vm.realm(), none)
	getter := fn [parent] (realm &Realm) &Object {
		return parent
	}
	prototypes := PrimitiveObjectPrototypes{
		number: getter
		bigint: getter
		string: getter
	}
	for receiver in [Value.from_i32(42), Value.from_bigint(string_to_bigint(utf16_string('42')) or { panic('invalid BigInt literal') }),
		Value.from_string(vm.create_string_from_str('abc')), Value.from_object(parent)] {
		mut log := &ArrayToStringLog{}
		join := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [receiver, mut log] (mut vm VM) !Value {
			log.events << 'call'
			assert vm.argument_count() == 0 && vm.this_value().is_object()
			object := vm.this_value().as_object()
			if receiver.is_object() {
				assert voidptr(object) == voidptr(receiver.as_object())
			} else if receiver.is_number() {
				assert (object.number_object or { panic('fixture') }).value == receiver.number
			} else if receiver.is_bigint() {
				assert voidptr((object.bigint_object or { panic('fixture') }).bigint) == voidptr(receiver.as_bigint())
			} else {
				assert (object.string_object or { panic('fixture') }).value.utf16 == receiver.as_string().utf16
			}
			return Value.from_i32(77)
		}, 0, PropertyName.from_str('join'), none)
		parent.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('join'), fn [join, mut log] (mut vm VM) !Value {
			log.events << 'get'
			assert vm.this_value().is_object()
			return Value.from_object(join.object)
		}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
		fallback := fn (realm &Realm) &Object {
			panic('callable join does not request fallback')
		}
		result := array_string_call(mut vm, receiver, prototypes, fallback)!
		assert result.number == 77 && log.events == ['get', 'call']
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}

fn test_array_to_string_noncallable_join_uses_current_realm_retained_intrinsic_and_propagates_errors() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	foreign := create_simple_execution_context(mut vm).realm?
	vm.pop_execution_context()
	mut object := Object.create(foreign, none)
	mut log := &ArrayToStringLog{}
	fallback_function := NativeFunction.create(mut vm, realm, realm.function_prototype, fn [object, mut log] (mut vm VM) !Value {
		log.events << 'fallback'
		assert voidptr(vm.this_value().as_object()) == voidptr(object) && vm.argument_count() == 0
		return Value.from_string(vm.create_string_from_str('host tag'))
	}, 0, PropertyName.from_str('toString'), none)
	fallback := fn [realm, fallback_function, mut log] (requested &Realm) &Object {
		assert voidptr(requested) == voidptr(realm)
		log.events << 'intrinsic'
		return fallback_function.object
	}
	for value in [js_undefined(), js_null(), Value.from_i32(7),
		Value.from_object(object)] {
		object.define_direct_property(PropertyName.from_str('join'), value, 7)
		result := array_string_call(mut vm, Value.from_object(object), PrimitiveObjectPrototypes{},
			fallback)!
		assert result.as_string().str() == 'host tag'
	}
	assert log.events == ['intrinsic', 'fallback', 'intrinsic', 'fallback', 'intrinsic', 'fallback',
		'intrinsic', 'fallback']
	object.define_native_accessor(mut vm, realm, PropertyName.from_str('join'), fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(99))
	}, unsafe { nil }, attribute_configurable, realm.function_prototype)
	if _ := array_string_call(mut vm, Value.from_object(object), PrimitiveObjectPrototypes{},
		fallback)
	{
		assert false
	} else {
		assert thrown_value(err).number == 99
	}
	for nullish in [js_null(), js_undefined()] {
		if _ := array_string_call(mut vm, nullish, PrimitiveObjectPrototypes{}, fallback) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == 'ToObject on null or undefined'
		}
	}
	assert log.events.len == 8
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
