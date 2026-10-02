module libjs

fn string_raw_test_prototypes(parent &Object) PrimitiveObjectPrototypes {
	return PrimitiveObjectPrototypes{
		number: fn [parent] (realm &Realm) &Object {
			return parent
		}
		bigint: fn [parent] (realm &Realm) &Object {
			return parent
		}
		string: fn [parent] (realm &Realm) &Object {
			return parent
		}
	}
}

fn string_raw_call(mut vm VM, prototypes PrimitiveObjectPrototypes, arguments []Value) !Value {
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [prototypes] (mut vm VM) !Value {
		return string_constructor_raw(mut vm, prototypes)
	}, 1, PropertyName.from_str('raw'), none)
	return call(mut vm, Value.from_object(function.object), js_null(), arguments)
}

fn test_string_raw_preserves_literal_units_substitution_count_and_primitive_raw_boxing() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	prototypes := string_raw_test_prototypes(parent)
	mut raw := Object.create(vm.realm(), none)
	raw.define_direct_property(PropertyName.from_str('length'), Value.from_i32(2), 7)
	raw.define_direct_property(PropertyName.from_number(0),
		Value.from_string(vm.create_string_from_str('foo ')), 7)
	raw.define_direct_property(PropertyName.from_number(1),
		Value.from_string(vm.create_string_from_str('\\nbar')), 7)
	mut cooked := Object.create(vm.realm(), none)
	cooked.define_direct_property(PropertyName.from_str('raw'), Value.from_object(raw), 7)
	assert string_raw_call(mut vm, prototypes, [Value.from_object(cooked),
		Value.from_i32(10), Value.from_symbol(Symbol.create(none, .unique))])!.as_string().str() == 'foo 10\\nbar'
	assert string_raw_call(mut vm, prototypes, [Value.from_object(cooked)])!.as_string().str() == 'foo \\nbar'
	raw.define_direct_property(PropertyName.from_number(0), Value.from_string(vm.create_string(Utf16String.from_slice([
		u16(0xd800),
		0,
	]))), 7)
	raw.define_direct_property(PropertyName.from_number(1), Value.from_string(vm.create_string(Utf16String.from_slice([
		u16(0xdc00),
	]))), 7)
	assert string_raw_call(mut vm, prototypes, [Value.from_object(cooked),
		Value.from_i32(65)])!.as_string().utf16.data == [u16(0xd800), 0, u16(`6`), u16(`5`), 0xdc00]
	cooked.define_direct_property(PropertyName.from_str('raw'),
		Value.from_string(vm.create_string_from_str('AB')), 7)
	assert string_raw_call(mut vm, prototypes, [Value.from_object(cooked),
		Value.from_i32(10)])!.as_string().str() == 'A10B'
	for value in [Value.from_i32(1), Value.from_bool(true),
		Value.from_symbol(Symbol.create(none, .unique))] {
		cooked.define_direct_property(PropertyName.from_str('raw'), value, 7)
		assert string_raw_call(mut vm, prototypes, [Value.from_object(cooked)])!.as_string().is_empty()
	}
	for length in [0.0, -1.0, 0.9] {
		raw.define_direct_property(PropertyName.from_str('length'), Value.from_f64(length), 7)
		cooked.define_direct_property(PropertyName.from_str('raw'), Value.from_object(raw), 7)
		assert string_raw_call(mut vm, prototypes, [Value.from_object(cooked),
			Value.from_symbol(Symbol.create(none, .unique))])!.as_string().is_empty()
	}
	for arguments in [[]Value{}, [js_null()], [Value.from_object(Object.create(vm.realm(), none))]] {
		if _ := string_raw_call(mut vm, prototypes, arguments) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == 'ToObject on null or undefined'
		}
	}
}

@[heap]
struct StringRawLog {
mut:
	events []string
}

fn string_raw_test_coercible(mut vm VM, mut log StringRawLog, name string, throws bool) Value {
	mut object := Object.create(vm.realm(), none)
	conversion := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [name, throws, mut log] (mut vm VM) !Value {
		assert vm.argument(0).as_string().str() == 'string'
		log.events << name
		if throws { return throw_completion(Value.from_i32(77)) }
		return Value.from_string(vm.create_string_from_str(name))
	}, 1, PropertyName.from_str('coerce'), none)
	object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(conversion.object), 7)
	return Value.from_object(object)
}

fn test_string_raw_snapshots_length_but_reads_live_literals_and_converts_interleaved_substitutions() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut log := &StringRawLog{}
	parent := Object.create(vm.realm(), none)
	prototypes := string_raw_test_prototypes(parent)
	mut raw := Object.create(vm.realm(), none)
	mut cooked := Object.create(vm.realm(), none)
	cooked.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('raw'), fn [raw, mut log] (mut vm VM) !Value {
		log.events << 'get raw'
		return Value.from_object(raw)
	}, unsafe { nil }, 7, vm.realm().function_prototype)
	raw.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('length'), fn [mut log] (mut vm VM) !Value {
		log.events << 'length'
		return Value.from_i32(3)
	}, unsafe { nil }, 7, vm.realm().function_prototype)
	for index in 0 .. 3 {
		value := string_raw_test_coercible(mut vm, mut log, 'literal${index}', false)
		raw.define_native_accessor(mut vm, vm.realm(), PropertyName.from_number(u32(index)), fn [index, value, mut log] (mut vm VM) !Value {
			log.events << 'get ${index}'
			return value
		}, unsafe { nil }, 7, vm.realm().function_prototype)
	}
	first := string_raw_test_coercible(mut vm, mut log, 'sub0', false)
	second := string_raw_test_coercible(mut vm, mut log, 'sub1', false)
	result := string_raw_call(mut vm, prototypes, [Value.from_object(cooked), first, second,
		js_null()])!
	assert result.as_string().str() == 'literal0sub0literal1sub1literal2'
	assert log.events == ['get raw', 'length', 'get 0', 'literal0', 'sub0', 'get 1', 'literal1',
		'sub1', 'get 2', 'literal2']
	log.events.clear()
	thrower := string_raw_test_coercible(mut vm, mut log, 'throw', true)
	if _ := string_raw_call(mut vm, prototypes, [Value.from_object(cooked), thrower, second]) {
		assert false
	} else {
		assert thrown_value(err).number == 77
	}
	assert log.events == ['get raw', 'length', 'get 0', 'literal0', 'throw']
	log.events.clear()
	// A later literal stays live even when conversion changes its property.
	mutation := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut raw] (mut vm VM) !Value {
		raw.define_direct_property(PropertyName.from_number(1),
			Value.from_string(vm.create_string_from_str('changed')), 7)
		raw.define_direct_property(PropertyName.from_str('length'), Value.from_i32(1), 7)
		return Value.from_string(vm.create_string_from_str('|'))
	}, 0, PropertyName.from_str('mutate'), none)
	mut substitute := Object.create(vm.realm(), none)
	substitute.define_direct_property(PropertyName.from_str('toString'),
		Value.from_object(mutation.object), 7)
	result_live := string_raw_call(mut vm, prototypes, [Value.from_object(cooked),
		Value.from_object(substitute)])!
	assert result_live.as_string().str() == 'literal0|changedliteral2'
	assert log.events == ['get raw', 'length', 'get 0', 'literal0', 'get 2', 'literal2']
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
