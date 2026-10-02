module libjs

fn string_constructor_test_record(mut vm VM, realm &Realm, prototype &Object) &Object {
	return StringConstructor.create(mut vm, realm, StringConstructorDependencies{
		prototype:        prototype
		prototype_getter: fn [prototype] (realm &Realm) &Object {
			return prototype
		}
		primitives:       PrimitiveObjectPrototypes{
			string: fn [prototype] (realm &Realm) &Object {
				return prototype
			}
		}
	}).object
}

fn test_string_constructor_initialization_preserves_source_order_descriptors_and_links() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	prototype := Object.create(realm, none)
	constructor := string_constructor_test_record(mut vm, realm, prototype)
	assert constructor.class_name == 'StringConstructor'
		&& Value.from_object(constructor).is_constructor()
	assert constructor.own_property_keys().map(it.str()) == ['prototype', 'raw', 'fromCharCode',
		'fromCodePoint', 'length', 'name']
	assert constructor.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == 'String'
	assert constructor.get(mut vm, PropertyName.from_str('length'))!.number == 1
	assert voidptr(constructor.prototype?) == voidptr(realm.function_prototype_record())
	property := constructor.internal_get_own_property(PropertyName.from_str('prototype'))?
	assert voidptr(property.value?.as_object()) == voidptr(prototype)
	assert !property.writable? && !property.enumerable? && !property.configurable?
	backref := prototype.internal_get_own_property(PropertyName.from_str('constructor'))?
	assert voidptr(backref.value?.as_object()) == voidptr(constructor)
	assert backref.writable? && backref.configurable? && !backref.enumerable?
	for name in ['raw', 'fromCharCode', 'fromCodePoint'] {
		descriptor := constructor.internal_get_own_property(PropertyName.from_str(name))?
		assert descriptor.writable? && descriptor.configurable? && !descriptor.enumerable?
		method := descriptor.value?.as_object()
		assert method.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == name
		assert method.get(mut vm, PropertyName.from_str('length'))!.number == 1
		assert voidptr(method.prototype?) == voidptr(realm.function_prototype_record())
	}
}

fn test_string_constructor_call_distinguishes_missing_undefined_and_symbol_descriptive_string() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	constructor := Value.from_object(string_constructor_test_record(mut vm, vm.realm(),
		Object.create(vm.realm(), none)))
	assert voidptr(call(mut vm, constructor, js_null(), []Value{})!.as_string()) == voidptr(vm.empty_string())
	assert call(mut vm, constructor, js_null(), [js_undefined()])!.as_string().str() == 'undefined'
	assert call(mut vm, constructor, js_null(), [js_null()])!.as_string().str() == 'null'
	assert call(mut vm, constructor, js_null(), [Value.from_bool(true)])!.as_string().str() == 'true'
	assert call(mut vm, constructor, js_null(), [Value.from_i32(42)])!.as_string().str() == '42'
	integer := string_to_bigint(utf16_string('123456789123456789')) or { panic('fixture') }
	assert call(mut vm, constructor, js_null(), [Value.from_bigint(integer)])!.as_string().str() == '123456789123456789'
	text := vm.create_string(Utf16String.from_slice([u16(0xd800), 0, 0xdc00]))
	assert voidptr(call(mut vm, constructor, js_null(), [Value.from_string(text)])!.as_string()) == voidptr(text)
	mut descriptions := []?Utf16String{}
	descriptions << none
	descriptions << utf16_string('')
	descriptions << text.utf16
	for description in descriptions {
		symbol := Symbol.create(description, .unique)
		assert call(mut vm, constructor, js_null(), [Value.from_symbol(symbol)])!.as_string().utf16 == symbol.descriptive_string()
		if _ := construct(mut vm, constructor, [Value.from_symbol(symbol)], none) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == 'Cannot convert symbol to string'
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

@[heap]
struct StringConstructorLog {
mut:
	events []string
}

fn test_string_constructor_converts_once_before_new_target_lookup_and_preserves_exotic_utf16() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	local := vm.realm()
	prototype := Object.create(local, none)
	constructor := Value.from_object(string_constructor_test_record(mut vm, local, prototype))
	mut log := &StringConstructorLog{}
	text := vm.create_string(Utf16String.from_slice([u16(0xd800), 0, 0xdc00]))
	mut argument := Object.create(local, none)
	conversion := NativeFunction.create(mut vm, local, local.function_prototype, fn [text, mut log] (mut vm VM) !Value {
		log.events << vm.argument(0).as_string().str()
		return Value.from_string(text)
	}, 1, PropertyName.from_str('convert'), none)
	argument.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(conversion.object), 7)
	assert voidptr(call(mut vm, constructor, js_null(), [Value.from_object(argument)])!.as_string()) == voidptr(text)
	assert log.events == ['string']
	log.events.clear()
	foreign := create_simple_execution_context(mut vm).realm?
	vm.pop_execution_context()
	foreign_prototype := Object.create(foreign, none)
	mut target := string_constructor_test_record(mut vm, foreign, foreign_prototype)
	target.define_native_accessor(mut vm, foreign, PropertyName.from_str('prototype'), fn [foreign_prototype, mut log] (mut vm VM) !Value {
		log.events << 'prototype'
		return Value.from_object(foreign_prototype)
	}, unsafe { nil }, attribute_configurable, foreign.function_prototype)
	result := construct(mut vm, constructor, [Value.from_object(argument)], target)!
	assert voidptr(result.string_object?.value) == voidptr(text)
	assert result.get(mut vm, PropertyName.from_str('length'))!.number == 3
	assert result.get(mut vm, PropertyName.from_number(0))!.as_string().utf16.data == [
		u16(0xd800),
	]
	assert voidptr(result.prototype?) == voidptr(foreign_prototype)
	assert log.events == ['string', 'prototype']
	log.events.clear()
	bound := BoundFunction.create(local, constructor.as_object(), js_null(), [
		Value.from_string(text),
	])
	assert voidptr(construct(mut vm, Value.from_object(bound.object), []Value{}, none)!.string_object?.value) == voidptr(text)
	for arguments in [[]Value{}, [js_undefined()]] {
		boxed := construct(mut vm, constructor, arguments, none)!
		assert boxed.string_object?.value.str() == if arguments.len == 0 {
			''
		} else {
			'undefined'
		}
	}
	if _ := construct(mut vm, constructor, [
		Value.from_symbol(Symbol.create(none, .unique)),
	], target)
	{
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	assert log.events.len == 0
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
