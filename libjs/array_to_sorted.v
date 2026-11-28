// SPDX-License-Identifier: BSD-2-Clause
module libjs

// ArrayPrototype.cpp::to_sorted. Read through holes into a dense intrinsic
// array, using the shared stable sorter without touching source or @@species.
fn array_prototype_to_sorted(mut vm VM) !Value {
	callback := vm.argument(0)
	if !callback.is_undefined() && !callback.is_function() { return vm.throw_error_type(.type_error, .not_a_function, callback.str()) }
	object, length := array_receiver(mut vm)!
	mut result := ArrayObject.create(mut vm, vm.realm(), length, vm.realm().array_prototype_record())!.object
	compare := fn [callback] (mut vm VM, x Value, y Value) !f64 {
		vm.consume_execution_budget()!
		return compare_array_elements(mut vm, x, y, if callback.is_undefined() { ?&Object(none) } else { ?&Object(callback.as_object()) })
	}
	sorted := sort_indexed_properties(mut vm, object, length, compare, .read_through_holes)!
	for index, value in sorted {
		vm.consume_execution_budget()!
		result.create_data_property_or_throw(mut vm, array_index_key(u64(index)), value)!
	}
	return Value.from_object(result)
}
