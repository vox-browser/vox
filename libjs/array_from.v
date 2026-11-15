// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Runtime/ArrayConstructor.cpp::from, synchronous iterable and array-like paths.
// Construction is generic and precedes acquiring an iterator. Mapper/property
// failures close acquired iterators; step/value and final-length failures do not.
fn array_constructor_from(mut vm VM) !Value {
	items, mapper, receiver, constructor := vm.argument(0), vm.argument(1), vm.argument(2), vm.this_value()
	if !mapper.is_undefined() && !mapper.is_function() { return vm.throw_error_type(.type_error, .not_a_function, mapper.str()) }
	method := items.get_method_with_prototypes(mut vm, PropertyName.from_symbol(vm.well_known_symbol_iterator()), realm_primitive_prototypes())!
	if !method.is_undefined() {
		mut result := array_from_create(mut vm, constructor, none)!
		mut iterator := get_iterator_from_method(mut vm, items, method)!
		mut index := u64(0)
		for {
			vm.consume_execution_budget() or { return iterator_close(mut vm, iterator, completion_from_error(err)).release_error() }
			if index >= 9007199254740991 {
				failure := vm.throw_error(.type_error, 'Array-like length exceeds maximum safe integer')
				return iterator_close(mut vm, iterator, completion_from_error(failure)).release_error()
			}
			step := iterator_step_value(mut vm, mut iterator)!
			if step.done {
				result.set(mut vm, PropertyName.from_str('length'), Value.from_f64(f64(index)), .yes)!
				return Value.from_object(result)
			}
			mapped := if mapper.is_undefined() { step.value } else {
				call(mut vm, mapper, receiver, [step.value, Value.from_f64(f64(index))]) or {
					return iterator_close(mut vm, iterator, completion_from_error(err)).release_error()
				}
			}
			result.create_data_property_or_throw(mut vm, array_index_key(index), mapped) or {
				return iterator_close(mut vm, iterator, completion_from_error(err)).release_error()
			}
			index++
		}
	}
	object := items.to_object_with_prototypes(mut vm, realm_primitive_prototypes())!
	length := length_of_array_like(mut vm, object)!
	mut result := array_from_create(mut vm, constructor, length)!
	for index := u64(0); index < length; index++ {
		vm.consume_execution_budget()!
		key := array_index_key(index)
		value := object.get(mut vm, key)!
		mapped := if mapper.is_undefined() { value } else { call(mut vm, mapper, receiver, [value, Value.from_f64(f64(index))])! }
		result.create_data_property_or_throw(mut vm, key, mapped)!
	}
	result.set(mut vm, PropertyName.from_str('length'), Value.from_f64(f64(length)), .yes)!
	return Value.from_object(result)
}

fn array_from_create(mut vm VM, constructor Value, length ?u64) !&Object {
	if constructor.is_constructor() {
		arguments := if count := length { [Value.from_f64(f64(count))] } else { []Value{} }
		return construct(mut vm, constructor, arguments, none)
	}
	return ArrayObject.create(mut vm, vm.realm(), length or { 0 }, vm.realm().array_prototype_record())!.object
}
