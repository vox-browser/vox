module libjs

fn test_typed_array_of_conversion_errors_preserve_prior_writes_and_restore_outer_arguments() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	abstract :=
		TypedArrayConstructor.create(mut vm, vm.realm(), parent, PrimitiveObjectPrototypes{})
	mut log := &TypedStaticLog{}
	constructor := typed_static_fixture(mut vm, .uint8, parent, mut log)
	mut throwing := Object.create(vm.realm(), none)
	convert := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut log] (mut vm VM) !Value {
		log.events << 'convert'
		array := log.created or { panic('fixture') }
		assert array.viewed_buffer.read_bytes(0, 3) == [u8(42), 0, 0]
		return throw_completion(Value.from_i32(77))
	}, 1, PropertyName.from_str('convert'), none)
	throwing.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(convert.object), 7)
	if _ := typed_static_method_call(mut vm, abstract, 'of', Value.from_object(constructor), [
		Value.from_i32(42),
		Value.from_object(throwing),
		Value.from_i32(43),
	])
	{
		assert false
	} else {
		assert thrown_value(err).number == 77
	}
	assert log.events == ['construct', 'convert']
	assert (log.created or { panic('fixture') }).viewed_buffer.read_bytes(0, 3) == [
		u8(42),
		0,
		0,
	]
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn typed_static_iterable(mut vm VM, mut log TypedStaticLog, mode string, parent &Object) &Object {
	mut iterator := Object.create(vm.realm(), parent)
	next := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut log, mode, parent] (mut vm VM) !Value {
		index := log.index
		log.index++
		log.events << 'next${index}'
		if mode == 'next throws' && index == 1 { return throw_completion(Value.from_i32(77)) }
		return Value.from_object(create_iterator_result_object(vm.realm(),
			Value.from_i32(index + 1), index == 3, parent))
	}, 0, PropertyName.from_str('next'), none)
	iterator.define_direct_property(PropertyName.from_str('next'), Value.from_object(next.object),
		7)
	iterator.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('return'), fn (mut vm VM) !Value {
		panic('completed/abrupt IteratorToList does not close')
	}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
	mut iterable := Object.create(vm.realm(), parent)
	iterable.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('length'), fn (mut vm VM) !Value {
		panic('iterable length must not be read')
	}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
	method := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [iterator] (mut vm VM) !Value {
		return Value.from_object(iterator)
	}, 0, PropertyName.from_str('iterator'), none)
	iterable.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_iterator()),
		Value.from_object(method.object), 7)
	return iterable
}

fn test_typed_array_from_collects_iterable_before_construction_mapping_and_conversion() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	abstract :=
		TypedArrayConstructor.create(mut vm, vm.realm(), parent, PrimitiveObjectPrototypes{})
	for mode in ['normal', 'next throws', 'map throws'] {
		mut log := &TypedStaticLog{}
		constructor := typed_static_fixture(mut vm, .uint8, parent, mut log)
		source := typed_static_iterable(mut vm, mut log, mode, parent)
		callback := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mode, mut log] (mut vm VM) !Value {
			index := vm.argument(1).as_i32()
			assert log.index == 4 && vm.argument_count() == 2 && vm.this_value().number == 10
			log.events << 'map${index}'
			if mode == 'map throws' && index == 1 { return throw_completion(Value.from_i32(88)) }
			return Value.from_f64(vm.argument(0).number + 10)
		}, 2, PropertyName.from_str('map'), none)
		if value := typed_static_method_call(mut vm, abstract, 'from',
			Value.from_object(constructor), [Value.from_object(source),
			Value.from_object(callback.object), Value.from_i32(10)])
		{
			assert mode == 'normal'
			result := value.as_object().typed_array?
			assert result.viewed_buffer.read_bytes(0, 3) == [u8(11), 12, 13]
		} else {
			assert thrown_value(err).number == if mode == 'next throws' {
				77
			} else {
				88
			}
		}
		assert log.events == match mode {
			'normal' { ['next0', 'next1', 'next2', 'next3', 'construct', 'map0', 'map1', 'map2'] }
			'next throws' { ['next0', 'next1'] }
			else { ['next0', 'next1', 'next2', 'next3', 'construct', 'map0', 'map1'] }
		}

		if mode == 'map throws' { assert (log.created or { panic('fixture') }).viewed_buffer.read_bytes(0, 3) == [
				u8(11),
				0,
				0,
			]
		 }
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}

