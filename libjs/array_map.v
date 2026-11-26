// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Runtime/ArrayPrototype.cpp::map. Capture length, validate the callback before
// species construction, then observe live inherited indices and accessors.
fn array_prototype_map(mut vm VM) !Value {
	object, length := array_receiver(mut vm)!
	callback := vm.argument(0)
	if !callback.is_function() { return vm.throw_error_type(.type_error, .not_a_function, callback.str()) }
	this_argument := vm.argument(1)
	constructor := array_species_constructor(mut vm, object)!
	mut result := array_create_with_species_constructor(mut vm, constructor, length)!
	mut fresh := constructor.is_undefined()
	if !fresh && constructor.is_object() {
		if intrinsic := vm.realm().array_constructor {
			fresh = voidptr(constructor.as_object()) == voidptr(intrinsic)
		}
	}
	append_elements := fresh && use_fresh_array_storage()
	for index := u64(0); index < length; index++ {
		vm.consume_execution_budget()!
		key := array_index_key(index)
		value, present := object.read_present_array_index(mut vm, key)!
		if !present { continue }
		mapped := call(mut vm, callback, this_argument, [value, Value.from_f64(f64(index)), Value.from_object(object)])!
		if append_elements {
			// Intrinsic construction returns an unpublished array with the
			// final length. Ascending indices are unique even across holes.
			result.append_fresh_array_index(key, mapped)
		} else {
			result.create_data_property_or_throw(mut vm, key, mapped)!
		}
	}
	return Value.from_object(result)
}
