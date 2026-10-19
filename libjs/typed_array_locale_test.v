module libjs

@[heap]
struct TypedLocaleLog {
mut:
	values []Value
	events []string
}

fn typed_locale_call(mut vm VM, source &TypedArray, arguments []Value, parent &Object) !Value {
	getter := fn [parent] (realm &Realm) &Object {
		return parent
	}
	prototypes := PrimitiveObjectPrototypes{
		number: getter
		bigint: getter
		string: getter
	}
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [prototypes] (mut vm VM) !Value {
		return typed_array_prototype_to_locale_string(mut vm, prototypes)
	}, 0, PropertyName.from_str('toLocaleString'), none)
	return call(mut vm, Value.from_object(function.object), Value.from_object(source.object),
		arguments)
}

fn test_typed_array_to_locale_string_all_kinds_invoke_primitives_with_locales_and_options() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut parent := Object.create(vm.realm(), none)
	locales := Object.create(vm.realm(), none)
	options := Object.create(vm.realm(), none)
	for kind in [BufferElementType.big_int64, .big_uint64, .float16, .float32, .float64, .int8,
		.int16, .int32, .uint8, .uint16, .uint32, .uint8_clamped] {
		buffer := ArrayBufferObject.create(mut vm, vm.realm(), kind.size() * 2, parent)!
		mut source := TypedArray.create(vm.realm(), kind, 2, buffer, parent)
		for index in 0 .. 2 {
			value := if kind.is_bigint() {
				Value.from_bigint(string_to_bigint(utf16_string((index + 1).str())) or { panic('invalid BigInt literal') })
			} else {
				Value.from_i32(index + 1)
			}
			typed_array_set_element(mut vm, mut source, CanonicalIndex.create(.index, u32(index)),
				value)!
		}
		mut log := &TypedLocaleLog{}
		function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [kind, locales, options, mut log] (mut vm VM) !Value {
			assert vm.this_value().is_bigint() == kind.is_bigint()
			assert vm.argument_count() == 2
			assert voidptr(vm.argument(0).as_object()) == voidptr(locales)
			assert voidptr(vm.argument(1).as_object()) == voidptr(options)
			log.values << vm.this_value()
			return Value.from_string(vm.create_string(Utf16String{ data: [
				u16(0xd800 + log.values.len),
			] }))
		}, 0, PropertyName.from_str('locale'), none)
		parent.define_direct_property(PropertyName.from_str('toLocaleString'),
			Value.from_object(function.object), 7)
		result := typed_locale_call(mut vm, source, [Value.from_object(locales),
			Value.from_object(options)], parent)!
		assert result.as_string().utf16.data == [u16(0xd801), u16(`,`), 0xd802]
		assert log.values.len == 2
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}

fn test_typed_array_to_locale_string_live_reads_follow_locale_result_coercion_mutations() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for mode in ['shrink', 'detach', 'grow'] {
		mut parent := Object.create(vm.realm(), none)
		mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(1), 2, 3], false, parent)
		buffer.maximum_byte_length = usize(8)
		mut source := TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
		initialize_typed_array_from_array_buffer(mut vm, mut source, buffer, Value.from_i32(0),
			js_undefined())!
		mut log := &TypedLocaleLog{}
		mut result_object := Object.create(vm.realm(), none)
		to_string := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mode, mut buffer, mut log] (mut vm VM) !Value {
			log.events << 'string'
			if mode == 'detach' { detach_array_buffer(mut vm, mut buffer, none)! } else { assert buffer.try_resize(if mode == 'shrink' {
					usize(1)
				} else {
					usize(5)
				}, true)
			 }
			return Value.from_string(vm.create_string_from_str('first'))
		}, 0, PropertyName.from_str('toString'), none)
		result_object.define_direct_property(PropertyName.from_str('toString'),
			Value.from_object(to_string.object), 7)
		function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [result_object, mut log] (mut vm VM) !Value {
			assert vm.argument_count() == 2 && vm.argument(0).is_undefined()
				&& vm.argument(1).is_undefined()
			log.values << vm.this_value()
			log.events << 'locale'
			return if log.values.len == 1 {
				Value.from_object(result_object)
			} else {
				vm.this_value()
			}
		}, 0, PropertyName.from_str('locale'), none)
		parent.define_direct_property(PropertyName.from_str('toLocaleString'),
			Value.from_object(function.object), 7)
		result := typed_locale_call(mut vm, source, []Value{}, parent)!
		assert result.as_string().str() == if mode == 'grow' {
			'first,2,3'
		} else {
			'first,,'
		}
		assert log.values.len == if mode == 'grow' {
			3
		} else {
			1
		}
		assert log.events[0..2] == ['locale', 'string']
	}
}

fn test_typed_array_to_locale_string_empty_avoids_lookup_and_propagates_lookup_call_and_string_errors() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	for mode in ['getter', 'noncallable', 'call', 'symbol'] {
		mut parent := Object.create(vm.realm(), none)
		mut log := &TypedLocaleLog{}
		function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mode, mut log] (mut vm VM) !Value {
			log.events << 'call'
			if mode == 'call' { return throw_completion(Value.from_i32(77)) }
			return Value.from_symbol(vm.well_known_symbol_iterator())
		}, 0, PropertyName.from_str('locale'), none)
		parent.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('toLocaleString'), fn [mode, function, mut log] (mut vm VM) !Value {
			log.events << 'get'
			assert vm.this_value().number == 1
			if mode == 'getter' { return throw_completion(Value.from_i32(99)) }
			return if mode == 'noncallable' { js_null() } else { Value.from_object(function.object) }
		}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
		empty := TypedArray.create(vm.realm(), .uint8, 0, ArrayBufferObject.create(mut vm,
			vm.realm(), 0, parent)!, parent)
		result := typed_locale_call(mut vm, empty, []Value{}, parent)!
		assert result.as_string().utf16.len() == 0 && log.events.len == 0
		source := TypedArray.create(vm.realm(), .uint8, 1, ArrayBufferObject.create_from_bytes(vm.realm(), [
			u8(1),
		], false, parent), parent)
		if _ := typed_locale_call(mut vm, source, []Value{}, parent) {
			assert false
		} else {
			value := thrown_value(err)
			if mode == 'getter' {
				assert value.number == 99
			} else if mode == 'call' {
				assert value.number == 77
			} else {
				assert value.as_object().error_kind()? == .type_error
			}
		}
		assert log.events == if mode in ['getter', 'noncallable'] {
			['get']
		} else {
			['get', 'call']
		}
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}
