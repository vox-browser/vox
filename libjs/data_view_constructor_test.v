module libjs

@[heap]
struct ViewConstructorLog {
mut:
	events []string
}

fn test_data_view_constructor_metadata_and_fixed_tracking_lengths() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	constructor := realm.data_view_constructor_record()
	prototype := realm.data_view_prototype_record()
	assert constructor.own_property_keys().map(it.str()) == ['prototype', 'length', 'name']
	assert constructor.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == 'DataView'
	assert constructor.get(mut vm, PropertyName.from_str('length'))!.number == 1
	assert voidptr(constructor.internal_get_prototype_of()?) == voidptr(realm.function_prototype_record())
	property := constructor.internal_get_own_property(PropertyName.from_str('prototype'))?
	assert voidptr(property.value?.as_object()) == voidptr(prototype)
	assert !property.writable? && !property.configurable? && !property.enumerable?
	for object in [prototype, realm.global_object_record()] {
		key := if voidptr(object) == voidptr(prototype) { 'constructor' } else { 'DataView' }
		link := object.internal_get_own_property(PropertyName.from_str(key))?
		assert voidptr(link.value?.as_object()) == voidptr(constructor)
		assert link.writable? && link.configurable? && !link.enumerable?
	}
	for maximum in [?uint(none), ?uint(12)] {
		buffer :=
			allocate_array_buffer(mut vm, realm.array_buffer_constructor_record(), 8, maximum)!
		view := construct(mut vm, Value.from_object(constructor), [
			Value.from_object(buffer.object),
			Value.from_i32(2),
		], none)!.data_view?
		assert voidptr(view.viewed_buffer?) == voidptr(buffer) && view.byte_offset() == 2
		assert voidptr(view.object.internal_get_prototype_of()?) == voidptr(prototype)
		assert view.byte_length.is_auto() == (maximum != none)
		assert get_view_byte_length(make_data_view_with_buffer_witness_record(view, .seq_cst)) == 6
		fixed := construct(mut vm, Value.from_object(constructor), [
			Value.from_object(buffer.object),
			Value.from_i32(2),
			Value.from_i32(3),
		], none)!.data_view?
		assert !fixed.byte_length.is_auto() && fixed.byte_length.length() == 3
		// ByteLength narrows the requested length to u32 before both source checks.
		wrapped := construct(mut vm, Value.from_object(constructor), [
			Value.from_object(buffer.object),
			Value.from_i32(2),
			Value.from_f64(4294967299),
		], none)!.data_view?
		assert wrapped.byte_length.length() == 3
	}
}

fn test_data_view_constructor_rejects_calls_brands_offsets_and_checked_length_overflow() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	function := Value.from_object(realm.data_view_constructor_record())
	if _ := call(mut vm, function, js_null(), []Value{}) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == "DataView constructor must be called with 'new'"
	}
	for bad in [js_undefined(), js_null(), Value.from_i32(4),
		Value.from_object(Object.create(realm, none))] {
		if _ := construct(mut vm, function, [bad], none) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
			assert thrown_value(err).as_object().error_message()?.str() == '0x' +
				'0'.repeat(int(2 * sizeof(voidptr))) + ' is not an ArrayBuffer'
		}
	}
	buffer := allocate_array_buffer(mut vm, realm.array_buffer_constructor_record(), 1, none)!
	for offset in [Value.from_i32(-1), Value.from_i32(2), Value.from_f64(9007199254740991)] {
		if _ := construct(mut vm, function, [Value.from_object(buffer.object), offset], none) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .range_error
		}
	}
	if _ := construct(mut vm, function, [Value.from_object(buffer.object),
		Value.from_i32(1), Value.from_f64(4294967295)], none)
	{
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == 'Invalid DataView length'
	}
	view := construct(mut vm, function, [Value.from_object(buffer.object),
		Value.from_i32(1)], none)!.data_view?
	assert view.byte_length.length() == 0
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_data_view_constructor_rechecks_buffer_after_prototype_lookup_and_preserves_new_target_realm() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	local := vm.realm()
	foreign := create_simple_execution_context(mut vm).realm?
	vm.pop_execution_context()
	for mode in ['foreign', 'shrink offset', 'shrink length', 'detach', 'throw'] {
		mut buffer := allocate_array_buffer(mut vm, local.array_buffer_constructor_record(), 8,
			uint(12))!
		target := NativeFunction.create_constructor(mut vm, foreign, foreign.function_prototype,
			data_view_constructor_call, data_view_constructor_construct, 1,
			PropertyName.from_str('Target'))
		mut object := target.object
		object.define_native_accessor(mut vm, foreign, PropertyName.from_str('prototype'), fn [mut buffer, mode] (mut vm VM) !Value {
			if mode == 'shrink offset' { assert buffer.try_resize(1, true)
			 }
			if mode == 'shrink length' { assert buffer.try_resize(3, true)
			 }
			if mode == 'detach' { buffer.detach_buffer() }
			if mode == 'throw' { return throw_completion(Value.from_i32(42)) }
			return js_null()
		}, unsafe { nil }, 0, foreign.function_prototype)
		if result := construct(mut vm, Value.from_object(local.data_view_constructor_record()), [
			Value.from_object(buffer.object),
			Value.from_i32(2),
			Value.from_i32(4),
		], object)
		{
			assert mode == 'foreign'
			assert voidptr(result.internal_get_prototype_of()?) == voidptr(foreign.data_view_prototype_record())
		} else {
			if mode == 'throw' {
				assert thrown_value(err).number == 42
			} else {
				assert thrown_value(err).as_object().error_kind()? == if mode == 'detach' {
					ErrorKind.type_error
				} else {
					ErrorKind.range_error
				}
			}
		}
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}

fn test_data_view_constructor_coercions_precede_prototype_lookup_and_detached_checks() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	mut log := &ViewConstructorLog{}
	mut buffer := allocate_array_buffer(mut vm, realm.array_buffer_constructor_record(), 8,
		uint(12))!
	mut arguments := [Value.from_object(buffer.object)]
	for name in ['offset', 'length'] {
		mut argument := Object.create(realm, none)
		convert := NativeFunction.create(mut vm, realm, realm.function_prototype, fn [mut log, name] (mut vm VM) !Value {
			log.events << name
			return Value.from_i32(if name == 'offset' { 2 } else { 4 })
		}, 1, PropertyName.from_str('convert'), none)
		argument.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
			Value.from_object(convert.object), 7)
		arguments << Value.from_object(argument)
	}
	target := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype,
		data_view_constructor_call, data_view_constructor_construct, 1,
		PropertyName.from_str('Target'))
	mut object := target.object
	object.define_native_accessor(mut vm, realm, PropertyName.from_str('prototype'), fn [mut log] (mut vm VM) !Value {
		log.events << 'prototype'
		return js_null()
	}, unsafe { nil }, 0, realm.function_prototype)
	function := Value.from_object(realm.data_view_constructor_record())
	assert construct(mut vm, function, arguments, object)!.data_view?.byte_length.length() == 4
	assert log.events == ['offset', 'length', 'prototype']
	log.events.clear()
	buffer.detach_buffer()
	if _ := construct(mut vm, function, arguments, object) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	assert log.events == ['offset']
	log.events.clear()
	arguments[0] = js_null()
	if _ := construct(mut vm, function, arguments, object) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	assert log.events.len == 0
}
