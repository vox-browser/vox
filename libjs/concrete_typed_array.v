module libjs

// Runtime/TypedArray.cpp's JS_DEFINE_TYPED_ARRAY constructor/prototype records.
// The shared TypedArray and remaining intrinsics are explicit dependencies;
// creating these complete records does not install builtin globals in a realm.
@[heap]
pub struct ConcreteTypedArrayPrototype {
pub:
	object &Object
	kind   BufferElementType
}

pub fn ConcreteTypedArrayPrototype.create(mut vm VM, realm &Realm, kind BufferElementType, typed_array_prototype &Object, primitives PrimitiveObjectPrototypes, object_prototype &Object) &ConcreteTypedArrayPrototype {
	mut object := Object.create(realm, typed_array_prototype)
	object.define_direct_property(PropertyName.from_str('BYTES_PER_ELEMENT'),
		Value.from_f64(f64(kind.size())), 0)
	if kind == .uint8 {
		initialize_uint8_array_prototype_helpers(mut vm, realm, mut object, primitives,
			object_prototype)
	}
	return &ConcreteTypedArrayPrototype{
		object: object
		kind:   kind
	}
}

@[heap]
pub struct ConcreteTypedArrayConstructor {
pub:
	object &Object
	kind   BufferElementType
}

pub fn ConcreteTypedArrayConstructor.create(mut vm VM, realm &Realm, kind BufferElementType, typed_array_constructor &Object, concrete_prototype &Object, intrinsic_prototype IntrinsicPrototypeGetter) &ConcreteTypedArrayConstructor {
	function := NativeFunction.create_constructor_record(mut vm, realm, typed_array_constructor, fn [kind] (mut vm VM) !Value {
		return call_typed_array_constructor(mut vm, kind)
	}, fn [kind, intrinsic_prototype] (mut vm VM, target &Object) !&Object {
		return construct_typed_array(mut vm, kind, target, intrinsic_prototype)!.object
	}, PropertyName.from_str(kind.typed_array_name()))
	mut object := function.object
	object.define_direct_property(PropertyName.from_str('prototype'),
		Value.from_object(concrete_prototype), 0)
	object.define_direct_property(PropertyName.from_str('BYTES_PER_ELEMENT'),
		Value.from_f64(f64(kind.size())), 0)
	object.set_function_length(3)
	if kind == .uint8 {
		initialize_uint8_array_constructor_helpers(mut vm, realm, mut object, intrinsic_prototype)
	}
	// Intrinsics.cpp::initialize_constructor runs after the class initializer.
	object.set_function_name(mut vm, PropertyName.from_str(kind.typed_array_name()), none)
	mut prototype := unsafe { concrete_prototype }
	prototype.define_direct_property(PropertyName.from_str('constructor'),
		Value.from_object(object), attribute_writable | attribute_configurable)
	return &ConcreteTypedArrayConstructor{
		object: object
		kind:   kind
	}
}
