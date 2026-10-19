module libjs

@[heap]
struct ObjectMethodLog {
mut:
	events []string
}

fn object_method_call(mut vm VM, name string, receiver Value, arguments []Value, prototypes PrimitiveObjectPrototypes) !Value {
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [name, prototypes] (mut vm VM) !Value {
		return match name {
			'hasOwnProperty' { object_prototype_has_own_property(mut vm, prototypes) }
			'propertyIsEnumerable' { object_prototype_property_is_enumerable(mut vm, prototypes) }
			'isPrototypeOf' { object_prototype_is_prototype_of(mut vm, prototypes) }
			'toLocaleString' { object_prototype_to_locale_string(mut vm, prototypes) }
			'valueOf' { object_prototype_value_of(mut vm, prototypes) }
			else { panic('unknown fixture method') }
		}
	}, 0, PropertyName.from_str(name), none)
	return call(mut vm, Value.from_object(function.object), receiver, arguments)
}

fn test_object_membership_uses_own_descriptors_without_invoking_accessors() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut parent := Object.create(vm.realm(), none)
	parent.define_direct_property(PropertyName.from_str('inherited'), Value.from_i32(42), 7)
	mut object := Object.create(vm.realm(), parent)
	object.define_direct_property(PropertyName.from_str('hidden'), Value.from_i32(42), 5)
	object.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('accessor'), fn (mut vm VM) !Value {
		panic('membership does not invoke getter')
	}, unsafe { nil }, attribute_enumerable, vm.realm().function_prototype)
	symbol := Symbol.create(utf16_string('key'), .unique)
	object.define_direct_property(PropertyName.from_symbol(symbol), Value.from_i32(42), 7)
	for name in ['hasOwnProperty', 'propertyIsEnumerable'] {
		for property in ['inherited', 'missing', 'hidden', 'accessor'] {
			result := object_method_call(mut vm, name, Value.from_object(object), [
				Value.from_string(vm.create_string_from_str(property)),
			], PrimitiveObjectPrototypes{})!
			assert result.as_bool() == (property == 'accessor'
				|| (name == 'hasOwnProperty' && property == 'hidden'))
		}
		result := object_method_call(mut vm, name, Value.from_object(object), [
			Value.from_symbol(symbol),
		], PrimitiveObjectPrototypes{})!
		assert result.as_bool()
	}
	getter := fn [parent] (realm &Realm) &Object {
		return parent
	}
	prototypes := PrimitiveObjectPrototypes{
		string: getter
	}
	for name in ['hasOwnProperty', 'propertyIsEnumerable'] {
		for key in [Value.from_i32(0), Value.from_i32(1),
			Value.from_string(vm.create_string_from_str('length'))] {
			result := object_method_call(mut vm, name,
				Value.from_string(vm.create_string_from_str('ab')), [key], prototypes)!
			assert result.as_bool() == (name == 'hasOwnProperty' || key.is_number())
		}
	}
}

fn test_object_membership_converts_keys_before_nullish_receiver_and_preserves_abrupt_completion() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut log := &ObjectMethodLog{}
	for name in ['hasOwnProperty', 'propertyIsEnumerable'] {
		for abrupt in [false, true] {
			mut key := Object.create(vm.realm(), none)
			method := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [abrupt, mut log] (mut vm VM) !Value {
				log.events << 'key'
				assert vm.argument(0).as_string().str() == 'string'
				if abrupt { return throw_completion(Value.from_i32(77)) }
				return Value.from_string(vm.create_string_from_str('answer'))
			}, 1, PropertyName.from_str('key'), none)
			key.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
				Value.from_object(method.object), 7)
			if _ := object_method_call(mut vm, name, js_null(), [
				Value.from_object(key),
			], PrimitiveObjectPrototypes{})
			{
				assert false
			} else {
				if abrupt {
					assert thrown_value(err).number == 77
				} else {
					assert thrown_value(err).as_object().error_message()?.str() == 'ToObject on null or undefined'
				}
			}
		}
	}
	assert log.events == ['key', 'key', 'key', 'key']
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_object_is_prototype_of_skips_coercion_for_primitives_and_walks_by_identity() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	child := Object.create(vm.realm(), parent)
	grandchild := Object.create(vm.realm(), child)
	for argument in [js_undefined(), js_null(), Value.from_i32(42),
		Value.from_bool(true)] {
		result :=
			object_method_call(mut vm, 'isPrototypeOf', js_null(), [argument], PrimitiveObjectPrototypes{})!
		assert !result.as_bool()
	}
	for candidate in [parent, child, grandchild] {
		result := object_method_call(mut vm, 'isPrototypeOf', Value.from_object(parent), [
			Value.from_object(candidate),
		], PrimitiveObjectPrototypes{})!
		assert result.as_bool() == (voidptr(candidate) != voidptr(parent))
	}
	getter := fn [parent] (realm &Realm) &Object {
		return parent
	}
	result := object_method_call(mut vm, 'isPrototypeOf', Value.from_i32(42), [
		Value.from_object(child),
	], PrimitiveObjectPrototypes{ number: getter })!
	assert !result.as_bool()
	if _ := object_method_call(mut vm, 'isPrototypeOf', js_undefined(), [
		Value.from_object(child),
	], PrimitiveObjectPrototypes{})
	{
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
}

