module libjs

// Runtime/BooleanConstructor.{h,cpp}. NativeFunction supplies the subclass's
// [[Call]] and [[Construct]] contexts; these callbacks translate its bodies.
@[heap]
pub struct BooleanConstructor {
pub:
	object &Object
}

pub fn BooleanConstructor.create(mut vm VM, realm &Realm) &BooleanConstructor {
	function := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype,
		boolean_constructor_call, boolean_constructor_construct, 1, PropertyName.from_str('Boolean'))
	mut object := function.object
	object.define_direct_property(PropertyName.from_str('prototype'),
		Value.from_object(realm.boolean_prototype_record()), 0)
	return &BooleanConstructor{object: object}
}

fn boolean_constructor_call(mut vm VM) !Value {
	return Value.from_bool(vm.argument(0).to_boolean())
}

fn boolean_constructor_prototype(realm &Realm) &Object {
	return realm.boolean_prototype_record()
}

fn boolean_constructor_construct(mut vm VM, new_target &Object) !&Object {
	boolean := vm.argument(0).to_boolean()
	prototype := get_prototype_from_constructor(mut vm, new_target, boolean_constructor_prototype)!
	// AbstractOperations.h::ordinary_create_from_constructor allocates in the
	// current realm, after choosing the prototype from the new target's realm.
	return BooleanObject.create_with_prototype(vm.realm(), boolean, prototype).object
}
