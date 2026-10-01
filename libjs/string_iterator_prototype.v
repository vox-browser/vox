module libjs

// Runtime/StringIteratorPrototype.{h,cpp}. Both the Iterator parent and the
// Object parent of result records are supplied explicitly; this does not
// install a substitute for either pending intrinsic.
@[heap]
pub struct StringIteratorPrototype {
pub:
	object &Object
}

pub fn StringIteratorPrototype.create(mut vm VM, realm &Realm, iterator_prototype &Object, result_prototype ?&Object) &StringIteratorPrototype {
	mut object := Object.create(realm, iterator_prototype)
	next := NativeFunction.create(mut vm, realm, realm.function_prototype,
		fn [result_prototype] (mut vm VM) !Value {
		receiver := vm.this_value()
		if receiver.is_object() {
			if mut iterator := receiver.as_object().string_iterator {
				result := iterator.next(mut vm)
				return Value.from_object(create_iterator_result_object(vm.realm(), result.value,
					result.done, result_prototype))
			}
		}
		return vm.throw_error_type(.type_error, .not_an_object_of_type, 'StringIterator')
	}, 0, PropertyName.from_str('next'), none)
	object.define_direct_property(PropertyName.from_str('next'), Value.from_object(next.object),
		attribute_writable | attribute_configurable)
	object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()),
		Value.from_string(vm.create_string_from_str('String Iterator')), attribute_configurable)
	return &StringIteratorPrototype{object: object}
}