fn test_typed_array_from_supports_primitive_string_iterator_and_nullish_iterator_array_like_path() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut parent := Object.create(vm.realm(), none)
	getter := fn [parent] (realm &Realm) &Object {
		return parent
	}
	prototypes := PrimitiveObjectPrototypes{
		number: getter
		bigint: getter
		string: getter
	}
	abstract := TypedArrayConstructor.create(mut vm, vm.realm(), parent, prototypes)
	mut log := &TypedStaticLog{}
	constructor := typed_static_fixture(mut vm, .uint8, parent, mut log)
	for iterator_value in [js_null(), js_undefined()] {
		parent.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_iterator()),
			iterator_value, 7)
		result := typed_static_method_call(mut vm, abstract, 'from',
			Value.from_object(constructor), [
			Value.from_string(vm.create_string_from_str('123')),
		])!.as_object().typed_array?
		assert result.viewed_buffer.read_bytes(0, 3) == [u8(1), 2, 3]
	}
	iterator_prototype := StringIteratorPrototype.create(mut vm, vm.realm(), parent, parent)
	iterator := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [iterator_prototype] (mut vm VM) !Value {
		assert vm.this_value().is_string()
		return Value.from_object(StringIterator.create(vm.realm(),
			vm.this_value().as_string().utf16, iterator_prototype.object).object)
	}, 0, PropertyName.from_str('iterator'), none)
	parent.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_iterator()),
		Value.from_object(iterator.object), 7)
	result := typed_static_method_call(mut vm, abstract, 'from', Value.from_object(constructor), [
		Value.from_string(vm.create_string_from_str('123')),
	])!.as_object().typed_array?
	assert result.viewed_buffer.read_bytes(0, 3) == [u8(1), 2, 3]
}

