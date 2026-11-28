// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Runtime/ArrayPrototype.cpp::concat, ordinary algorithm. The shared
// ArraySpeciesCreate helper currently covers the port's single-realm graph;
// the foreign-intrinsic constructor exception remains pending.
fn array_prototype_concat(mut vm VM) !Value {
	object := vm.this_value().to_object_with_prototypes(mut vm, realm_primitive_prototypes())!
	mut result := array_species_create(mut vm, object, 0)!
	mut length := u64(0)
	length = append_concat_item(mut vm, mut result, Value.from_object(object), length)!
	for index in 0 .. vm.argument_count() {
		length = append_concat_item(mut vm, mut result, vm.argument(index), length)!
	}
	result.set(mut vm, vm.length_key(), Value.from_f64(f64(length)), .yes)!
	return Value.from_object(result)
}

fn append_concat_item(mut vm VM, mut result Object, item Value, offset u64) !u64 {
	mut length := offset
	vm.consume_execution_budget()!
	mut spreadable := false
	if item.is_object() {
		flag := item.as_object().get(mut vm, PropertyName.from_symbol(vm.well_known_symbol_is_concat_spreadable()))!
		spreadable = if flag.is_undefined() { item.is_array(mut vm)! } else { flag.to_boolean() }
	}
	if spreadable {
		object := item.as_object()
		count := length_of_array_like(mut vm, object)!
		if count > 9007199254740991 - length {
			return vm.throw_error(.type_error, 'Array-like length exceeds maximum safe integer')
		}
		for index := u64(0); index < count; index++ {
			vm.consume_execution_budget()!
			key := array_index_key(index)
			if object.has_property_checked(mut vm, key)! {
				value := object.get(mut vm, key)!
				result.create_data_property_or_throw(mut vm, array_index_key(length), value)!
			}
			length++
		}
	} else {
		if length >= 9007199254740991 {
			return vm.throw_error(.type_error, 'Array-like length exceeds maximum safe integer')
		}
		result.create_data_property_or_throw(mut vm, array_index_key(length), item)!
		length++
	}
	return length
}
