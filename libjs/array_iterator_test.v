module libjs

@[heap]
struct ArrayIteratorTestState {
mut:
	events []string
	length Value = Value.from_i32(2)
	nested bool
}

fn test_array_iterators_yield_sparse_inherited_values_and_real_entry_arrays() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut parent := Object.create(vm.realm(), none)
	parent.define_direct_property(PropertyName.from_number(1), Value.from_i32(17), 7)
	prototype := ArrayIteratorPrototype.create(mut vm, vm.realm(), parent, parent, parent)
	array := ArrayObject.create(mut vm, vm.realm(), 3, parent)!
	mut object := array.object
	assert object.create_data_property(mut vm, PropertyName.from_number(0), Value.from_i32(42))!
	for kind in [PropertyKind.key, .value, .key_and_value] {
		iterator := ArrayIterator.create(vm.realm(), Value.from_object(object), kind, prototype.object)
		assert iterator.object.own_property_keys().len == 0
		assert voidptr(iterator.object.prototype?) == voidptr(prototype.object)
		mut record := get_iterator_direct(mut vm, iterator.object)!
		values := iterator_to_list(mut vm, mut record)!
		assert values.len == 3 && record.done && iterator.array.is_undefined()
		for index, value in values {
			element := [Value.from_i32(42), Value.from_i32(17), js_undefined()][index]
			match kind {
				.key { assert value.number == f64(index) }
				.value { assert value == element }
				.key_and_value {
					pair := value.as_object()
					assert pair.array_object?.length == 2
					assert voidptr(pair.prototype?) == voidptr(parent)
					assert create_list_from_array_like(mut vm, value, unsafe { nil })! == [Value.from_i32(index), element]
				}
			}
		}
	}
}

fn test_array_iterator_length_is_live_and_exhaustion_releases_target_permanently() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	mut state := &ArrayIteratorTestState{}
	mut target := Object.create(vm.realm(), none)
	target.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('length'),
		fn [mut state] (mut vm VM) !Value {
		state.events << 'length'
		return state.length
	}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
	// Key iterators must never read an indexed property.
	target.define_native_accessor(mut vm, vm.realm(), PropertyName.from_number(0),
		fn (mut vm VM) !Value { return throw_completion(Value.from_i32(17)) },
		unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
	mut iterator := ArrayIterator.create(vm.realm(), Value.from_object(target), .key, parent)
	assert iterator.next(mut vm, parent)!.value.number == 0
	state.length = Value.from_i32(3)
	assert iterator.next(mut vm, parent)!.value.number == 1
	state.length = Value.from_i32(1)
	assert iterator.next(mut vm, parent)!.done
	assert iterator.array.is_undefined() && iterator.index == 2
	state.length = Value.from_i32(99)
	assert iterator.next(mut vm, parent)!.done
	assert state.events == ['length', 'length', 'length']
}

fn test_array_iterator_throws_before_or_after_index_increment_at_the_source_boundary() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for mode in ['length throws', 'length conversion throws', 'element throws'] {
		mut state := &ArrayIteratorTestState{}
		mut length := Object.create(vm.realm(), none)
		length.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('valueOf'),
			fn (mut vm VM) !Value { return throw_completion(Value.from_i32(9)) },
			unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
		mut target := Object.create(vm.realm(), none)
		target.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('length'),
			fn [mut state, mode, length] (mut vm VM) !Value {
			state.events << 'length'
			if mode == 'length throws' { return throw_completion(Value.from_i32(17)) }
			if mode == 'length conversion throws' { return Value.from_object(length) }
			return Value.from_i32(2)
		}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
		target.define_native_accessor(mut vm, vm.realm(), PropertyName.from_number(0),
			fn [mut state] (mut vm VM) !Value {
			state.events << 'element'
			return throw_completion(Value.from_i32(42))
		}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
		mut iterator := ArrayIterator.create(vm.realm(), Value.from_object(target), .value, parent)
		if _ := iterator.next(mut vm, parent) { assert false } else {
			assert thrown_value(err).number == match mode {
				'length throws' { 17 }
				'length conversion throws' { 9 }
				else { 42 }
			}
		}
		assert iterator.index == if mode == 'element throws' { u64(1) } else { u64(0) }
		assert !iterator.array.is_undefined()
		assert state.events == if mode == 'element throws' { ['length', 'element'] } else { ['length'] }
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}

fn test_array_iterator_preserves_saved_index_across_reentrant_length_access() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	mut state := &ArrayIteratorTestState{}
	mut target := Object.create(vm.realm(), none)
	mut iterator := ArrayIterator.create(vm.realm(), Value.from_object(target), .key, parent)
	target.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('length'),
		fn [mut state, mut iterator, parent] (mut vm VM) !Value {
		if !state.nested {
			state.nested = true
			assert iterator.next(mut vm, parent)!.value.number == 0
		}
		return Value.from_i32(3)
	}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
	assert iterator.next(mut vm, parent)!.value.number == 0
	assert iterator.index == 2
	assert iterator.next(mut vm, parent)!.value.number == 2
	assert iterator.next(mut vm, parent)!.done
}

