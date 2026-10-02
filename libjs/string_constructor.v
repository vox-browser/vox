module libjs

// Runtime/StringConstructor.{h,cpp}. The complete String prototype and the
// primitive ToObject intrinsic graph remain explicit dependencies.
pub struct StringConstructorDependencies {
pub:
	prototype        &Object
	prototype_getter IntrinsicPrototypeGetter = unsafe { nil }
	primitives       PrimitiveObjectPrototypes
}

@[heap]
pub struct StringConstructor {
pub:
	object &Object
}

pub fn StringConstructor.create(mut vm VM, realm &Realm, dependencies StringConstructorDependencies) &StringConstructor {
	function := NativeFunction.create_constructor_record(mut vm, realm, realm.function_prototype,
		string_constructor_call, fn [dependencies] (mut vm VM, target &Object) !&Object {
		return string_constructor_construct(mut vm, target, dependencies.prototype_getter)
	}, PropertyName.from_str('String'))
	mut object := function.object
	object.class_name = 'StringConstructor'
	object.define_direct_property(PropertyName.from_str('prototype'),
		Value.from_object(dependencies.prototype), 0)
	raw := NativeFunction.create(mut vm, realm, realm.function_prototype, fn [dependencies] (mut vm VM) !Value {
		return string_constructor_raw(mut vm, dependencies.primitives)
	}, 1, PropertyName.from_str('raw'), none)
	object.define_direct_property(PropertyName.from_str('raw'), Value.from_object(raw.object),
		attribute_writable | attribute_configurable)
	for index, name in ['fromCharCode', 'fromCodePoint'] {
		behaviour := if index == 0 {
			NativeFunctionPointer(string_constructor_from_char_code)
		} else {
			NativeFunctionPointer(string_constructor_from_code_point)
		}
		method := NativeFunction.create_raw(mut vm, realm, realm.function_prototype, behaviour, 1,
			PropertyName.from_str(name), none)
		object.define_direct_property(PropertyName.from_str(name),
			Value.from_object(method.object), attribute_writable | attribute_configurable)
	}
	object.set_function_length(1)
	// Intrinsics.cpp::initialize_constructor follows the subclass initializer.
	object.set_function_name(mut vm, PropertyName.from_str('String'), none)
	mut prototype := dependencies.prototype
	prototype.define_direct_property(PropertyName.from_str('constructor'),
		Value.from_object(object), attribute_writable | attribute_configurable)
	return &StringConstructor{
		object: object
	}
}

// The SymbolDescriptiveString special case belongs only to [[Call]].
pub fn string_constructor_call(mut vm VM) !Value {
	if vm.argument_count() == 0 { return Value.from_string(vm.empty_string()) }
	value := vm.argument(0)
	if value.is_symbol() {
		return Value.from_string(vm.create_string(value.as_symbol().descriptive_string()))
	}
	return Value.from_string(value.to_primitive_string(mut vm)!)
}

pub fn string_constructor_construct(mut vm VM, new_target &Object, intrinsic_prototype IntrinsicPrototypeGetter) !&Object {
	text := if vm.argument_count() == 0 {
		vm.empty_string()
	} else {
		vm.argument(0).to_primitive_string(mut vm)!
	}
	prototype := get_prototype_from_constructor(mut vm, new_target, intrinsic_prototype)!
	return StringObject.create(vm.realm(), text, prototype).object
}
