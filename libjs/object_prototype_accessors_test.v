module libjs

@[heap]
struct LegacyAccessorLog {
mut:
	events []string
}

fn legacy_accessor_call(mut vm VM, name string, receiver Value, arguments []Value, prototypes PrimitiveObjectPrototypes) !Value {
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [name, prototypes] (mut vm VM) !Value {
		return match name {
			'__defineGetter__' { object_prototype_define_getter(mut vm, prototypes) }
			'__defineSetter__' { object_prototype_define_setter(mut vm, prototypes) }
			'__lookupGetter__' { object_prototype_lookup_getter(mut vm, prototypes) }
			'__lookupSetter__' { object_prototype_lookup_setter(mut vm, prototypes) }
			else { panic('unknown fixture method') }
		}
	}, 1, PropertyName.from_str(name), none)
	return call(mut vm, Value.from_object(function.object), receiver, arguments)
}

fn test_legacy_accessor_definitions_preserve_the_other_callback_and_replace_data_descriptors() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut object := Object.create(vm.realm(), none)
	getter := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		return Value.from_i32(42)
	}, 0, PropertyName.from_str('getter'), none)
	setter := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		panic('definition and lookup never call the setter')
	}, 1, PropertyName.from_str('setter'), none)
	symbol := Symbol.create(utf16_string('key'), .unique)
	for property in [Value.from_string(vm.create_string_from_str('answer')),
		Value.from_symbol(symbol)] {
		key := property.to_property_key(mut vm)!
		object.define_direct_property(key, Value.from_i32(7), attribute_configurable)
		one := legacy_accessor_call(mut vm, '__defineGetter__', Value.from_object(object), [
			property,
			Value.from_object(getter.object),
		], PrimitiveObjectPrototypes{})!
		assert one.is_undefined()
		first := object.internal_get_own_property(key)?
		assert first.is_accessor_descriptor() && first.enumerable? && first.configurable?
		assert same_value(first.getter?, Value.from_object(getter.object))
			&& first.setter?.is_undefined()
		two := legacy_accessor_call(mut vm, '__defineSetter__', Value.from_object(object), [
			property,
			Value.from_object(setter.object),
		], PrimitiveObjectPrototypes{})!
		assert two.is_undefined()
		second := object.internal_get_own_property(key)?
		assert same_value(second.getter?, Value.from_object(getter.object))
		assert same_value(second.setter?, Value.from_object(setter.object))
		assert second.enumerable? && second.configurable?
		assert object.get(mut vm, key)!.number == 42
	}
}

fn test_legacy_accessor_definition_observes_receiver_then_callability_then_key_conversion() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut log := &LegacyAccessorLog{}
	parent := Object.create(vm.realm(), none)
	prototype_getter := fn [parent, mut log] (realm &Realm) &Object {
		log.events << 'box'
		return parent
	}
	prototypes := PrimitiveObjectPrototypes{
		number: prototype_getter
	}
	mut key := Object.create(vm.realm(), none)
	key_function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut log] (mut vm VM) !Value {
		log.events << 'key'
		return throw_completion(Value.from_i32(77))
	}, 1, PropertyName.from_str('key'), none)
	key.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(key_function.object), 7)
	callback := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		panic('definition never calls callback')
	}, 0, PropertyName.from_str('callback'), none)
	mut bad_callback := Object.create(vm.realm(), none)
	bad_callback.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('toString'), fn (mut vm VM) !Value {
		panic('non-callable diagnostic is side-effect free')
	}, unsafe { nil }, 0, vm.realm().function_prototype)
	for name in ['__defineGetter__', '__defineSetter__'] {
		for mode in 0 .. 3 {
			receiver := if mode == 0 { js_null() } else { Value.from_i32(42) }
			candidate := if mode == 2 {
				Value.from_object(callback.object)
			} else {
				Value.from_object(bad_callback)
			}
			if _ := legacy_accessor_call(mut vm, name, receiver, [
				Value.from_object(key),
				candidate,
			], prototypes)
			{
				assert false
			} else {
				if mode == 2 {
					assert thrown_value(err).number == 77
				} else {
					message := thrown_value(err).as_object().error_message()?.str()
					assert message == if mode == 0 {
						'ToObject on null or undefined'
					} else {
						'[object Object] is not a function'
					}
				}
			}
		}
	}
	assert log.events == ['box', 'box', 'key', 'box', 'box', 'key']
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_legacy_accessor_definition_propagates_define_property_failures_and_boxes_primitives() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	getter := fn [parent] (realm &Realm) &Object {
		return parent
	}
	prototypes := PrimitiveObjectPrototypes{
		number: getter
		string: getter
	}
	callback := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		panic('definition does not call callback')
	}, 0, PropertyName.from_str('callback'), none)
	property := Value.from_string(vm.create_string_from_str('answer'))
	for name in ['__defineGetter__', '__defineSetter__'] {
		mut frozen := Object.create(vm.realm(), none)
		frozen.define_direct_property(PropertyName.from_str('answer'), Value.from_i32(42), 0)
		mut closed := Object.create(vm.realm(), none)
		closed.internal_prevent_extensions()
		for receiver in [Value.from_object(frozen), Value.from_object(closed),
			Value.from_string(vm.create_string_from_str('a'))] {
			key := if receiver.is_string() { Value.from_i32(0) } else { property }
			if _ := legacy_accessor_call(mut vm, name, receiver, [key,
				Value.from_object(callback.object)], prototypes)
			{
				assert false
			} else {
				assert thrown_value(err).as_object().error_message()?.str() == ErrorType.object_define_own_property_returned_false.message().str()
			}
		}
		result := legacy_accessor_call(mut vm, name, Value.from_i32(42), [property,
			Value.from_object(callback.object)], prototypes)!
		assert result.is_undefined() && !parent.has_own_property(PropertyName.from_str('answer'))
	}
}

