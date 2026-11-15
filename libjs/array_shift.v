// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn array_prototype_shift(mut vm VM) !Value {
	mut object, length := array_receiver(mut vm)!
	if length == 0 {
		object.set(mut vm, PropertyName.from_str('length'), Value.from_i32(0), .yes)!
		return js_undefined()
	}
	first := object.get(mut vm, array_index_key(0))!
	for index := u64(1); index < length; index++ {
		vm.consume_execution_budget()!
		from := array_index_key(index)
		to := array_index_key(index - 1)
		if object.has_property_checked(mut vm, from)! { object.set(mut vm, to, object.get(mut vm, from)!, .yes)! }
		else { object.delete_property_or_throw(mut vm, to)! }
	}
	object.delete_property_or_throw(mut vm, array_index_key(length - 1))!
	object.set(mut vm, PropertyName.from_str('length'), Value.from_f64(f64(length - 1)), .yes)!
	return first
}
