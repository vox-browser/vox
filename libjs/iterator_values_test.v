module libjs

@[heap]
struct IteratorValuesTestState {
mut:
	events []string
	index  int
}

fn test_iterator_values_closes_only_for_a_callback_completion() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for mode in ['all', 'callback normal', 'callback throw', 'next throw'] {
		mut state := &IteratorValuesTestState{}
		mut iterator := Object.create(vm.realm(), none)
		next := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype,
			fn [mut state, mode] (mut vm VM) !Value {
			index := state.index
			state.index++
			state.events << 'next ${index}'
			if mode == 'next throw' && index == 1 { return throw_completion(Value.from_i32(17)) }
			return Value.from_object(create_iterator_result_object(vm.realm(), Value.from_i32(index), index == 2, none))
		}, 0, PropertyName.from_str('next'), none)
		iterator.define_direct_property(PropertyName.from_str('next'), Value.from_object(next.object), 7)
		return_method := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype,
			fn [mut state] (mut vm VM) !Value {
			state.events << 'return'
			return Value.from_object(Object.create(vm.realm(), none))
		}, 0, PropertyName.from_str('return'), none)
		iterator.define_direct_property(PropertyName.from_str('return'), Value.from_object(return_method.object), 7)
		mut iterable := Object.create(vm.realm(), none)
		method := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype,
			fn [iterator] (mut vm VM) !Value { return Value.from_object(iterator) },
			0, PropertyName.from_str('iterator'), none)
		iterable.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_iterator()), Value.from_object(method.object), 7)
		result := get_iterator_values(mut vm, iterable, fn [mut state, mode] (mut vm VM, value Value) ?Completion {
			state.events << 'value ${int(value.number)}'
			if mode == 'callback normal' { return normal_completion(Value.from_i32(42)) }
			if mode == 'callback throw' { return Completion{type_: .throw_, value: Value.from_i32(9)} }
			return none
		})
		if mode == 'all' {
			assert !result.is_abrupt() && result.value.is_undefined()
			assert state.events == ['next 0', 'value 0', 'next 1', 'value 1', 'next 2']
		} else if mode == 'next throw' {
			assert result.is_error() && result.value.number == 17
			assert state.events == ['next 0', 'value 0', 'next 1']
		} else {
			assert result.type_ == if mode == 'callback throw' { CompletionType.throw_ } else { CompletionType.normal }
			assert result.value.number == if mode == 'callback throw' { 9 } else { 42 }
			assert state.events == ['next 0', 'value 0', 'return']
		}
	}
	invalid := Object.create(vm.realm(), none)
	failure := get_iterator_values(mut vm, invalid, fn (mut vm VM, value Value) ?Completion {
		panic('invalid iterable must not call the callback')
	})
	assert failure.is_error() && failure.value.as_object().error_kind()? == .type_error
}

fn test_iterator_setter_ignores_inherited_properties_and_preserves_own_setters() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut home := Object.create(vm.realm(), none)
	key := PropertyName.from_str('value')
	home.define_native_accessor(mut vm, vm.realm(), key,
		fn (mut vm VM) !Value { return throw_completion(Value.from_i32(17)) },
		fn (mut vm VM) !Value { return throw_completion(Value.from_i32(42)) },
		attribute_configurable, vm.realm().function_prototype)
	mut receiver := Object.create(vm.realm(), home)
	setter_that_ignores_prototype_properties(mut vm, Value.from_object(receiver), home, key, Value.from_i32(9))!
	assert receiver.get(mut vm, key)!.number == 9
	descriptor := receiver.internal_get_own_property(key)?
	assert descriptor.writable? && descriptor.enumerable? && descriptor.configurable?
	setter_that_ignores_prototype_properties(mut vm, Value.from_object(receiver), home, key, Value.from_i32(10))!
	assert receiver.get(mut vm, key)!.number == 10
	receiver.define_native_accessor(mut vm, vm.realm(), key, unsafe { nil },
		fn (mut vm VM) !Value { return throw_completion(vm.argument(0)) },
		attribute_configurable, vm.realm().function_prototype)
	if _ := setter_that_ignores_prototype_properties(mut vm, Value.from_object(receiver), home, key, Value.from_i32(11)) {
		assert false
	} else { assert thrown_value(err).number == 11 }
	for value in [js_undefined(), Value.from_i32(0), Value.from_object(home)] {
		if _ := setter_that_ignores_prototype_properties(mut vm, value, home, key, js_null()) {
			assert false
		} else { assert thrown_value(err).as_object().error_kind()? == .type_error }
	}
	fixed := Object.create(vm.realm(), home)
	mut fixed_object := fixed
	fixed_object.define_direct_property(key, Value.from_i32(1), 0)
	if _ := setter_that_ignores_prototype_properties(mut vm, Value.from_object(fixed), home, key, Value.from_i32(2)) {
		assert false
	} else { assert thrown_value(err).as_object().error_kind()? == .type_error }
	mut closed := Object.create(vm.realm(), home)
	assert closed.internal_prevent_extensions()
	if _ := setter_that_ignores_prototype_properties(mut vm, Value.from_object(closed), home, key, js_null()) {
		assert false
	} else { assert thrown_value(err).as_object().error_kind()? == .type_error }
}
