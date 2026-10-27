module libjs

import math

@[heap]
struct ViewOperationLog {
mut:
	events []string
}

fn view_method(mut vm VM, view &DataView, name string, arguments []Value) !Value {
	function := vm.realm().data_view_prototype_record().get(mut vm, PropertyName.from_str(name))!
	return call(mut vm, function, Value.from_object(view.object), arguments)
}

fn test_data_view_prototype_installs_all_methods_getters_and_upstream_metadata() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	prototype := realm.data_view_prototype_record()
	mut keys := []string{}
	for prefix in ['get', 'set'] {
		for suffix in ['BigInt64', 'BigUint64', 'Float16', 'Float32', 'Float64', 'Int8', 'Int16',
			'Int32', 'Uint8', 'Uint16', 'Uint32'] {
			name := prefix + suffix
			keys << name
			descriptor := prototype.internal_get_own_property(PropertyName.from_str(name))?
			assert descriptor.writable? && descriptor.configurable? && !descriptor.enumerable?
			function := descriptor.value?.as_object()
			assert function.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == name
			assert function.get(mut vm, PropertyName.from_str('length'))!.number == if prefix == 'get' {
				1
			} else {
				2
			}
			assert voidptr(function.internal_get_prototype_of()?) == voidptr(realm.function_prototype_record())
			if _ := call(mut vm, Value.from_object(function), Value.from_object(prototype), [
				Value.from_i32(-1),
			])
			{
				assert false
			} else {
				assert thrown_value(err).as_object().error_message()?.str() == 'Not an object of type DataView'
			}
		}
	}
	for name in ['buffer', 'byteLength', 'byteOffset'] {
		keys << name
		descriptor := prototype.internal_get_own_property(PropertyName.from_str(name))?
		assert descriptor.configurable? && !descriptor.enumerable?
			&& descriptor.setter?.is_undefined()
		getter := descriptor.getter?.as_object()
		assert getter.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == 'get ' + name
		assert getter.get(mut vm, PropertyName.from_str('length'))!.number == 0
		if _ := call(mut vm, Value.from_object(getter), js_null(), []Value{}) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
	keys << ['constructor', 'Symbol(Symbol.toStringTag)']
	assert prototype.own_property_keys().map(it.str()) == keys
	tag :=
		prototype.internal_get_own_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()))?
	assert tag.value?.as_string().str() == 'DataView'
	assert tag.configurable? && !tag.enumerable? && !tag.writable?
}

fn test_data_view_all_numeric_pairs_write_at_the_offset_and_handle_byte_order() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	buffer := allocate_array_buffer(mut vm, realm.array_buffer_constructor_record(), 16, none)!
	view := DataView.create(realm, buffer, ByteLength.from_u32(12), 2,
		realm.data_view_prototype_record())
	for name in ['BigInt64', 'BigUint64', 'Float16', 'Float32', 'Float64', 'Int8', 'Int16', 'Int32',
		'Uint8', 'Uint16', 'Uint32'] {
		for little_endian in [false, true] {
			value := if name.starts_with('Big') {
				Value.from_bigint(string_to_bigint(utf16_string('42')) or { panic('invalid BigInt literal') })
			} else {
				Value.from_i32(42)
			}
			assert view_method(mut vm, view, 'set' + name, [Value.from_i32(1), value,
				Value.from_bool(little_endian)])!.is_undefined()
			result := view_method(mut vm, view, 'get' + name, [
				Value.from_i32(1),
				Value.from_bool(little_endian),
			])!
			assert same_value(result, value)
			assert buffer.read_bytes(0, 3) == [u8(0), 0, 0]
		}
	}
	assert view_method(mut vm, view, 'setUint16', [Value.from_i32(0),
		Value.from_i32(0x1234)])!.is_undefined()
	assert buffer.read_bytes(2, 2) == [u8(0x12), 0x34]
	assert view_method(mut vm, view, 'getUint16', [Value.from_i32(0)])!.number == 0x1234
	assert view_method(mut vm, view, 'getUint16', [Value.from_i32(0),
		Value.from_bool(true)])!.number == 0x3412
	for signed in [false, true] {
		name := if signed { 'BigInt64' } else { 'BigUint64' }
		value := Value.from_bigint(string_to_bigint(utf16_string('-18446744073709551617')) or { panic('invalid BigInt literal') })
		assert view_method(mut vm, view, 'set' + name, [Value.from_i32(0), value])!.is_undefined()
		result := view_method(mut vm, view, 'get' + name, [Value.from_i32(0)])!
		assert result.as_bigint().big_integer.str() == if signed {
			'-1'
		} else {
			'18446744073709551615'
		}
	}
}

