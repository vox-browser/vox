module libjs

fn symbol_constructor_method(mut vm VM, realm &Realm, name string, arguments []Value) !Value {
	function := realm.symbol_constructor_record().get(mut vm, PropertyName.from_str(name))!
	return call(mut vm, function, js_undefined(), arguments)
}

fn test_symbol_constructor_metadata_links_static_methods_and_well_known_symbols() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	constructor := realm.symbol_constructor_record()
	prototype := realm.symbol_prototype_record()
	assert constructor.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == 'Symbol'
	assert constructor.get(mut vm, PropertyName.from_str('length'))!.number == 0
	assert constructor.internal_get_prototype_of()? == realm.function_prototype_record()
	assert Value.from_object(constructor).is_constructor() // pinned upstream has_constructor()
	mut expected_keys := ['prototype', 'for', 'keyFor']
	expected_keys << well_known_symbol_names
	expected_keys << ['length', 'name']
	assert constructor.own_property_keys().map(it.str()) == expected_keys
	prototype_descriptor := constructor.internal_get_own_property(PropertyName.from_str('prototype'))?
	assert prototype_descriptor.value?.as_object() == prototype
	assert !prototype_descriptor.writable? && !prototype_descriptor.configurable? && !prototype_descriptor.enumerable?
	assert prototype.get(mut vm, PropertyName.from_str('constructor'))!.as_object() == constructor
	global_descriptor := realm.global_object_record().internal_get_own_property(PropertyName.from_str('Symbol'))?
	assert global_descriptor.value?.as_object() == constructor
	assert global_descriptor.writable? && global_descriptor.configurable? && !global_descriptor.enumerable?
	for name in ['for', 'keyFor'] {
		descriptor := constructor.internal_get_own_property(PropertyName.from_str(name))?
		assert descriptor.writable? && descriptor.configurable? && !descriptor.enumerable?
		method := descriptor.value?.as_object()
		assert method.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == name
		assert method.get(mut vm, PropertyName.from_str('length'))!.number == 1
		assert method.internal_get_prototype_of()? == realm.function_prototype_record()
	}
	for index, name in well_known_symbol_names {
		descriptor := constructor.internal_get_own_property(PropertyName.from_str(name))?
		assert !descriptor.writable? && !descriptor.enumerable? && !descriptor.configurable?
		assert descriptor.value?.as_symbol() == vm.well_known_symbols_[index]
	}
}

fn test_symbol_call_preserves_missing_and_utf16_descriptions_and_always_creates_unique_identity() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	function := Value.from_object(vm.realm().symbol_constructor_record())
	missing := call(mut vm, function, js_null(), []Value{})!.as_symbol()
	undefined_description := call(mut vm, function, js_null(), [js_undefined()])!.as_symbol()
	assert voidptr(missing) != voidptr(undefined_description)
	assert missing.description == none && undefined_description.description == none
	for text in [Utf16String.new(), utf16_string('key'), Utf16String.from_slice([u16(0xd800), 0, 0xdc00])] {
		argument := Value.from_string(vm.create_string(text))
		first := call(mut vm, function, js_null(), [argument])!.as_symbol()
		second := call(mut vm, function, js_null(), [argument])!.as_symbol()
		assert voidptr(first) != voidptr(second) && first.kind == .unique && second.kind == .unique
		assert first.description? == text && second.description? == text
	}
	assert call(mut vm, function, js_null(), [js_null()])!.as_symbol().description?.str() == 'null'
	if _ := call(mut vm, function, js_null(), [Value.from_symbol(missing)]) { assert false }
	else { assert thrown_value(err).as_object().error_kind()? == .type_error }
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_symbol_registry_is_shared_between_realms_in_one_vm_and_retains_exact_keys() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	first_realm := vm.realm()
	second_realm := create_simple_execution_context(mut vm).realm?
	vm.pop_execution_context()
	assert first_realm.symbol_constructor_record() != second_realm.symbol_constructor_record()
	assert first_realm.symbol_prototype_record() != second_realm.symbol_prototype_record()
	for text in [utf16_string('key'), Utf16String.new(), Utf16String.from_slice([u16(0xd800)]),
		Utf16String.from_slice([u16(0xfffd)]), Utf16String.from_slice([u16(0), 0xdc00])] {
		argument := Value.from_string(vm.create_string(text))
		first := symbol_constructor_method(mut vm, first_realm, 'for', [argument])!.as_symbol()
		second := symbol_constructor_method(mut vm, second_realm, 'for', [argument])!.as_symbol()
		assert first == second && first.is_global()
		assert first.description? == text
		key := symbol_constructor_method(mut vm, first_realm, 'keyFor', [Value.from_symbol(first)])!
		assert key.as_string().utf16 == text
	}
	assert vm.global_symbol_registry().len == 5
	default_key := symbol_constructor_method(mut vm, first_realm, 'for', []Value{})!
	assert symbol_constructor_method(mut vm, first_realm, 'keyFor', [default_key])!.as_string().str() == 'undefined'
	for symbol in [Symbol.create(utf16_string('key'), .unique), vm.well_known_symbol_iterator()] {
		assert symbol_constructor_method(mut vm, first_realm, 'keyFor', [Value.from_symbol(symbol)])!.is_undefined()
	}
	mut other_vm := VM.create()
	create_simple_execution_context(mut other_vm)
	other := symbol_constructor_method(mut other_vm, other_vm.realm(), 'for', []Value{})!
	assert voidptr(other.as_symbol()) != voidptr(default_key.as_symbol())
}

@[heap]
struct SymbolCoercionTrace {
mut:
	calls int
}

fn test_symbol_constructor_coercion_and_brand_errors_restore_context_and_construction_never_coerces() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	function := Value.from_object(realm.symbol_constructor_record())
	mut trace := &SymbolCoercionTrace{}
	mut argument := Object.create(realm, none)
	coercion := NativeFunction.create(mut vm, realm, realm.function_prototype, fn [mut trace] (mut vm VM) !Value {
		trace.calls++
		assert vm.argument(0).as_string().str() == 'string'
		return throw_completion(Value.from_i32(17))
	}, 1, PropertyName.from_str('coerce'), none)
	argument.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(coercion.object), 7)
	if _ := call(mut vm, function, js_null(), [Value.from_object(argument)]) { assert false }
	else { assert thrown_value(err).number == 17 }
	if _ := symbol_constructor_method(mut vm, realm, 'for', [Value.from_object(argument)]) { assert false }
	else { assert thrown_value(err).number == 17 }
	assert trace.calls == 2
	if _ := construct(mut vm, function, [Value.from_object(argument)], none) { assert false }
	else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
		assert thrown_value(err).as_object().error_message()? == 'Symbol is not a constructor'
	}
	assert trace.calls == 2
	boxed := SymbolObject.create(realm, Symbol.create(none, .unique))
	for value in [js_undefined(), js_null(), Value.from_i32(42), Value.from_object(boxed.object)] {
		if _ := symbol_constructor_method(mut vm, realm, 'keyFor', [value]) { assert false }
		else { assert thrown_value(err).as_object().error_kind()? == .type_error }
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