fn test_typed_array_from_of_validate_constructor_mapping_and_result_before_element_reads() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	abstract :=
		TypedArrayConstructor.create(mut vm, vm.realm(), parent, PrimitiveObjectPrototypes{})
	mut source := Object.create(vm.realm(), none)
	source.define_native_accessor(mut vm, vm.realm(),
		PropertyName.from_symbol(vm.well_known_symbol_iterator()), fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(99))
	}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
	if _ := typed_static_method_call(mut vm, abstract, 'from', Value.from_i32(42), [
		Value.from_object(source),
		Value.from_i32(7),
	])
	{
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == '42 is not a constructor'
	}
	mut log := &TypedStaticLog{}
	constructor := typed_static_fixture(mut vm, .uint8, parent, mut log)
	if _ := typed_static_method_call(mut vm, abstract, 'from', Value.from_object(constructor), [
		Value.from_object(source),
		Value.from_i32(7),
	])
	{
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == '7 is not a function'
	}
	if _ := typed_static_method_call(mut vm, abstract, 'from', Value.from_object(constructor), [
		Value.from_object(source),
	])
	{
		assert false
	} else {
		assert thrown_value(err).number == 99
	}
	assert log.events.len == 0
	for nullish in [js_null(), js_undefined()] {
		if _ := typed_static_method_call(mut vm, abstract, 'from', Value.from_object(constructor), [
			nullish,
		])
		{
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == 'ToObject on null or undefined'
		}
	}
	for mode in ['short', 'wrong brand', 'detached'] {
		mut buffer := ArrayBufferObject.create(mut vm, vm.realm(), 1, parent)!
		array := TypedArray.create(vm.realm(), .uint8, 1, buffer, parent)
		if mode == 'detached' { detach_array_buffer(mut vm, mut buffer, none)! }
		bad := NativeFunction.create_constructor(mut vm, vm.realm(), vm.realm().function_prototype, fn (mut vm VM) !Value {
			return js_undefined()
		}, fn [array, mode, parent] (mut vm VM, target &Object) !&Object {
			return if mode == 'wrong brand' { parent } else { array.object }
		}, 1, PropertyName.from_str('Bad'))
		mut input := Object.create(vm.realm(), none)
		input.define_direct_property(PropertyName.from_str('length'), Value.from_i32(2), 7)
		input.define_native_accessor(mut vm, vm.realm(), PropertyName.from_number(0), fn (mut vm VM) !Value {
			panic('result validation precedes input elements')
		}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
		for name in ['from', 'of'] {
			arguments := if name == 'from' { [Value.from_object(input)] } else { [
					Value.from_i32(42),
					Value.from_i32(43),
				] }
			if _ := typed_static_method_call(mut vm, abstract, name, Value.from_object(bad.object),
				arguments)
			{
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .type_error
			}
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

@[heap]
struct TypedStaticLog {
mut:
	events    []string
	created   ?&TypedArray
	arguments []Value
	index     int
}

fn typed_static_fixture(mut vm VM, kind BufferElementType, parent &Object, mut log TypedStaticLog) &Object {
	constructor := NativeFunction.create_constructor(mut vm, vm.realm(),
		vm.realm().function_prototype, fn (mut vm VM) !Value {
		return js_undefined()
	}, fn [kind, parent, mut log] (mut vm VM, target &Object) !&Object {
		log.events << 'construct'
		log.arguments = vm.running_execution_context().arguments().clone()
		getter := fn [parent] (realm &Realm) &Object {
			return parent
		}
		result := construct_typed_array(mut vm, kind, target, getter)!
		log.created = result
		return result.object
	}, 3, PropertyName.from_str('Host'))
	return constructor.object
}

fn typed_static_method_call(mut vm VM, abstract &TypedArrayConstructor, name string, constructor Value, arguments []Value) !Value {
	method := abstract.object.get(mut vm, PropertyName.from_str(name))!
	return call(mut vm, method, constructor, arguments)
}

fn test_typed_array_abstract_constructor_metadata_species_and_call_construct_cleanup() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	parent := Object.create(realm, none)
	abstract := TypedArrayConstructor.create(mut vm, realm, parent, PrimitiveObjectPrototypes{})
	keys := abstract.object.own_property_keys()
	assert keys == [PropertyName.from_str('prototype'), PropertyName.from_str('from'),
		PropertyName.from_str('of'), PropertyName.from_str('length'),
		PropertyName.from_str('name'), PropertyName.from_symbol(vm.well_known_symbol_species())]
	assert Value.from_object(abstract.object).is_constructor()
	assert voidptr(abstract.object.prototype?) == voidptr(realm.function_prototype_record())
	assert voidptr(parent.get_without_side_effects(PropertyName.from_str('constructor')).as_object()) == voidptr(abstract.object)
	for name, length in {
		'from': 1.0
		'of':   0.0
	} {
		property := abstract.object.internal_get_own_property(PropertyName.from_str(name))?
		assert property.writable? && property.configurable? && !property.enumerable?
		method := property.value?.as_object()
		assert method.get_without_side_effects(PropertyName.from_str('length')).number == length
		assert method.get_without_side_effects(PropertyName.from_str('name')).as_string().str() == name
		assert !Value.from_object(method).is_constructor()
	}
	prototype_property :=
		abstract.object.internal_get_own_property(PropertyName.from_str('prototype'))?
	assert !prototype_property.writable? && !prototype_property.configurable?
		&& !prototype_property.enumerable?
	for receiver in [Value.from_object(abstract.object), Value.from_i32(42),
		js_null(), js_undefined()] {
		value := abstract.object.internal_get(mut vm,
			PropertyName.from_symbol(vm.well_known_symbol_species()), receiver)!
		assert same_value(value, receiver)
	}
	for mode in ['call', 'construct', 'bound call', 'bound construct'] {
		bound := BoundFunction.create(realm, abstract.object, js_undefined(), [
			Value.from_i32(42),
		])
		target := Value.from_object(if mode.starts_with('bound') {
			bound.object
		} else {
			abstract.object
		})
		if mode.ends_with('call') {
			if _ := call(mut vm, target, js_undefined(), [Value.from_i32(7)]) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_message()?.str() == 'Abstract class TypedArray cannot be constructed directly'
			}
		} else {
			if _ := construct(mut vm, target, [Value.from_i32(7)], none) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_message()?.str() == 'Abstract class TypedArray cannot be constructed directly'
			}
		}
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}

fn test_typed_array_of_all_kinds_uses_argument_count_and_converts_in_order_without_species() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	abstract :=
		TypedArrayConstructor.create(mut vm, vm.realm(), parent, PrimitiveObjectPrototypes{})
	for kind in [BufferElementType.big_int64, .big_uint64, .float16, .float32, .float64, .int8,
		.int16, .int32, .uint8, .uint16, .uint32, .uint8_clamped] {
		mut log := &TypedStaticLog{}
		constructor := typed_static_fixture(mut vm, kind, parent, mut log)
		mut arguments := []Value{}
		for number in [42, 17, 3] {
			arguments << if kind.is_bigint() {
				Value.from_bigint(string_to_bigint(utf16_string(number.str())) or { panic('invalid BigInt literal') })
			} else {
				Value.from_i32(number)
			}
		}
		result := typed_static_method_call(mut vm, abstract, 'of', Value.from_object(constructor),
			arguments)!.as_object().typed_array?
		assert result.kind == kind && result.array_length.length() == 3
		assert log.arguments == [Value.from_i32(3)]
		for index, value in arguments {
			assert same_value(typed_array_get_element(result, CanonicalIndex.create(.index,
				u32(index))), value)
		}
		empty := typed_static_method_call(mut vm, abstract, 'of', Value.from_object(constructor),
			[]Value{})!.as_object().typed_array?
		assert empty.array_length.length() == 0
	}
}

