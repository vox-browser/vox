module libjs

// Runtime/Iterator.cpp::get_iterator_values. A callback's optional completion
// requests an early stop and closes the iterator; an iteration error is returned
// directly. The acquisition boundary currently accepts object receivers.
pub type IteratorValueCallback = fn (mut vm VM, value Value) ?Completion

pub fn get_iterator_values(mut vm VM, iterable &Object, callback IteratorValueCallback) Completion {
	mut record := get_iterator_sync(mut vm, iterable) or { return completion_from_error(err) }
	for {
		next := iterator_step_value(mut vm, mut record) or { return completion_from_error(err) }
		if next.done { return normal_completion(js_undefined()) }
		if completion := callback(mut vm, next.value) {
			return iterator_close(mut vm, record, completion)
		}
	}
	return normal_completion(js_undefined())
}

// 7.3.36 SetterThatIgnoresPrototypeProperties. The own descriptor is inspected
// before deciding whether to create a property or use the ordinary Set path.
pub fn setter_that_ignores_prototype_properties(mut vm VM, receiver Value, home &Object, key PropertyName, value Value) ! {
	if !receiver.is_object() { return vm.throw_error_type(.type_error, .not_an_object, receiver.str()) }
	mut object := receiver.as_object()
	if voidptr(object) == voidptr(home) {
		return vm.throw_error_type(.type_error, .desc_write_non_writable, receiver.str())
	}
	if object.internal_get_own_property(key) == none {
		object.create_data_property_or_throw(mut vm, key, value)!
	} else {
		object.set(mut vm, key, value, .yes)!
	}
}
