module libjs

// Runtime/StringPrototype.cpp::symbol_iterator. Its StringIterator record is
// translated; retain the current realm's iterator intrinsic as a dependency.
pub fn string_prototype_symbol_iterator(mut vm VM, prototype IntrinsicPrototypeGetter) !Value {
	realm := vm.realm()
	value := require_object_coercible(mut vm, vm.this_value())!
	text := value.to_primitive_string(mut vm)!
	return Value.from_object(StringIterator.create(realm, text.utf16, prototype(realm)).object)
}
