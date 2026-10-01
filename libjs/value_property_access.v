module libjs

// Value.cpp::get (GetV), including its direct primitive-prototype lookup.
// Number, BigInt and String intrinsic dependencies are explicit until installed.
pub fn (value Value) get_with_prototypes(mut vm VM, key PropertyName, prototypes PrimitiveObjectPrototypes) !Value {
	realm := vm.realm()
	object := if value.is_string() && key != PropertyName.from_str('length') {
		assert prototypes.string != unsafe { nil }
		prototypes.string(realm)
	} else if value.is_boolean() {
		realm.boolean_prototype_record()
	} else if value.is_number() {
		assert prototypes.number != unsafe { nil }
		prototypes.number(realm)
	} else if value.is_bigint() {
		assert prototypes.bigint != unsafe { nil }
		prototypes.bigint(realm)
	} else if value.is_symbol() {
		realm.symbol_prototype_record()
	} else {
		value.to_object_with_prototypes(mut vm, prototypes)!
	}
	return object.internal_get(mut vm, key, value)
}

// Value.cpp::invoke_internal (Invoke). An absent argument list is represented
// by the empty V array; the original primitive stays the call receiver.
pub fn (value Value) invoke_with_prototypes(mut vm VM, key PropertyName, arguments []Value, prototypes PrimitiveObjectPrototypes) !Value {
	function := value.get_with_prototypes(mut vm, key, prototypes)!
	return call(mut vm, function, value, arguments)
}
