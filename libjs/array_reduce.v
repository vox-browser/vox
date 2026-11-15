// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Runtime/ArrayPrototype.cpp::reduce/reduce_right. Snapshot length, then use
// live HasProperty/Get for both the initial seed and each subsequent element.
fn array_prototype_reduce(mut vm VM) !Value { return array_reduce(mut vm, false) }
fn array_prototype_reduce_right(mut vm VM) !Value { return array_reduce(mut vm, true) }

fn array_reduce(mut vm VM, reverse bool) !Value {
	object, length := array_receiver(mut vm)!
	callback := vm.argument(0)
	if !callback.is_function() { return vm.throw_error_type(.type_error, .not_a_function, callback.str()) }
	mut accumulator := vm.argument(1)
	mut seeded := vm.argument_count() > 1
	// An exclusive remaining range avoids a signed -1 sentinel and keeps all
// indices through 2^53-2 representable in either direction.
	mut remaining := length
	for remaining > 0 {
		vm.consume_execution_budget()!
		index := if reverse { remaining - 1 } else { length - remaining }
		remaining--
		key := array_index_key(index)
		if !object.internal_has_property(key) { continue }
		value := object.get(mut vm, key)!
		if !seeded {
			accumulator = value
			seeded = true
		} else {
			accumulator = call(mut vm, callback, js_undefined(), [accumulator, value,
				Value.from_f64(f64(index)), Value.from_object(object)])!
		}
	}
	if !seeded { return vm.throw_error_type(.type_error, .reduce_no_initial) }
	return accumulator
}