fn test_array_iterator_keeps_large_numeric_indices_and_decimal_element_keys() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	mut target := Object.create(vm.realm(), none)
	target.define_direct_property(PropertyName.from_str('length'), Value.from_f64(9007199254740991), 7)
	for index in [u64(2147483647), 2147483648, 4294967295, 4294967296, 9007199254740990] {
		target.define_direct_property(PropertyName.from_str(index.str()), Value.from_i32(42), 7)
		for kind in [PropertyKind.key, .value, .key_and_value] {
			mut iterator := ArrayIterator.create(vm.realm(), Value.from_object(target), kind, parent)
			iterator.index = index
			result := iterator.next(mut vm, parent)!
			assert !result.done && iterator.index == index + 1
			match kind {
				.key { assert result.value.number == f64(index) }
				.value { assert result.value.number == 42 }
				.key_and_value {
					assert create_list_from_array_like(mut vm, result.value, unsafe { nil })! == [Value.from_f64(f64(index)), Value.from_i32(42)]
				}
			}
		}
	}
}

fn test_array_iterator_prototype_brand_descriptors_and_compiled_next_calls() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	prototype := ArrayIteratorPrototype.create(mut vm, vm.realm(), parent, parent, parent)
	assert prototype.object.own_property_keys().map(it.str()) == ['next', 'Symbol(Symbol.toStringTag)']
	method_descriptor := prototype.object.internal_get_own_property(PropertyName.from_str('next'))?
	assert method_descriptor.writable? && method_descriptor.configurable? && !method_descriptor.enumerable?
	method := method_descriptor.value?
	assert method.as_object().get(mut vm, PropertyName.from_str('name'))!.as_string().str() == 'next'
	assert method.as_object().get(mut vm, PropertyName.from_str('length'))!.number == 0
	tag := prototype.object.internal_get_own_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()))?
	assert tag.configurable? && !tag.writable? && !tag.enumerable?
	assert tag.value?.as_string().str() == 'Array Iterator'
	mut fake := Object.create(vm.realm(), prototype.object)
	fake.class_name = 'ArrayIterator'
	for receiver in [js_undefined(), Value.from_i32(1), Value.from_object(fake),
		Value.from_object(prototype.object)] {
		if _ := call(mut vm, method, receiver, []Value{}) { assert false } else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
	array := ArrayObject.create_from(mut vm, vm.realm(), [Value.from_i32(42)], parent)!
	iterator := ArrayIterator.create(vm.realm(), Value.from_object(array.object), .value, prototype.object)
	mut global := vm.realm().global_object_record()
	global.define_direct_property(PropertyName.from_str('iterator'), Value.from_object(iterator.object), 7)
	mut script := Script.parse('iterator.next().value;', vm.realm(), 'array-iterator.js', unsafe { nil })!
	assert vm.run(mut script)!.number == 42
	mut done_script := Script.parse('iterator.next().done;', vm.realm(), 'array-iterator-done.js', unsafe { nil })!
	assert vm.run(mut done_script)!.as_bool()
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