fn test_legacy_accessor_lookup_walks_descriptors_stops_at_data_and_never_invokes_callbacks() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut parent := Object.create(vm.realm(), none)
	mut middle := Object.create(vm.realm(), parent)
	mut child := Object.create(vm.realm(), middle)
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		panic('lookup must never call getter or setter')
	}, 0, PropertyName.from_str('callback'), none)
	symbol := Symbol.create(utf16_string('key'), .unique)
	for property in [Value.from_string(vm.create_string_from_str('answer')),
		Value.from_symbol(symbol)] {
		key := property.to_property_key(mut vm)!
		parent.define_direct_accessor(key, function.object, function.object, 0)
		for name in ['__lookupGetter__', '__lookupSetter__'] {
			found := legacy_accessor_call(mut vm, name, Value.from_object(child), [
				property,
			], PrimitiveObjectPrototypes{})!
			assert same_value(found, Value.from_object(function.object))
			middle.define_direct_property(key, Value.from_i32(42), 7)
			blocked := legacy_accessor_call(mut vm, name, Value.from_object(child), [
				property,
			], PrimitiveObjectPrototypes{})!
			assert blocked.is_undefined()
			assert middle.internal_delete(key)
			child.define_property_or_throw(mut vm, key, PropertyDescriptor{
				getter:       js_undefined()
				setter:       js_undefined()
				configurable: true
			})!
			missing := legacy_accessor_call(mut vm, name, Value.from_object(child), [
				property,
			], PrimitiveObjectPrototypes{})!
			assert missing.is_undefined()
			assert child.internal_delete(key)
		}
	}
	for name in ['__lookupGetter__', '__lookupSetter__'] {
		absent := legacy_accessor_call(mut vm, name, Value.from_object(child), [
			Value.from_string(vm.create_string_from_str('absent')),
		], PrimitiveObjectPrototypes{})!
		assert absent.is_undefined()
	}
}

fn test_legacy_accessor_lookup_boxes_before_converting_property_key() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut log := &LegacyAccessorLog{}
	parent := Object.create(vm.realm(), none)
	getter := fn [parent, mut log] (realm &Realm) &Object {
		log.events << 'box'
		return parent
	}
	mut key := Object.create(vm.realm(), none)
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut log] (mut vm VM) !Value {
		log.events << 'key'
		return throw_completion(Value.from_i32(77))
	}, 1, PropertyName.from_str('key'), none)
	key.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(function.object), 7)
	for name in ['__lookupGetter__', '__lookupSetter__'] {
		for receiver in [js_null(), Value.from_i32(42)] {
			if _ := legacy_accessor_call(mut vm, name, receiver, [
				Value.from_object(key),
			], PrimitiveObjectPrototypes{ number: getter })
			{
				assert false
			} else {
				if receiver.is_null() {
					assert thrown_value(err).as_object().error_message()?.str() == 'ToObject on null or undefined'
				} else {
					assert thrown_value(err).number == 77
				}
			}
		}
	}
	assert log.events == ['box', 'key', 'box', 'key']
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
