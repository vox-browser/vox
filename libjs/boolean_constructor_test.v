module libjs

import math

fn test_boolean_constructor_links_intrinsics_and_defines_standard_global_descriptors() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	constructor := realm.boolean_constructor_record()
	prototype := realm.boolean_prototype_record()
	assert constructor.internal_get_prototype_of()? == realm.function_prototype_record()
	assert Value.from_object(constructor).is_constructor()
	assert constructor.own_property_keys().map(it.str()) == ['prototype', 'length', 'name']
	assert constructor.get(mut vm, PropertyName.from_str('length'))!.number == 1
	assert constructor.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == 'Boolean'
	descriptor := constructor.internal_get_own_property(PropertyName.from_str('prototype'))?
	assert descriptor.value?.as_object() == prototype
	assert !descriptor.writable? && !descriptor.configurable? && !descriptor.enumerable?
	back_reference := prototype.internal_get_own_property(PropertyName.from_str('constructor'))?
	assert back_reference.value?.as_object() == constructor
	assert back_reference.writable? && back_reference.configurable? && !back_reference.enumerable?
	global := realm.global_object_record().internal_get_own_property(PropertyName.from_str('Boolean'))?
	assert global.value?.as_object() == constructor
	assert global.writable? && global.configurable? && !global.enumerable?
	foreign := create_simple_execution_context(mut vm).realm?
	assert foreign.boolean_constructor_record() != constructor
	assert foreign.boolean_prototype_record() != prototype
}

fn test_boolean_call_and_construction_use_to_boolean_without_primitive_conversion() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	function := Value.from_object(realm.boolean_constructor_record())
	mut trap := Object.create(realm, none)
	coercion := NativeFunction.create(mut vm, realm, realm.function_prototype, fn (mut vm VM) !Value {
		assert false, 'Boolean must not call conversion hooks'
		return js_undefined()
	}, 1, PropertyName.from_str('coerce'), none)
	trap.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(coercion.object), 7)
	for value in [js_undefined(), js_null(), Value.from_bool(false), Value.from_bool(true),
		Value.from_f64(0), Value.from_f64(-0.0), Value.from_f64(math.nan()), Value.from_i32(42),
		Value.from_string(vm.create_string_from_str('')), Value.from_string(vm.create_string_from_str('false')),
		Value.from_bigint(string_to_bigint(utf16_string('0')) or { panic('invalid BigInt literal') }),
		Value.from_bigint(string_to_bigint(utf16_string('42')) or { panic('invalid BigInt literal') }),
		Value.from_symbol(Symbol.create(none, .unique)), Value.from_object(trap)] {
		assert call(mut vm, function, Value.from_i32(99), [value])!.as_bool() == value.to_boolean()
		boxed := construct(mut vm, function, [value], none)!
		assert boxed.boolean_object?.value == value.to_boolean()
		assert boxed.internal_get_prototype_of()? == realm.boolean_prototype_record()
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
	assert !call(mut vm, function, js_null(), []Value{})!.as_bool()
	no_argument := construct(mut vm, function, []Value{}, none)!
	assert !no_argument.boolean_object?.value
}

fn test_boolean_construction_preserves_new_target_prototype_and_foreign_fallback() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	local := vm.realm()
	foreign := create_simple_execution_context(mut vm).realm?
	vm.pop_execution_context()
	function := Value.from_object(local.boolean_constructor_record())
	custom := Object.create(local, none)
	for prototype_value in [Value.from_object(custom), js_null(), Value.from_i32(42)] {
		new_target := NativeFunction.create_constructor(mut vm, foreign, foreign.function_prototype,
			boolean_constructor_call, boolean_constructor_construct, 1, PropertyName.from_str('Foreign'))
		mut object := new_target.object
		object.define_direct_property(PropertyName.from_str('prototype'), prototype_value, 7)
		boxed := construct(mut vm, function, [Value.from_bool(true)], object)!
		assert boxed.boolean_object?.value
		assert boxed.internal_get_prototype_of()? == if prototype_value.is_object() { custom } else { foreign.boolean_prototype_record() }
	}
	new_target := NativeFunction.create_constructor(mut vm, foreign, foreign.function_prototype,
		boolean_constructor_call, boolean_constructor_construct, 1, PropertyName.from_str('Abrupt'))
	mut object := new_target.object
	object.define_native_accessor(mut vm, foreign, PropertyName.from_str('prototype'), fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(17))
	}, unsafe { nil }, 0, foreign.function_prototype)
	if _ := construct(mut vm, function, []Value{}, object) {
		assert false
	} else {
		assert thrown_value(err).number == 17
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
