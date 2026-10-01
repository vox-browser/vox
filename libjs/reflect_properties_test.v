module libjs

@[heap]
struct ReflectPropertyLog {
mut:
	events []string
}

fn reflect_property_call(mut vm VM, name string, arguments []Value, prototype ?&Object) !Value {
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [name, prototype] (mut vm VM) !Value {
		return match name {
			'defineProperty' { reflect_define_property(mut vm) }
			'deleteProperty' { reflect_delete_property(mut vm) }
			'get' { reflect_get(mut vm) }
			'getOwnPropertyDescriptor' { reflect_get_own_property_descriptor(mut vm, prototype) }
			'has' { reflect_has(mut vm) }
			'set' { reflect_set(mut vm) }
			else { panic('fixture method') }
		}
	}, 0, PropertyName.from_str(name), none)
	return call(mut vm, Value.from_object(function.object), js_null(), arguments)
}

fn test_reflect_properties_validate_targets_before_keys_and_preserve_abrupt_key_conversion() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut log := &ReflectPropertyLog{}
	mut key := Object.create(vm.realm(), none)
	conversion := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut log] (mut vm VM) !Value {
		log.events << 'key'
		assert vm.argument(0).as_string().str() == 'string'
		return throw_completion(Value.from_i32(77))
	}, 1, PropertyName.from_str('key'), none)
	key.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(conversion.object), 7)
	object := Object.create(vm.realm(), none)
	for name in ['defineProperty', 'deleteProperty', 'get', 'getOwnPropertyDescriptor', 'has',
		'set'] {
		for target in [js_null(), js_undefined(), Value.from_i32(42),
			Value.from_bool(true), Value.from_string(vm.create_string_from_str('abc'))] {
			if _ := reflect_property_call(mut vm, name, [target, Value.from_object(key)], none) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_message()?.str() == '${target.str()} is not an object'
			}
		}
		assert log.events.len == 0
		if _ := reflect_property_call(mut vm, name, [Value.from_object(object),
			Value.from_object(key)], none)
		{
			assert false
		} else {
			assert thrown_value(err).number == 77
		}
		assert log.events == ['key']
		log.events.clear()
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_reflect_define_property_converts_key_then_descriptor_before_returning_boolean_failures() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut log := &ReflectPropertyLog{}
	mut object := Object.create(vm.realm(), none)
	object.define_direct_property(PropertyName.from_str('answer'), Value.from_i32(42), 0)
	mut key := Object.create(vm.realm(), none)
	conversion := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut log] (mut vm VM) !Value {
		log.events << 'key'
		return Value.from_string(vm.create_string_from_str('answer'))
	}, 1, PropertyName.from_str('key'), none)
	key.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(conversion.object), 7)
	mut descriptor := Object.create(vm.realm(), none)
	for name in ['enumerable', 'configurable', 'value', 'writable'] {
		descriptor.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str(name), fn [name, mut log] (mut vm VM) !Value {
			log.events << name
			return if name == 'value' { Value.from_i32(77) } else { Value.from_bool(false) }
		}, unsafe { nil }, 0, vm.realm().function_prototype)
	}
	result := reflect_property_call(mut vm, 'defineProperty', [
		Value.from_object(object),
		Value.from_object(key),
		Value.from_object(descriptor),
	], none)!
	assert !result.as_bool()
	assert log.events == ['key', 'enumerable', 'configurable', 'value', 'writable']
	assert object.get(mut vm, PropertyName.from_str('answer'))!.number == 42
	log.events.clear()
	descriptor.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('value'), fn [mut log] (mut vm VM) !Value {
		log.events << 'value'
		return throw_completion(Value.from_i32(99))
	}, unsafe { nil }, 0, vm.realm().function_prototype)
	if _ := reflect_property_call(mut vm, 'defineProperty', [
		Value.from_object(object),
		Value.from_object(key),
		Value.from_object(descriptor),
	], none)
	{
		assert false
	} else {
		assert thrown_value(err).number == 99
	}
	assert log.events == ['key', 'enumerable', 'configurable', 'value']
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_reflect_get_and_set_distinguish_absent_receiver_from_explicit_undefined_and_preserve_inherited_accessors() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut parent := Object.create(vm.realm(), none)
	mut child := Object.create(vm.realm(), parent)
	for receiver in [Value.from_object(child), js_undefined(),
		js_null(), Value.from_i32(42)] {
		parent.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('answer'), fn [receiver] (mut vm VM) !Value {
			assert same_value(vm.this_value(), receiver)
			return Value.from_i32(77)
		}, fn [receiver] (mut vm VM) !Value {
			assert same_value(vm.this_value(), receiver)
			assert vm.argument(0).number == 99
			return throw_completion(Value.from_i32(55))
		}, 0, vm.realm().function_prototype)
		mut read_arguments := [Value.from_object(child),
			Value.from_string(vm.create_string_from_str('answer'))]
		mut write_arguments := [Value.from_object(child), read_arguments[1], Value.from_i32(99)]
		if !receiver.is_object() {
			read_arguments << receiver
			write_arguments << receiver
		}
		read := reflect_property_call(mut vm, 'get', read_arguments, none)!
		assert read.number == 77
		if _ := reflect_property_call(mut vm, 'set', write_arguments, none) {
			assert false
		} else {
			assert thrown_value(err).number == 55
		}
	}
	parent.define_direct_property(PropertyName.from_str('value'), Value.from_i32(1), 7)
	key := Value.from_string(vm.create_string_from_str('value'))
	result := reflect_property_call(mut vm, 'set', [Value.from_object(parent), key,
		Value.from_i32(42), Value.from_object(child)], none)!
	assert result.as_bool()
	assert child.get(mut vm, PropertyName.from_str('value'))!.number == 42
	assert parent.get(mut vm, PropertyName.from_str('value'))!.number == 1
	primitive := reflect_property_call(mut vm, 'set', [Value.from_object(parent), key,
		Value.from_i32(77), js_undefined()], none)!
	assert !primitive.as_bool()
	parent.define_direct_property(PropertyName.from_str('fixed'), Value.from_i32(1), 0)
	fixed := reflect_property_call(mut vm, 'set', [Value.from_object(parent),
		Value.from_string(vm.create_string_from_str('fixed')),
		Value.from_i32(77)], none)!
	assert !fixed.as_bool()
}

