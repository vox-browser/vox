// SPDX-License-Identifier: BSD-2-Clause
module libjs

// ArrayPrototype.cpp::flat_map / FlattenIntoArray. Only actual arrays flatten;
// callbacks visit present source indices and are never reapplied to children.
fn array_prototype_flat_map(mut vm VM) !Value {
	object, length := array_receiver(mut vm)!
	mapper := vm.argument(0)
	if !mapper.is_function() { return vm.throw_error_type(.type_error, .not_a_function, mapper.str()) }
	this_argument := vm.argument(1)
	mut result := array_species_create(mut vm, object, 0)!
	flatten_into_array(mut vm, mut result, object, length, 0, 1, mapper, this_argument)!
	return Value.from_object(result)
}

fn flatten_into_array(mut vm VM, mut target Object, source &Object, length u64, start u64, depth f64, mapper Value, this_argument Value) !u64 {
	mut target_index := start
	for index := u64(0); index < length; index++ {
		vm.consume_execution_budget()!
		key := array_index_key(index)
		if !source.internal_has_property(key) { continue }
		mut value := source.get(mut vm, key)!
		if !mapper.is_undefined() {
			value = call(mut vm, mapper, this_argument, [value, Value.from_f64(f64(index)), Value.from_object(source)])!
		}
		if depth > 0 && value.is_array(mut vm)! {
			if vm.stack_info_.size_free() < 512 * 1024 { return vm.throw_error_type(.internal_error, .call_stack_size_exceeded) }
			child := value.as_object()
			child_length := length_of_array_like(mut vm, child)!
			target_index = flatten_into_array(mut vm, mut target, child, child_length, target_index, depth - 1, js_undefined(), js_undefined())!
			continue
		}
		if target_index >= 9007199254740991 { return vm.throw_error(.type_error, 'Flattened array-like index exceeds maximum safe integer') }
		target.create_data_property_or_throw(mut vm, array_index_key(target_index), value)!
		target_index++
	}
	return target_index
}
