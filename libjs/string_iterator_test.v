module libjs

fn test_string_iterator_yields_code_points_preserves_lone_surrogates_and_stays_done() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	result_parent := Object.create(vm.realm(), none)
	prototype := StringIteratorPrototype.create(mut vm, vm.realm(), parent, result_parent)
	mut source := Utf16String.from_slice([u16(`A`), 0xd83d, 0xde00, 0xd800, 0, 0xdc00])
	mut iterator := StringIterator.create(vm.realm(), source, prototype.object)
	source.data[0] = u16(`Z`)
	assert iterator.object.own_property_keys().len == 0
	assert voidptr(iterator.object.prototype?) == voidptr(prototype.object)
	assert iterator.object.class_name == 'StringIterator'
	assert iterator.text.data[0] == u16(`A`)
	method := iterator.object.get(mut vm, PropertyName.from_str('next'))!
	expected := [[u16(`A`)], [u16(0xd83d), 0xde00], [u16(0xd800)], [u16(0)], [u16(0xdc00)]]
	for index, units in expected {
		value := call(mut vm, method, Value.from_object(iterator.object), []Value{})!
		result := value.as_object()
		assert voidptr(result.prototype?) == voidptr(result_parent)
		assert !iterator_complete(mut vm, result)!
		assert iterator_value(mut vm, result)!.as_string().utf16.data == units
		assert !iterator.done
		assert iterator.index == if index == 0 { 1 } else { index + 2 }
	}
	for _ in 0 .. 2 {
		value := call(mut vm, method, Value.from_object(iterator.object), []Value{})!
		result := value.as_object()
		assert iterator_complete(mut vm, result)!
		assert iterator_value(mut vm, result)!.is_undefined()
		assert iterator.done && iterator.index == 6
	}
	mut empty := StringIterator.create(vm.realm(), Utf16String.new(), prototype.object)
	assert empty.next(mut vm).done && empty.done
}

fn test_string_iterator_prototype_has_native_metadata_tag_and_unforgeable_brand() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	prototype := StringIteratorPrototype.create(mut vm, vm.realm(), parent, none)
	assert voidptr(prototype.object.prototype?) == voidptr(parent)
	assert prototype.object.own_property_keys().map(it.str()) == ['next', 'Symbol(Symbol.toStringTag)']
	key := PropertyName.from_str('next')
	descriptor := prototype.object.internal_get_own_property(key)?
	assert descriptor.writable? && descriptor.configurable? && !descriptor.enumerable?
	method := descriptor.value?
	assert method.as_object().get(mut vm, PropertyName.from_str('name'))!.as_string().str() == 'next'
	assert method.as_object().get(mut vm, PropertyName.from_str('length'))!.number == 0
	tag := prototype.object.internal_get_own_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()))?
	assert !tag.writable? && !tag.enumerable? && tag.configurable?
	assert tag.value?.as_string().str() == 'String Iterator'
	mut fake := Object.create(vm.realm(), prototype.object)
	fake.class_name = 'StringIterator'
	for receiver in [js_undefined(), js_null(), Value.from_i32(1),
		Value.from_string(vm.create_string_from_str('x')), Value.from_object(fake),
		Value.from_object(prototype.object)] {
		if _ := call(mut vm, method, receiver, []Value{}) { assert false } else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}

fn test_string_iterator_records_collect_through_cached_next_and_respect_replacement() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	prototype := StringIteratorPrototype.create(mut vm, vm.realm(), parent, none)
	iterator := StringIterator.create(vm.realm(), utf16_string('hi'), prototype.object)
	mut record := get_iterator_direct(mut vm, iterator.object)!
	mut object := iterator.object
	replacement := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype,
		fn (mut vm VM) !Value { return throw_completion(Value.from_i32(17)) },
		0, PropertyName.from_str('next'), none)
	object.define_direct_property(PropertyName.from_str('next'), Value.from_object(replacement.object), 7)
	values := iterator_to_list(mut vm, mut record)!
	// Current V formats a reference's str() inside map() as `&` plus the value.
	mut texts := []string{}
	for value in values {
		texts << value.as_string().str()
	}
	assert texts == ['h', 'i']
	assert record.done && iterator.done
	mut changed := get_iterator_direct(mut vm, iterator.object)!
	if _ := iterator_step_value(mut vm, mut changed) { assert false } else {
		assert thrown_value(err).number == 17
	}
	assert changed.done
	// No builtin fast path may bypass a user-supplied return method.
	return_method := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype,
		fn (mut vm VM) !Value { return throw_completion(Value.from_i32(42)) },
		0, PropertyName.from_str('return'), none)
	object.define_direct_property(PropertyName.from_str('return'), Value.from_object(return_method.object), 7)
	closed := iterator_close(mut vm, record, normal_completion(js_undefined()))
	assert closed.is_error() && closed.value.number == 42
}
