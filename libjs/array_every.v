// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn array_prototype_every(mut vm VM) !Value {
	object, length := array_receiver(mut vm)!
	callback := vm.argument(0)
	if !callback.is_function() { return vm.throw_error_type(.type_error, .not_a_function, callback.str()) }
	this_argument := vm.argument(1)
	for index := u64(0); index < length; index++ {
		vm.consume_execution_budget()!
		key := array_index_key(index)
		if !object.has_property_checked(mut vm, key)! { continue }
		value := object.get(mut vm, key)!
		if !call(mut vm, callback, this_argument, [value, Value.from_f64(f64(index)), Value.from_object(object)])!.to_boolean() { return Value.from_bool(false) }
	}
	return Value.from_bool(true)
}
