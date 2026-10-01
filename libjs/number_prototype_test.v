module libjs

import math

fn number_prototype_test_decimal(number f64) NumberDecimalExponentialForm {
	assert number == 1.25
	return NumberDecimalExponentialForm{
		fraction: 125
		exponent: -2
	}
}

fn number_prototype_test_locale(mut vm VM, realm &Realm, parent &Object) NumberLocaleDependencies {
	constructor := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype, fn (mut vm VM) !Value {
		return js_undefined()
	}, fn [realm, parent] (mut vm VM, target &Object) !&Object {
		assert voidptr(vm.realm()) == voidptr(realm) && vm.argument_count() == 2
		return parent
	}, 0, PropertyName.from_str('HostNumberFormat')).object
	return NumberLocaleDependencies{
		constructor_getter: fn [realm, constructor] (current &Realm) &Object {
			assert voidptr(current) == voidptr(realm)
			return constructor
		}
		format_numeric:     fn [parent] (formatter &Object, number Value) Utf16String {
			assert voidptr(formatter) == voidptr(parent) && number.is_number()
			return utf16_string('host Intl marker')
		}
	}
}

fn number_prototype_test_constructor(mut vm VM, realm &Realm, prototype &Object) &Object {
	mut global := realm.global_object_record()
	return NumberConstructor.create(mut vm, realm, NumberConstructorDependencies{
		prototype:        prototype
		prototype_getter: fn [prototype] (realm &Realm) &Object {
			return prototype
		}
		parse_int:        global.get(mut vm, PropertyName.from_str('parseInt')) or {
			panic('fixture')
		}.as_object()
		parse_float:      global.get(mut vm, PropertyName.from_str('parseFloat')) or {
			panic('fixture')
		}.as_object()
	}).object
}

fn test_number_prototype_initialization_source_order_descriptors_and_own_positive_zero_slot() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	parent := Object.create(realm, none)
	prototype := NumberPrototype.create(mut vm, realm, parent, number_prototype_test_decimal, number_prototype_test_locale(mut vm,
		realm, parent)).object
	assert voidptr(prototype.internal_get_prototype_of()?) == voidptr(parent)
	assert prototype.number_object?.value == 0 && !math.signbit(prototype.number_object?.value)
	assert prototype.class_name == 'NumberPrototype'
	assert !Value.from_object(prototype).is_function()
	if _ := call(mut vm, Value.from_object(prototype), js_null(), []Value{}) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == '[object NumberPrototype] is not a function'
	}
	names := ['toExponential', 'toFixed', 'toLocaleString', 'toPrecision', 'toString', 'valueOf']
	lengths := [1, 1, 0, 1, 1, 0]
	assert prototype.own_property_keys().map(it.str()) == names
	for index, name in names {
		descriptor := prototype.internal_get_own_property(PropertyName.from_str(name))?
		assert descriptor.writable? && descriptor.configurable? && !descriptor.enumerable?
		method := descriptor.value?.as_object()
		assert method.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == name
		assert method.get(mut vm, PropertyName.from_str('length'))!.number == lengths[index]
		assert voidptr(method.internal_get_prototype_of()?) == voidptr(realm.function_prototype_record())
		result := call(mut vm, Value.from_object(method), Value.from_object(prototype), []Value{})!
		if index == 5 {
			assert result.number == 0 && !math.signbit(result.number)
		} else {
			assert result.as_string().str() == if index == 0 {
				'0e+0'
			} else if index == 2 {
				'host Intl marker'
			} else {
				'0'
			}
		}
	}
	assert prototype.internal_get_own_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag())) == none
	constructor := number_prototype_test_constructor(mut vm, realm, prototype)
	mut with_constructor := names.clone()
	with_constructor << 'constructor'
	assert prototype.own_property_keys().map(it.str()) == with_constructor
	assert voidptr(prototype.get(mut vm, PropertyName.from_str('constructor'))!.as_object()) == voidptr(constructor)
}