fn test_reflect_has_delete_and_descriptor_read_use_symbols_and_do_not_invoke_accessors() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut parent := Object.create(vm.realm(), none)
	parent.define_direct_property(PropertyName.from_str('inherited'), Value.from_i32(42), 7)
	mut object := Object.create(vm.realm(), parent)
	callback := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
		panic('descriptor and membership operations do not call accessors')
	}, 0, PropertyName.from_str('getter'), none)
	symbol := Symbol.create(utf16_string('key'), .unique)
	object.define_direct_accessor(PropertyName.from_symbol(symbol), callback.object, none, 0)
	inherited := Value.from_string(vm.create_string_from_str('inherited'))
	found := reflect_property_call(mut vm, 'has', [Value.from_object(object), inherited], parent)!
	assert found.as_bool()
	missing := reflect_property_call(mut vm, 'getOwnPropertyDescriptor', [
		Value.from_object(object),
		inherited,
	], parent)!
	assert missing.is_undefined()
	descriptor := reflect_property_call(mut vm, 'getOwnPropertyDescriptor', [
		Value.from_object(object),
		Value.from_symbol(symbol),
	], parent)!.as_object()
	assert voidptr(descriptor.prototype?) == voidptr(parent)
	assert descriptor.own_property_keys().map(it.str()) == ['get', 'set', 'enumerable',
		'configurable']
	assert same_value(descriptor.get(mut vm, PropertyName.from_str('get'))!,
		Value.from_object(callback.object))
	assert descriptor.get(mut vm, PropertyName.from_str('set'))!.is_undefined()
	deleted := reflect_property_call(mut vm, 'deleteProperty', [
		Value.from_object(object),
		Value.from_symbol(symbol),
	], none)!
	assert !deleted.as_bool()
	absent := reflect_property_call(mut vm, 'deleteProperty', [
		Value.from_object(object),
		inherited,
	], none)!
	assert absent.as_bool() && parent.has_own_property(PropertyName.from_str('inherited'))
	object.define_direct_property(PropertyName.from_str('removable'), Value.from_i32(1), 7)
	removed := reflect_property_call(mut vm, 'deleteProperty', [
		Value.from_object(object),
		Value.from_string(vm.create_string_from_str('removable')),
	], none)!
	assert removed.as_bool() && !object.has_own_property(PropertyName.from_str('removable'))
}
