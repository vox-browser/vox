// SPDX-License-Identifier: BSD-2-Clause
module libjs

// ObjectConstructor.cpp::from_entries / AddEntriesFromIterable. Entry property
// reads precede ToPropertyKey, and entry-processing errors close the iterator
// while preserving the original thrown value.
fn object_constructor_from_entries(mut vm VM) !Value {
	iterable := vm.argument(0)
	if iterable.is_nullish() { return vm.throw_error_type(.type_error, .to_object_null_or_undefined) }
	mut object := Object.create(vm.realm(), vm.realm().object_prototype)
	mut iterator := get_iterator_sync_value(mut vm, iterable)!
	for {
		vm.consume_execution_budget()!
		step := iterator_step_value(mut vm, mut iterator)!
		if step.done { return Value.from_object(object) }
		object_from_entries_add(mut vm, mut object, step.value) or {
			return iterator_close(mut vm, iterator, completion_from_error(err)).release_error()
		}
	}
	return Value.from_object(object)
}

fn object_from_entries_add(mut vm VM, mut target Object, entry Value) ! {
	if !entry.is_object() { return vm.throw_error(.type_error, 'Object.fromEntries iterator value is not an object') }
	object := entry.as_object()
	key := object.get(mut vm, PropertyName.from_number(0))!
	value := object.get(mut vm, PropertyName.from_number(1))!
	property := key.to_property_key(mut vm)!
	target.create_data_property_or_throw(mut vm, property, value)!
}
