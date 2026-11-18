module libjs

// Runtime/ArrayIteratorPrototype.{h,cpp}. The Iterator parent, entry-pair Array
// parent, and Object parent of result records are explicit dependency boundaries.
@[heap]
pub struct ArrayIteratorPrototype {
pub:
	object &Object
}

pub fn ArrayIteratorPrototype.create(mut vm VM, realm &Realm, iterator_prototype &Object, array_prototype &Object, result_prototype ?&Object) &ArrayIteratorPrototype {
	mut object := Object.create(realm, iterator_prototype)
	mut next := NativeFunction.create(mut vm, realm, realm.function_prototype,
		fn [array_prototype, result_prototype] (mut vm VM) !Value {
		result := array_iterator_next_value(mut vm, array_prototype)!
		return Value.from_object(create_iterator_result_object(vm.realm(), result.value,
			result.done, result_prototype))
	}, 0, PropertyName.from_str('next'), none)
	next.array_iterator_pair_prototype = array_prototype
	object.define_direct_property(PropertyName.from_str('next'), Value.from_object(next.object),
		attribute_writable | attribute_configurable)
	object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()),
		Value.from_string(vm.create_string_from_str('Array Iterator')), attribute_configurable)
	return &ArrayIteratorPrototype{object: object}
}

fn array_iterator_next_value(mut vm VM, array_prototype &Object) !IteratorStepValue {
	receiver := vm.this_value()
	if receiver.is_object() {
		if mut iterator := receiver.as_object().array_iterator {
			return iterator.next(mut vm, array_prototype)
		}
	}
	return vm.throw_error_type(.type_error, .not_an_object_of_type, 'ArrayIterator')
}

fn use_array_iterator_steps() bool {
	$if test {
		if builtin_profile_enabled { return false }
	}
	return true
}

// Internal consumers keep the original native frame for getters and errors.
// Only direct calls to next() need the ordinary result object.
fn (mut function NativeFunction) step_array_iterator(mut vm VM, receiver Value, array_prototype &Object) !IteratorStepValue {
	mut stack := vm.interpreter_stack()
	mark := stack.top()
	defer { stack.deallocate(mark) }
	function.push_call_frame(mut vm, mut stack, receiver, []Value{})!
	defer { vm.pop_current_context() }
	return array_iterator_next_value(mut vm, array_prototype)
}
