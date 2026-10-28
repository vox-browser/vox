module libjs

// Runtime/BigIntConstructor.{h,cpp}. The pinned has_constructor() is true,
// although [[Construct]] always throws. Creating this complete record requires
// its retained prototype; production global installation awaits the remaining
// Object/Intl intrinsic graph.
@[heap]
pub struct BigIntConstructor {
pub:
	object &Object
}

pub fn BigIntConstructor.create(mut vm VM, realm &Realm, bigint_prototype &Object) &BigIntConstructor {
	function := NativeFunction.create_constructor_record(mut vm, realm, realm.function_prototype,
		bigint_constructor_call, bigint_constructor_construct, PropertyName.from_str('BigInt'))
	mut object := function.object
	// JS_OBJECT/GC_CELL supplies this diagnostic name in the upstream header.
	object.class_name = 'BigIntConstructor'
	object.define_direct_property(PropertyName.from_str('prototype'),
		Value.from_object(bigint_prototype), 0)
	for index, name in ['asIntN', 'asUintN'] {
		behaviour := [NativeFunctionPointer(bigint_constructor_as_int_n),
			NativeFunctionPointer(bigint_constructor_as_uint_n)][index]
		method := NativeFunction.create_raw(mut vm, realm, realm.function_prototype, behaviour, 2,
			PropertyName.from_str(name), none)
		object.define_direct_property(PropertyName.from_str(name),
			Value.from_object(method.object), attribute_writable | attribute_configurable)
	}
	object.set_function_length(1)
	// Runtime/Intrinsics.cpp::initialize_constructor follows the class initializer.
	object.set_function_name(mut vm, PropertyName.from_str('BigInt'), none)
	mut prototype := unsafe { bigint_prototype }
	prototype.define_direct_property(PropertyName.from_str('constructor'),
		Value.from_object(object), attribute_writable | attribute_configurable)
	return &BigIntConstructor{
		object: object
	}
}

// Runtime/BigIntConstructor.cpp::call. ToPrimitive runs once with the number
// hint; NumberToBigInt accepts integral Numbers that ToBigInt would reject.
pub fn bigint_constructor_call(mut vm VM) !Value {
	primitive := vm.argument(0).to_primitive_with_hint(mut vm, .number)!
	if primitive.is_number() {
		return Value.from_bigint(number_to_bigint(mut vm, primitive)!)
	}
	return Value.from_bigint(primitive.to_bigint(mut vm)!)
}

fn bigint_constructor_construct(mut vm VM, _ &Object) !&Object {
	return vm.throw_error_type(.type_error, .not_a_constructor, 'BigInt')
}
