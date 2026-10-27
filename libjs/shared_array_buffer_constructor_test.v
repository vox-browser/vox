module libjs

import math

@[heap]
struct SharedConstructorLog {
mut:
	events []string
}

fn test_shared_array_buffer_constructor_installs_metadata_species_and_intrinsic_links() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	constructor := realm.shared_array_buffer_constructor_record()
	prototype := realm.shared_array_buffer_prototype_record()
	assert Value.from_object(constructor).is_constructor()
	assert constructor.own_property_keys().map(it.str()) == ['prototype', 'length', 'name',
		'Symbol(Symbol.species)']
	assert voidptr(constructor.internal_get_prototype_of()?) == voidptr(realm.function_prototype_record())
	assert constructor.get(mut vm, PropertyName.from_str('length'))!.number == 1
	assert constructor.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == 'SharedArrayBuffer'
	descriptor := constructor.internal_get_own_property(PropertyName.from_str('prototype'))?
	assert voidptr(descriptor.value?.as_object()) == voidptr(prototype)
	assert !descriptor.writable? && !descriptor.enumerable? && !descriptor.configurable?
	for object in [prototype, realm.global_object_record()] {
		key := if voidptr(object) == voidptr(prototype) {
			'constructor'
		} else {
			'SharedArrayBuffer'
		}
		link := object.internal_get_own_property(PropertyName.from_str(key))?
		assert voidptr(link.value?.as_object()) == voidptr(constructor)
		assert link.writable? && link.configurable? && !link.enumerable?
	}
	species :=
		constructor.internal_get_own_property(PropertyName.from_symbol(vm.well_known_symbol_species()))?
	assert species.configurable? && !species.enumerable? && species.setter?.is_undefined()
	getter := species.getter?.as_object()
	assert getter.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == 'get [Symbol.species]'
	assert getter.get(mut vm, PropertyName.from_str('length'))!.number == 0
	assert constructor.internal_get(mut vm,
		PropertyName.from_symbol(vm.well_known_symbol_species()), Value.from_i32(42))!.number == 42
}

