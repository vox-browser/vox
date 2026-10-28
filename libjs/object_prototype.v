module libjs

// Runtime/ObjectPrototype.{h,cpp}. As upstream, allocation precedes
// initialization so Function.prototype can refer to this intrinsic root.
@[heap]
pub struct ObjectPrototype {
pub:
	object &Object
}

pub fn ObjectPrototype.create(realm &Realm) &ObjectPrototype {
	mut object := Object.create(realm, none)
	object.immutable_prototype = true
	return &ObjectPrototype{ object: object }
}

pub fn (prototype &ObjectPrototype) initialize(mut vm VM, realm &Realm, primitives PrimitiveObjectPrototypes) {
	mut object := prototype.object
	names := ['hasOwnProperty', 'toString', 'toLocaleString', 'valueOf',
		'propertyIsEnumerable', 'isPrototypeOf', '__defineGetter__', '__defineSetter__',
		'__lookupGetter__', '__lookupSetter__']
	lengths := [1, 0, 0, 0, 1, 1, 2, 2, 1, 1]
	for index, name in names {
		function := NativeFunction.create(mut vm, realm, realm.function_prototype,
			fn [name, primitives] (mut vm VM) !Value {
				return match name {
					'hasOwnProperty' { object_prototype_has_own_property(mut vm, primitives)! }
					'toString' { object_prototype_to_string(mut vm, primitives)! }
					'toLocaleString' { object_prototype_to_locale_string(mut vm, primitives)! }
					'valueOf' { object_prototype_value_of(mut vm, primitives)! }
					'propertyIsEnumerable' { object_prototype_property_is_enumerable(mut vm, primitives)! }
					'isPrototypeOf' { object_prototype_is_prototype_of(mut vm, primitives)! }
					'__defineGetter__' { object_prototype_define_getter(mut vm, primitives)! }
					'__defineSetter__' { object_prototype_define_setter(mut vm, primitives)! }
					'__lookupGetter__' { object_prototype_lookup_getter(mut vm, primitives)! }
					else { object_prototype_lookup_setter(mut vm, primitives)! }
				}
			}, lengths[index], PropertyName.from_str(name), none)
		object.define_direct_property(PropertyName.from_str(name), Value.from_object(function.object),
			attribute_writable | attribute_configurable)
	}
	object.define_native_accessor(mut vm, realm, PropertyName.from_str('__proto__'),
		fn [primitives] (mut vm VM) !Value { return object_prototype_proto_getter(mut vm, primitives)! },
		object_prototype_proto_setter, attribute_configurable, realm.function_prototype)
}

// ObjectPrototype.cpp::to_string, 20.1.3.6. The tag uses observable @@toStringTag
// access after intrinsic slot classification, rather than the diagnostic name.
pub fn object_prototype_to_string(mut vm VM, primitives PrimitiveObjectPrototypes) !Value {
	value := vm.this_value()
	if value.is_undefined() { return Value.from_string(vm.create_string_from_str('[object Undefined]')) }
	if value.is_null() { return Value.from_string(vm.create_string_from_str('[object Null]')) }
	object := value.to_object_with_prototypes(mut vm, primitives)!
	builtin_tag := if Value.from_object(object).is_array(mut vm)! { 'Array' }
		else if object.callable != none { 'Function' }
		else if object.error_data != none { 'Error' }
		else if object.boolean_object != none { 'Boolean' }
		else if object.number_object != none { 'Number' }
		else if object.string_object != none { 'String' }
		else { 'Object' }
	tag := object.get(mut vm, PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()))!
	text := if tag.is_string() { tag.as_string().utf16 } else { utf16_string(builtin_tag) }
	return Value.from_string(vm.create_string(utf16_concat([utf16_string('[object '), text, utf16_string(']')])))
}
