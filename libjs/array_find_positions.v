// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn array_prototype_find_index(mut vm VM) !Value { return array_directional_find(mut vm, false, true) }
fn array_prototype_find_last(mut vm VM) !Value { return array_directional_find(mut vm, true, false) }
fn array_prototype_find_last_index(mut vm VM) !Value { return array_directional_find(mut vm, true, true) }

fn array_directional_find(mut vm VM, reverse bool, position bool) !Value {
	object, length := array_receiver(mut vm)!
	callback := vm.argument(0)
	if !callback.is_function() { return vm.throw_error_type(.type_error, .not_a_function, callback.str()) }
	this_argument := vm.argument(1)
	for cursor := u64(0); cursor < length; cursor++ {
		vm.consume_execution_budget()!
		index := if reverse { length - cursor - 1 } else { cursor }
		value := object.get(mut vm, array_index_key(index))!
		if call(mut vm, callback, this_argument, [value, Value.from_f64(f64(index)), Value.from_object(object)])!.to_boolean() {
			return if position { Value.from_f64(f64(index)) } else { value }
		}
	}
	return if position { Value.from_i32(-1) } else { js_undefined() }
}

fn array_prototype_at(mut vm VM) !Value {
	object, length := array_receiver(mut vm)!
	relative := vm.argument(0).to_integer_or_infinity(mut vm)!
	index := if relative < 0 { f64(length) + relative } else { relative }
	if index < 0 || index >= f64(length) { return js_undefined() }
	return object.get(mut vm, array_index_key(u64(index)))
}
