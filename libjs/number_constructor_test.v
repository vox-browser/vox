module libjs

import math

@[heap]
struct NumberConstructorLog {
mut:
	events []string
}

fn number_constructor_test_record(mut vm VM, realm &Realm, prototype &Object) &Object {
	parse_int := realm.global_object_record().get(mut vm, PropertyName.from_str('parseInt')) or {
		panic(err)
	}
	parse_float := realm.global_object_record().get(mut vm, PropertyName.from_str('parseFloat')) or {
		panic(err)
	}
	return NumberConstructor.create(mut vm, realm, NumberConstructorDependencies{
		prototype:        prototype
		prototype_getter: fn [prototype] (realm &Realm) &Object {
			return prototype
		}
		parse_int:        parse_int.as_object()
		parse_float:      parse_float.as_object()
	}).object
}

fn test_number_constructor_initialization_preserves_metadata_constants_alias_identity_and_source_order() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	prototype := Object.create(realm, none)
	constructor := number_constructor_test_record(mut vm, realm, prototype)
	assert constructor.own_property_keys().map(it.str()) == ['prototype', 'isFinite', 'isInteger',
		'isNaN', 'isSafeInteger', 'parseInt', 'parseFloat', 'EPSILON', 'MAX_VALUE', 'MIN_VALUE',
		'MAX_SAFE_INTEGER', 'MIN_SAFE_INTEGER', 'NEGATIVE_INFINITY', 'POSITIVE_INFINITY', 'NaN',
		'length', 'name']
	assert Value.from_object(constructor).is_constructor()
		&& constructor.class_name == 'NumberConstructor'
	assert voidptr(constructor.internal_get_prototype_of()?) == voidptr(realm.function_prototype_record())
	assert constructor.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == 'Number'
	assert constructor.get(mut vm, PropertyName.from_str('length'))!.number == 1
	assert voidptr(prototype.get(mut vm, PropertyName.from_str('constructor'))!.as_object()) == voidptr(constructor)
	for name in ['parseInt', 'parseFloat'] {
		method := constructor.get(mut vm, PropertyName.from_str(name))!
		original := realm.global_object_record().get(mut vm, PropertyName.from_str(name))!
		assert same_value(method, original)
		mut global := realm.global_object_record()
		global.define_direct_property(PropertyName.from_str(name), Value.from_i32(77), 7)
		assert same_value(constructor.get(mut vm, PropertyName.from_str(name))!, original)
	}
	for name in ['isFinite', 'isInteger', 'isNaN', 'isSafeInteger', 'parseInt', 'parseFloat'] {
		descriptor := constructor.internal_get_own_property(PropertyName.from_str(name))?
		assert descriptor.writable? && descriptor.configurable? && !descriptor.enumerable?
	}
	for name in ['isFinite', 'isInteger', 'isNaN', 'isSafeInteger'] {
		method := constructor.get(mut vm, PropertyName.from_str(name))!.as_object()
		assert method.get(mut vm, PropertyName.from_str('length'))!.number == 1
		assert method.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == name
	}
	for name, expected in {
		'EPSILON':           math.ldexp(1, -52)
		'MAX_VALUE':         math.max_f64
		'MIN_VALUE':         math.f64_from_bits(1)
		'MAX_SAFE_INTEGER':  9007199254740991.0
		'MIN_SAFE_INTEGER':  -9007199254740991.0
		'NEGATIVE_INFINITY': math.inf(-1)
		'POSITIVE_INFINITY': math.inf(1)
		'NaN':               math.nan()
	} {
		descriptor := constructor.internal_get_own_property(PropertyName.from_str(name))?
		assert same_value(descriptor.value?, Value.from_f64(expected))
		assert !descriptor.writable? && !descriptor.enumerable? && !descriptor.configurable?
	}
}

