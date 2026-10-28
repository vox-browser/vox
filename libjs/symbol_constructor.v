module libjs

// Runtime/SymbolConstructor.{h,cpp}. Preserve the pinned source's constructor
// internal method: IsConstructor is true, but [[Construct]] always throws for
// Symbol without converting its description argument.
@[heap]
pub struct SymbolConstructor {
pub:
	object &Object
}

pub fn SymbolConstructor.create(mut vm VM, realm &Realm) &SymbolConstructor {
	function := NativeFunction.create_constructor_record(mut vm, realm, realm.function_prototype,
		symbol_constructor_call, symbol_constructor_construct, PropertyName.from_str('Symbol'))
	mut object := function.object
	object.define_direct_property(PropertyName.from_str('prototype'),
		Value.from_object(realm.symbol_prototype_record()), 0)
	for name, behaviour in {
		'for': NativeFunctionPointer(symbol_constructor_for)
		'keyFor': NativeFunctionPointer(symbol_constructor_key_for)
	} {
		method := NativeFunction.create_raw(mut vm, realm, realm.function_prototype, behaviour,
			1, PropertyName.from_str(name), none)
		object.define_direct_property(PropertyName.from_str(name), Value.from_object(method.object),
			attribute_writable | attribute_configurable)
	}
	for index, name in well_known_symbol_names {
		object.define_direct_property(PropertyName.from_str(name),
			Value.from_symbol(vm.well_known_symbols_[index]), 0)
	}
	object.set_function_length(0)
	object.set_function_name(mut vm, PropertyName.from_str('Symbol'), none)
	return &SymbolConstructor{object: object}
}

fn symbol_constructor_call(mut vm VM) !Value {
	argument := vm.argument(0)
	if argument.is_undefined() { return Value.from_symbol(Symbol.create(none, .unique)) }
	text := argument.to_primitive_string(mut vm)!
	return Value.from_symbol(Symbol.create(text.utf16, .unique))
}

fn symbol_constructor_construct(mut vm VM, _ &Object) !&Object {
	return vm.throw_error_type(.type_error, .not_a_constructor, 'Symbol')
}

fn symbol_constructor_for(mut vm VM) !Value {
	text := vm.argument(0).to_primitive_string(mut vm)!
	if symbol := vm.global_symbol_registry_lookup(text.utf16) { return Value.from_symbol(symbol) }
	symbol := Symbol.create(text.utf16, .global)
	vm.global_symbol_registry_set(text.utf16, symbol)
	return Value.from_symbol(symbol)
}

fn symbol_constructor_key_for(mut vm VM) !Value {
	argument := vm.argument(0)
	if !argument.is_symbol() { return vm.throw_error_type(.type_error, .not_a_symbol, argument.str()) }
	if key := argument.as_symbol().key() { return Value.from_string(vm.create_string(key)) }
	return js_undefined()
}
