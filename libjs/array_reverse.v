// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn array_prototype_reverse(mut vm VM) !Value {
	mut object, length := array_receiver(mut vm)!
	for lower := u64(0); lower < length / 2; lower++ {
		vm.consume_execution_budget()!
		low := array_index_key(lower)
		high := array_index_key(length - lower - 1)
		low_exists := object.has_property_checked(mut vm, low)!
		low_value := if low_exists { object.get(mut vm, low)! } else { js_undefined() }
		high_exists := object.has_property_checked(mut vm, high)!
		high_value := if high_exists { object.get(mut vm, high)! } else { js_undefined() }
		if low_exists && high_exists {
			object.set(mut vm, low, high_value, .yes)!
			object.set(mut vm, high, low_value, .yes)!
		} else if high_exists {
			object.set(mut vm, low, high_value, .yes)!
			object.delete_property_or_throw(mut vm, high)!
		} else if low_exists {
			object.delete_property_or_throw(mut vm, low)!
			object.set(mut vm, high, low_value, .yes)!
		}
	}
	return Value.from_object(object)
}
