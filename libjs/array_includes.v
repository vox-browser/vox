// SPDX-License-Identifier: BSD-2-Clause
module libjs

// ArrayPrototype.cpp::includes uses Get (including holes) and SameValueZero.
fn array_prototype_includes(mut vm VM) !Value {
	object, length := array_receiver(mut vm)!
	if length == 0 { return Value.from_bool(false) }
	needle := vm.argument(0)
	start := relative_array_index(mut vm, vm.argument(1), length)!
	for index := start; index < length; index++ {
		vm.consume_execution_budget()!
		if same_value_zero(object.get(mut vm, array_index_key(index))!, needle) { return Value.from_bool(true) }
	}
	return Value.from_bool(false)
}
