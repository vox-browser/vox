module libjs

// Runtime/SymbolPrototype.{h,cpp}. Unlike Boolean.prototype, this ordinary
// prototype has no primitive-data slot. Its Object prototype is explicit until
// that intrinsic is translated.
@[heap]
pub struct SymbolPrototype {
pub:
	object &Object
}

pub fn SymbolPrototype.create(mut vm VM, realm &Realm, object_prototype ?&Object) &SymbolPrototype {
	mut object := Object.create(realm, object_prototype)
	for name, behaviour in {
		'toString': NativeFunctionPointer(symbol_prototype_to_string)
		'valueOf': NativeFunctionPointer(symbol_prototype_value_of)
	} {
		function := NativeFunction.create_raw(mut vm, realm, realm.function_prototype,
			behaviour, 0, PropertyName.from_str(name), none)
		object.define_direct_property(PropertyName.from_str(name), Value.from_object(function.object),
			attribute_writable | attribute_configurable)
	}
	object.define_native_accessor(mut vm, realm, PropertyName.from_str('description'),
		symbol_prototype_description, unsafe { nil }, attribute_configurable, realm.function_prototype)
	key := PropertyName.from_symbol(vm.well_known_symbol_to_primitive())
	primitive := NativeFunction.create_raw(mut vm, realm, realm.function_prototype,
		symbol_prototype_to_primitive, 1, key, none)
	object.define_direct_property(key, Value.from_object(primitive.object), attribute_configurable)
	object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()),
		Value.from_string(vm.create_string_from_str('Symbol')), attribute_configurable)
	return &SymbolPrototype{object: object}
}

fn this_symbol_value(mut vm VM, value Value) !&Symbol {
	if value.is_symbol() { return value.as_symbol() }
	if value.is_object() {
		if wrapper := value.as_object().symbol_object { return wrapper.symbol }
	}
	return vm.throw_error_type(.type_error, .not_an_object_of_type, 'Symbol')
}

fn symbol_prototype_description(mut vm VM) !Value {
	symbol := this_symbol_value(mut vm, vm.this_value())!
	if description := symbol.description { return Value.from_string(vm.create_string(description)) }
	return js_undefined()
}

fn symbol_prototype_to_string(mut vm VM) !Value {
	symbol := this_symbol_value(mut vm, vm.this_value())!
	return Value.from_string(vm.create_string(symbol.descriptive_string()))
}

fn symbol_prototype_value_of(mut vm VM) !Value {
	symbol := this_symbol_value(mut vm, vm.this_value())!
	return Value.from_symbol(symbol)
}

fn symbol_prototype_to_primitive(mut vm VM) !Value {
	// The hint is ignored, without conversion or validation.
	symbol := this_symbol_value(mut vm, vm.this_value())!
	return Value.from_symbol(symbol)
}