fn test_object_value_of_boxes_all_primitives_with_current_realm_prototypes_and_preserves_objects() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	getter := fn [parent] (realm &Realm) &Object {
		return parent
	}
	prototypes := PrimitiveObjectPrototypes{
		number: getter
		bigint: getter
		string: getter
	}
	for value in [Value.from_i32(42), Value.from_bigint(string_to_bigint(utf16_string('42')) or { panic('invalid BigInt literal') }),
		Value.from_string(vm.create_string_from_str('ab')), Value.from_bool(true),
		Value.from_symbol(Symbol.create(utf16_string('key'), .unique)),
		Value.from_object(parent)] {
		one := object_method_call(mut vm, 'valueOf', value, []Value{}, prototypes)!.as_object()
		two := object_method_call(mut vm, 'valueOf', value, []Value{}, prototypes)!.as_object()
		assert (voidptr(one) == voidptr(two)) == value.is_object()
		if value.is_number() {
			assert one.number_object?.value == 42 && voidptr(one.prototype?) == voidptr(parent)
		} else if value.is_bigint() {
			assert voidptr(one.bigint_object?.bigint) == voidptr(value.as_bigint())
		} else if value.is_string() {
			assert voidptr(one.string_object?.value) == voidptr(value.as_string())
		} else if value.is_boolean() {
			assert one.boolean_object?.value
				&& voidptr(one.prototype?) == voidptr(vm.realm().boolean_prototype_record())
		} else if value.is_symbol() {
			assert voidptr(one.symbol_object?.symbol) == voidptr(value.as_symbol())
		} else {
			assert voidptr(one) == voidptr(parent)
		}
	}
	for value in [js_undefined(), js_null()] {
		if _ := object_method_call(mut vm, 'valueOf', value, []Value{}, prototypes) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
}

fn test_object_to_locale_string_invokes_live_to_string_with_primitive_receiver_and_no_arguments() {
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
	mut log := &ObjectMethodLog{}
	for receiver in [Value.from_i32(42), Value.from_bigint(string_to_bigint(utf16_string('42')) or { panic('invalid BigInt literal') }),
		Value.from_string(vm.create_string_from_str('ab')), Value.from_object(parent)] {
		function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [receiver, mut log] (mut vm VM) !Value {
			log.events << 'call'
			assert same_value(vm.this_value(), receiver) && vm.argument_count() == 0
			return Value.from_i32(77)
		}, 0, PropertyName.from_str('toString'), none)
		parent.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('toString'), fn [receiver, function, mut log] (mut vm VM) !Value {
			log.events << 'get'
			assert same_value(vm.this_value(), receiver)
			return Value.from_object(function.object)
		}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
		result := object_method_call(mut vm, 'toLocaleString', receiver, [
			Value.from_i32(1),
			Value.from_i32(2),
		], prototypes)!
		assert result.number == 77
	}
	assert log.events == ['get', 'call', 'get', 'call', 'get', 'call', 'get', 'call']
	parent.define_direct_property(PropertyName.from_str('toString'), Value.from_i32(42), 7)
	if _ := object_method_call(mut vm, 'toLocaleString', Value.from_i32(1), []Value{}, prototypes) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == '42 is not a function'
	}
	parent.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('toString'), fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(99))
	}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
	if _ := object_method_call(mut vm, 'toLocaleString', Value.from_object(parent), []Value{},
		prototypes)
	{
		assert false
	} else {
		assert thrown_value(err).number == 99
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
