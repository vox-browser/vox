// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Runtime/ArrayPrototype.cpp::fill. Snapshot length before converting bounds,
// then use ordinary Set with Throw for holes, inherited setters and failures.
fn array_prototype_fill(mut vm VM) !Value {
	mut object, length := array_receiver(mut vm)!
	value := vm.argument(0)
	start := relative_array_index(mut vm, vm.argument(1), length)!
	end := if vm.argument(2).is_undefined() { length } else { relative_array_index(mut vm, vm.argument(2), length)! }
	for index := start; index < end; index++ {
		vm.consume_execution_budget()!
		object.set(mut vm, array_index_key(index), value, .yes)!
	}
	return Value.from_object(object)
}
