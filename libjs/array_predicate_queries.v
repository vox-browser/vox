// SPDX-License-Identifier: BSD-2-Clause
module libjs

// ArrayPrototype.cpp::find/some. Both snapshot length and stop at the first
// truthy callback result. Find visits holes with Get; some first uses HasProperty.
fn array_prototype_find(mut vm VM) !Value { return array_predicate_query(mut vm, true) }
fn array_prototype_some(mut vm VM) !Value { return array_predicate_query(mut vm, false) }

fn array_predicate_query(mut vm VM, find bool) !Value {
	object, length := array_receiver(mut vm)!
	callback := vm.argument(0)
	if !callback.is_function() { return vm.throw_error_type(.type_error, .not_a_function, callback.str()) }
	this_argument := vm.argument(1)
	for index := u64(0); index < length; index++ {
		vm.consume_execution_budget()!
		key := array_index_key(index)
		if !find && !object.has_property_checked(mut vm, key)! { continue }
		value := object.get(mut vm, key)!
		if call(mut vm, callback, this_argument, [value, Value.from_f64(f64(index)), Value.from_object(object)])!.to_boolean() {
			return if find { value } else { Value.from_bool(true) }
		}
	}
	return if find { js_undefined() } else { Value.from_bool(false) }
}