fn test_number_constructor_call_distinguishes_missing_argument_and_rounds_bigints_once() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	constructor := Value.from_object(number_constructor_test_record(mut vm, vm.realm(),
		Object.create(vm.realm(), none)))
	assert same_value(call(mut vm, constructor, js_null(), []Value{})!, Value.from_i32(0))
	assert call(mut vm, constructor, js_null(), [js_undefined()])!.is_nan()
	for argument, expected in {
		'00123':     123.0
		'0x11':      17.0
		'0b11':      3.0
		'0o77':      63.0
		'Infinity':  math.inf(1)
		'-Infinity': math.inf(-1)
		'':          0.0
	} {
		assert call(mut vm, constructor, js_null(), [
			Value.from_string(vm.create_string_from_str(argument)),
		])!.number == expected
	}
	mut log := &NumberConstructorLog{}
	for source, expected in {
		'9007199254740993':  9007199254740992.0
		'9007199254740995':  9007199254740996.0
		'-9007199254740995': -9007199254740996.0
		'123':               123.0
	} {
		integer := string_to_bigint(utf16_string(source)) or { panic(source) }
		mut object := Object.create(vm.realm(), none)
		coercion := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [integer, mut log] (mut vm VM) !Value {
			log.events << vm.argument(0).as_string().str()
			return Value.from_bigint(integer)
		}, 1, PropertyName.from_str('coerce'), none)
		object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
			Value.from_object(coercion.object), 7)
		assert call(mut vm, constructor, js_null(), [Value.from_object(object)])!.number == expected
		assert log.events == ['number']
		log.events.clear()
	}
	assert same_value(call(mut vm, constructor, js_null(), [Value.from_f64(-0.0)])!,
		Value.from_f64(-0.0))
	if _ := call(mut vm, constructor, js_null(), [
		Value.from_symbol(Symbol.create(none, .unique)),
	])
	{
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == 'Cannot convert symbol to number'
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_number_construction_converts_before_prototype_lookup_and_preserves_bound_and_foreign_targets() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	local := vm.realm()
	prototype := Object.create(local, none)
	constructor := Value.from_object(number_constructor_test_record(mut vm, local, prototype))
	result := construct(mut vm, constructor, []Value{}, none)!
	assert result.number_object?.value == 0 && result.class_name == 'NumberObject'
	assert voidptr(result.prototype?) == voidptr(prototype)
	mut log := &NumberConstructorLog{}
	mut argument := Object.create(local, none)
	coercion := NativeFunction.create(mut vm, local, local.function_prototype, fn [mut log] (mut vm VM) !Value {
		log.events << 'convert'
		return Value.from_f64(-0.0)
	}, 1, PropertyName.from_str('coerce'), none)
	argument.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(coercion.object), 7)
	foreign := create_simple_execution_context(mut vm).realm?
	vm.pop_execution_context()
	foreign_prototype := Object.create(foreign, none)
	mut target := number_constructor_test_record(mut vm, foreign, foreign_prototype)
	target.define_native_accessor(mut vm, foreign, PropertyName.from_str('prototype'), fn [foreign_prototype, mut log] (mut vm VM) !Value {
		log.events << 'prototype'
		return Value.from_object(foreign_prototype)
	}, unsafe { nil }, attribute_configurable, foreign.function_prototype)
	result_with_target := construct(mut vm, constructor, [Value.from_object(argument)], target)!
	assert same_value(Value.from_f64(result_with_target.number_object?.value), Value.from_f64(-0.0))
	assert voidptr(result_with_target.prototype?) == voidptr(foreign_prototype)
	assert log.events == ['convert', 'prototype']
	log.events.clear()
	bound := BoundFunction.create(local, constructor.as_object(), js_null(), [
		Value.from_i32(42),
	])
	assert construct(mut vm, Value.from_object(bound.object), []Value{}, none)!.number_object?.value == 42
	thrower := NativeFunction.create(mut vm, local, local.function_prototype, fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(77))
	}, 1, PropertyName.from_str('thrower'), none)
	argument.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(thrower.object), 7)
	if _ := construct(mut vm, constructor, [Value.from_object(argument)], target) {
		assert false
	} else {
		assert thrown_value(err).number == 77
	}
	assert log.events.len == 0
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
