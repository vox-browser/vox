// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Runtime/ArrayPrototype.cpp::map. Capture length, validate the callback before
// species construction, then observe live inherited indices and accessors.
fn array_prototype_map(mut vm VM) !Value {
	object, length := array_receiver(mut vm)!
	callback := vm.argument(0)
	if !callback.is_function() { return vm.throw_error_type(.type_error, .not_a_function, callback.str()) }
	this_argument := vm.argument(1)
	mut result := array_species_create(mut vm, object, length)!
	for index := u64(0); index < length; index++ {
		vm.consume_execution_budget()!
		key := array_index_key(index)
		if !object.internal_has_property(key) { continue }
		value := object.get(mut vm, key)!
		mapped := call(mut vm, callback, this_argument, [value, Value.from_f64(f64(index)), Value.from_object(object)])!
		result.create_data_property_or_throw(mut vm, key, mapped)!
	}
	return Value.from_object(result)
}