fn test_number_records_support_boxing_coercion_and_bound_calls_without_inherited_branding() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	parent := Object.create(realm, none)
	prototype := NumberPrototype.create(mut vm, realm, parent, number_prototype_test_decimal, number_prototype_test_locale(mut vm,
		realm, parent)).object
	constructor := number_prototype_test_constructor(mut vm, realm, prototype)
	primitives := PrimitiveObjectPrototypes{
		number: fn [prototype] (realm &Realm) &Object {
			return prototype
		}
	}
	value := Value.from_f64(1.25)
	wrapper := value.to_object_with_prototypes(mut vm, primitives)!
	assert wrapper.number_object?.value == 1.25
	assert Value.from_object(wrapper).to_number(mut vm)!.number == 1.25
	primitive_text := Value.from_object(wrapper).to_primitive_string(mut vm)!
	assert primitive_text.str() == '1.25'
	assert call(mut vm, Value.from_object(constructor), js_null(), [
		Value.from_object(wrapper),
	])!.number == 1.25
	assert value.invoke_with_prototypes(mut vm, PropertyName.from_str('toExponential'), []Value{},
		primitives)!.as_string().str() == '1.25e+0'
	method := wrapper.get(mut vm, PropertyName.from_str('toPrecision'))!
	bound := BoundFunction.create(realm, method.as_object(), Value.from_object(wrapper), [
		Value.from_i32(3),
	])
	assert call(mut vm, Value.from_object(bound.object), js_null(), []Value{})!.as_string().str() == '1.25'
	boxed := construct(mut vm, Value.from_object(constructor), [
		Value.from_f64(-0.0),
	], none)!
	assert math.signbit(boxed.number_object?.value)
	assert voidptr(boxed.prototype?) == voidptr(prototype)
	spoof := Object.create(realm, wrapper)
	for name in ['valueOf', 'toExponential', 'toFixed', 'toLocaleString', 'toPrecision', 'toString'] {
		function := prototype.get(mut vm, PropertyName.from_str(name))!
		if _ := call(mut vm, function, Value.from_object(spoof), []Value{}) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == 'Not an object of type Number'
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_number_locale_method_uses_its_callee_realm_intrinsics_after_global_replacement() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	local := vm.realm()
	parent := Object.create(local, none)
	prototype := NumberPrototype.create(mut vm, local, parent, number_prototype_test_decimal, number_prototype_test_locale(mut vm,
		local, parent)).object
	method := prototype.get(mut vm, PropertyName.from_str('toLocaleString'))!
	mut global := local.global_object_record()
	global.define_direct_property(PropertyName.from_str('Intl'), Value.from_i32(77), 7)
	foreign := create_simple_execution_context(mut vm)
	assert voidptr(foreign.realm?) != voidptr(local)
	assert call(mut vm, method, Value.from_f64(-0.0), []Value{})!.as_string().str() == 'host Intl marker'
	assert vm.running_execution_context() == foreign && vm.interpreter_stack().depth() == 0
}

fn test_number_construction_uses_new_target_realm_for_missing_intrinsic_prototype() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	local := vm.realm()
	parent := Object.create(local, none)
	prototype := NumberPrototype.create(mut vm, local, parent, number_prototype_test_decimal, number_prototype_test_locale(mut vm,
		local, parent)).object
	foreign := create_simple_execution_context(mut vm).realm?
	vm.pop_execution_context()
	foreign_parent := Object.create(foreign, none)
	foreign_prototype := NumberPrototype.create(mut vm, foreign, foreign_parent,
		number_prototype_test_decimal,
		number_prototype_test_locale(mut vm, foreign, foreign_parent)).object
	constructor := NumberConstructor.create(mut vm, local, NumberConstructorDependencies{
		prototype:        prototype
		prototype_getter: fn [foreign, foreign_prototype] (realm &Realm) &Object {
			assert voidptr(realm) == voidptr(foreign)
			return foreign_prototype
		}
		parse_int:        local.global_object_record().get(mut vm,
			PropertyName.from_str('parseInt'))!.as_object()
		parse_float:      local.global_object_record().get(mut vm,
			PropertyName.from_str('parseFloat'))!.as_object()
	}).object
	mut target := NativeFunction.create_constructor(mut vm, foreign, foreign.function_prototype, fn (mut vm VM) !Value {
		return js_undefined()
	}, fn [foreign_parent] (mut vm VM, target &Object) !&Object {
		return foreign_parent
	}, 0, PropertyName.from_str('HostNewTarget')).object
	target.define_native_accessor(mut vm, foreign, PropertyName.from_str('prototype'), fn [foreign] (mut vm VM) !Value {
		assert voidptr(vm.realm()) == voidptr(foreign)
		return js_null()
	}, unsafe { nil }, attribute_configurable, foreign.function_prototype)
	bound := BoundFunction.create(local, target, js_null(), []Value{})
	for new_target in [target, bound.object] {
		result := construct(mut vm, Value.from_object(constructor), [
			Value.from_f64(1.25),
		], new_target)!
		assert result.number_object?.value == 1.25
		assert voidptr(result.prototype?) == voidptr(foreign_prototype)
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