fn test_typed_array_from_array_like_gets_captured_length_then_interleaves_mapping_and_live_getters() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	abstract :=
		TypedArrayConstructor.create(mut vm, vm.realm(), parent, PrimitiveObjectPrototypes{})
	mut log := &TypedStaticLog{}
	constructor := typed_static_fixture(mut vm, .uint8, parent, mut log)
	mut source := Object.create(vm.realm(), none)
	source.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('length'), fn [mut log] (mut vm VM) !Value {
		log.events << 'length'
		return Value.from_i32(3)
	}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
	for index in 0 .. 3 {
		source.define_native_accessor(mut vm, vm.realm(), PropertyName.from_number(u32(index)), fn [index, mut log] (mut vm VM) !Value {
			log.events << 'get${index}'
			if index == 1 { assert typed_array_get_element(log.created or { panic('fixture') }, CanonicalIndex.create(.index, 0)).number == 11
			 }
			return Value.from_i32(index + 1)
		}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
	}
	callback := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [source, mut log] (mut vm VM) !Value {
		assert vm.this_value().number == 10 && vm.argument_count() == 2
		index := vm.argument(1).as_i32()
		log.events << 'map${index}'
		mut object := source
		object.define_direct_property(PropertyName.from_str('length'), Value.from_i32(0), 7)
		return Value.from_f64(vm.argument(0).number + vm.this_value().number)
	}, 2, PropertyName.from_str('map'), none)
	result := typed_static_method_call(mut vm, abstract, 'from', Value.from_object(constructor), [
		Value.from_object(source),
		Value.from_object(callback.object),
		Value.from_i32(10),
	])!.as_object().typed_array?
	assert result.viewed_buffer.read_bytes(0, 3) == [u8(11), 12, 13]
	assert log.events == ['length', 'construct', 'get0', 'map0', 'get1', 'map1', 'get2', 'map2']
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