fn test_data_view_getters_and_numeric_methods_recompute_fixed_and_tracking_bounds() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	mut buffer := allocate_array_buffer(mut vm, realm.array_buffer_constructor_record(), 8,
		uint(12))!
	fixed := DataView.create(realm, buffer, ByteLength.from_u32(4), 2,
		realm.data_view_prototype_record())
	tracking := DataView.create(realm, buffer, ByteLength.auto_length(), 2,
		realm.data_view_prototype_record())
	for view in [fixed, tracking] {
		assert voidptr(view.object.get(mut vm, PropertyName.from_str('buffer'))!.as_object()) == voidptr(buffer.object)
		assert view.object.get(mut vm, PropertyName.from_str('byteOffset'))!.number == 2
	}
	assert buffer.try_resize(4, true)
	assert tracking.object.get(mut vm, PropertyName.from_str('byteLength'))!.number == 2
	assert view_method(mut vm, tracking, 'setUint8', [Value.from_i32(1),
		Value.from_i32(42)])!.is_undefined()
	assert view_method(mut vm, tracking, 'getUint8', [Value.from_i32(1)])!.number == 42
	for name in ['byteOffset', 'byteLength'] {
		if _ := fixed.object.get(mut vm, PropertyName.from_str(name)) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
	if _ := view_method(mut vm, tracking, 'getUint16', [Value.from_i32(1)]) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .range_error
	}
	if _ := view_method(mut vm, fixed, 'getUint8', [Value.from_i32(0)]) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	assert buffer.try_resize(8, true)
	assert fixed.object.get(mut vm, PropertyName.from_str('byteLength'))!.number == 4
	assert tracking.object.get(mut vm, PropertyName.from_str('byteLength'))!.number == 6
	assert view_method(mut vm, fixed, 'getUint8', [Value.from_i32(2)])!.number == 0
	buffer.detach_buffer()
	for view in [fixed, tracking] {
		assert voidptr(view.object.get(mut vm, PropertyName.from_str('buffer'))!.as_object()) == voidptr(buffer.object)
		if _ := view_method(mut vm, view, 'getUint8', []Value{}) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
}

fn test_data_view_setters_convert_index_and_value_before_bounds_and_never_coerce_endian() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	for mode in ['normal', 'index throws', 'value throws', 'value detaches', 'value shrinks',
		'out of range'] {
		mut log := &ViewOperationLog{}
		mut buffer := allocate_array_buffer(mut vm, realm.array_buffer_constructor_record(), 8,
			uint(12))!
		view := DataView.create(realm, buffer, ByteLength.from_u32(4), 2,
			realm.data_view_prototype_record())
		mut arguments := []Value{}
		for name in ['index', 'value', 'endian'] {
			mut argument := Object.create(realm, none)
			convert := NativeFunction.create(mut vm, realm, realm.function_prototype, fn [mut log, mut buffer, mode, name] (mut vm VM) !Value {
				log.events << name
				if mode == name + ' throws' { return throw_completion(Value.from_i32(42)) }
				if name == 'value' && mode == 'value detaches' { buffer.detach_buffer() }
				if name == 'value' && mode == 'value shrinks' { assert buffer.try_resize(3, true)
				 }
				return Value.from_i32(if name == 'index' {
					if mode == 'out of range' { 4 } else { 0 }
				} else {
					42
				})
			}, 1, PropertyName.from_str('convert'), none)
			argument.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
				Value.from_object(convert.object), 7)
			arguments << Value.from_object(argument)
		}
		if _ := view_method(mut vm, view, 'setUint16', arguments) {
			assert mode == 'normal' && buffer.read_bytes(2, 2) == [u8(42), 0]
		} else {
			if mode in ['index throws', 'value throws'] {
				assert thrown_value(err).number == 42
			} else {
				assert thrown_value(err).as_object().error_kind()? == if mode == 'out of range' {
					ErrorKind.range_error
				} else {
					ErrorKind.type_error
				}
			}
		}
		assert log.events == if mode == 'index throws' {
			['index']
		} else {
			['index', 'value']
		}
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}

fn test_data_view_float_special_values_bigint_type_errors_and_large_indices() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	buffer := allocate_array_buffer(mut vm, realm.array_buffer_constructor_record(), 8, none)!
	view := DataView.create(realm, buffer, ByteLength.from_u32(8), 0,
		realm.data_view_prototype_record())
	for name in ['Float16', 'Float32', 'Float64'] {
		for value in [Value.from_f64(-0.0), Value.from_f64(math.nan()),
			Value.from_f64(math.inf(-1))] {
			assert view_method(mut vm, view, 'set' + name, [Value.from_i32(0), value])!.is_undefined()
			assert same_value(view_method(mut vm, view, 'get' + name, [
				Value.from_i32(0),
			])!, value)
		}
	}
	for name in ['setBigInt64', 'setBigUint64'] {
		if _ := view_method(mut vm, view, name, [Value.from_i32(0),
			Value.from_i32(42)])
		{
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
	if _ := view_method(mut vm, view, 'setUint32', [Value.from_i32(0),
		Value.from_bigint(string_to_bigint(utf16_string('42')) or { panic('invalid BigInt literal') })])
	{
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .type_error
	}
	for name in ['getUint8', 'getFloat64'] {
		if _ := view_method(mut vm, view, name, [Value.from_f64(9007199254740991)]) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .range_error
		}
	}
	shared_buffer := ArrayBufferObject.create_from_bytes(realm, [u8(0), 0], true,
		realm.array_buffer_prototype_record())
	shared_view := DataView.create(realm, shared_buffer, ByteLength.from_u32(2), 0,
		realm.data_view_prototype_record())
	assert view_method(mut vm, shared_view, 'setUint16', [Value.from_i32(0),
		Value.from_i32(42)])!.is_undefined()
	assert view_method(mut vm, shared_view, 'getUint16', [Value.from_i32(0)])!.number == 42
}