fn test_shared_array_buffer_constructor_coercion_order_precedes_allocation_and_prototype_lookup() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	mut log := &SharedConstructorLog{}
	mut length := Object.create(realm, none)
	convert := NativeFunction.create(mut vm, realm, realm.function_prototype, fn [mut log] (mut vm VM) !Value {
		log.events << 'length'
		assert vm.argument(0).as_string().str() == 'number'
		return Value.from_f64(3.9)
	}, 1, PropertyName.from_str('convert'), none)
	length.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(convert.object), 7)
	mut maximum := Object.create(realm, none)
	maximum_convert := NativeFunction.create(mut vm, realm, realm.function_prototype, fn [mut log] (mut vm VM) !Value {
		log.events << 'maximum conversion'
		return Value.from_i32(8)
	}, 1, PropertyName.from_str('convert'), none)
	maximum.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(maximum_convert.object), 7)
	mut options := Object.create(realm, none)
	options.define_native_accessor(mut vm, realm, PropertyName.from_str('maxByteLength'), fn [mut log, maximum] (mut vm VM) !Value {
		log.events << 'maximum'
		return Value.from_object(maximum)
	}, unsafe { nil }, attribute_configurable, realm.function_prototype)
	custom := Object.create(realm, none)
	target := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype,
		shared_array_buffer_constructor_call, shared_array_buffer_constructor_construct, 1,
		PropertyName.from_str('Target'))
	mut object := target.object
	object.define_native_accessor(mut vm, realm, PropertyName.from_str('prototype'), fn [mut log, custom] (mut vm VM) !Value {
		log.events << 'prototype'
		return Value.from_object(custom)
	}, unsafe { nil }, 0, realm.function_prototype)
	function := Value.from_object(realm.shared_array_buffer_constructor_record())
	arguments := [Value.from_object(length), Value.from_object(options)]
	if _ := call(mut vm, function, js_undefined(), arguments) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == "SharedArrayBuffer constructor must be called with 'new'"
	}
	assert log.events.len == 0
	buffer := construct(mut vm, function, arguments, object)!.array_buffer?
	assert log.events == ['length', 'maximum', 'maximum conversion', 'prototype']
	assert buffer.is_shared_array_buffer() && buffer.byte_length() == 3
		&& buffer.max_byte_length() == 8
	assert buffer.data_block().capacity() >= 8 && buffer.read_bytes(0, 3) == [u8(0), 0, 0]
	assert voidptr(buffer.object.internal_get_prototype_of()?) == voidptr(custom)
	log.events.clear()
	options.define_direct_property(PropertyName.from_str('maxByteLength'), Value.from_i32(2), 7)
	if _ := construct(mut vm, function, arguments, object) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == 'ArrayBuffer byte length of 3 exceeds the max byte length of 2'
	}
	assert log.events == ['length']
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_shared_array_buffer_constructor_rewrites_only_initial_length_range_errors() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	function := Value.from_object(realm.shared_array_buffer_constructor_record())
	for value in [js_undefined(), js_null(), Value.from_bool(false),
		Value.from_f64(0.9), Value.from_string(vm.create_string_from_str('3'))] {
		buffer := construct(mut vm, function, [value, Value.from_i32(8)], none)!.array_buffer?
		assert buffer.byte_length() == if value.is_string() {
			uint(3)
		} else {
			uint(0)
		}
		assert buffer.is_shared_array_buffer() && buffer.is_fixed_length() && !buffer.is_detached()
	}
	for value in [Value.from_i32(-1), Value.from_f64(math.inf(1)),
		Value.from_f64(9007199254740992)] {
		if _ := construct(mut vm, function, [value], none) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == 'Invalid shared array buffer length'
		}
	}
	for kind in [ErrorKind.range_error, .type_error] {
		mut argument := Object.create(realm, none)
		convert := NativeFunction.create(mut vm, realm, realm.function_prototype, fn [kind] (mut vm VM) !Value {
			return vm.throw_error_type(kind, .invalid_length, 'sentinel')
		}, 1, PropertyName.from_str('convert'), none)
		argument.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
			Value.from_object(convert.object), 7)
		if _ := construct(mut vm, function, [Value.from_object(argument)], none) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == kind
			assert thrown_value(err).as_object().error_message()?.str() == if kind == .range_error {
				'Invalid shared array buffer length'
			} else {
				'Invalid sentinel length'
			}
		}
		mut options := Object.create(realm, none)
		options.define_native_accessor(mut vm, realm, PropertyName.from_str('maxByteLength'), fn [kind] (mut vm VM) !Value {
			return vm.throw_error_type(kind, .invalid_length, 'sentinel')
		}, unsafe { nil }, 0, realm.function_prototype)
		if _ := construct(mut vm, function, [Value.from_i32(0),
			Value.from_object(options)], none)
		{
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == 'Invalid sentinel length'
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_shared_array_buffer_allocation_reserves_maximum_and_uses_new_target_realm_before_storage_errors() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	local := vm.realm()
	foreign := create_simple_execution_context(mut vm).realm?
	vm.pop_execution_context()
	mut log := &SharedConstructorLog{}
	target := NativeFunction.create_constructor(mut vm, foreign, foreign.function_prototype,
		shared_array_buffer_constructor_call, shared_array_buffer_constructor_construct, 1,
		PropertyName.from_str('Foreign'))
	mut object := target.object
	object.define_native_accessor(mut vm, foreign, PropertyName.from_str('prototype'), fn [mut log] (mut vm VM) !Value {
		log.events << 'prototype'
		return js_null()
	}, unsafe { nil }, 0, foreign.function_prototype)
	for maximum in [?uint(none), ?uint(0), ?uint(12)] {
		buffer := allocate_shared_array_buffer(mut vm, object, 0, maximum)!
		assert buffer.is_shared_array_buffer() && !buffer.is_detached() && buffer.byte_length() == 0
		assert buffer.is_fixed_length() == (maximum == none)
		assert buffer.data_block().capacity() >= maximum or { uint(0) }
		assert voidptr(buffer.object.internal_get_prototype_of()?) == voidptr(foreign.shared_array_buffer_prototype_record())
	}
	log.events.clear()
	if _ := allocate_shared_array_buffer(mut vm, object, 4, uint(3)) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .range_error
	}
	assert log.events.len == 0
	if _ := allocate_shared_array_buffer(mut vm, object, 0, uint(9007199254740992)) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == 'Not enough memory to allocate 9007199254740992 bytes'
	}
	assert log.events == ['prototype']
	assert vm.running_execution_context() == base && voidptr(vm.realm()) == voidptr(local)
	assert vm.interpreter_stack().depth() == 0
}
