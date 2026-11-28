// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn array_prototype_sort(mut vm VM) !Value {
	callback := vm.argument(0)
	if !callback.is_undefined() && !callback.is_function() { return vm.throw_error_type(.type_error, .not_a_function, callback.str()) }
	mut object, length := array_receiver(mut vm)!
	compare := fn [callback] (mut vm VM, x Value, y Value) !f64 {
		vm.consume_execution_budget()!
		return compare_array_elements(mut vm, x, y, if callback.is_undefined() { ?&Object(none) } else { ?&Object(callback.as_object()) })
	}
	sorted := sort_indexed_properties(mut vm, object, length, compare, .skip_holes)!
	for index, value in sorted {
		vm.consume_execution_budget()!
		object.set(mut vm, array_index_key(u64(index)), value, .yes)!
	}
	for index := u64(sorted.len); index < length; index++ {
		vm.consume_execution_budget()!
		object.delete_property_or_throw(mut vm, array_index_key(index))!
	}
	return Value.from_object(object)
}
