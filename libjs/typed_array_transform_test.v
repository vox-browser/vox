module libjs

@[heap]
struct TypedTransformLog {
mut:
	events  []string
	values  []Value
	created ?&TypedArray
}

fn typed_transform_number_string(value Value) string {
	return if value.is_bigint() { value.as_bigint().big_integer.str() } else { value.str() }
}

fn typed_transform_call(mut vm VM, name string, source Value, arguments []Value, parent &Object) !Value {
	constructor := NativeFunction.create_constructor(mut vm, vm.realm(),
		vm.realm().function_prototype, fn (mut vm VM) !Value {
		return js_undefined()
	}, fn (mut vm VM, target &Object) !&Object {
		panic('default Construct must be bypassed')
	}, 1, PropertyName.from_str('Intrinsic'))
	lookup := fn [constructor] (realm &Realm, kind BufferElementType) &Object {
		return constructor.object
	}
	getter := fn [parent] (realm &Realm, kind BufferElementType) &Object {
		return parent
	}
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [name, lookup, getter] (mut vm VM) !Value {
		return if name == 'filter' {
			typed_array_prototype_filter(mut vm, PrimitiveObjectPrototypes{}, lookup, getter)!
		} else {
			typed_array_prototype_map(mut vm, PrimitiveObjectPrototypes{}, lookup, getter)!
		}
	}, 1, PropertyName.from_str(name), none)
	return call(mut vm, Value.from_object(function.object), source, arguments)
}

fn test_typed_array_filter_map_all_kinds_capture_values_and_keep_callback_this_and_arguments() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	parent := Object.create(realm, none)
	for name in ['filter', 'map'] {
		for shared_buffer in [false, true] {
			for kind in [BufferElementType.big_int64, .big_uint64, .float16, .float32, .float64,
				.int8, .int16, .int32, .uint8, .uint16, .uint32, .uint8_clamped] {
				buffer := ArrayBufferObject.create_from_bytes(realm,
					[]u8{len: int(kind.size() * 3)}, shared_buffer, parent)
				mut source := TypedArray.create(realm, kind, 3, buffer, parent)
				for index in 0 .. 3 {
					value := if kind.is_bigint() {
						Value.from_bigint(string_to_bigint(utf16_string((index + 1).str())) or { panic('invalid BigInt literal') })
					} else {
						Value.from_i32(index + 1)
					}
					typed_array_set_element(mut vm, mut source, CanonicalIndex.create(.index,
						u32(index)), value)!
				}
				mut log := &TypedTransformLog{}
				mut object := source.object
				object.define_native_accessor(mut vm, realm, PropertyName.from_str('constructor'), fn [mut log] (mut vm VM) !Value {
					log.events << 'species'
					return js_undefined()
				}, unsafe { nil }, attribute_configurable, realm.function_prototype)
				callback := NativeFunction.create(mut vm, realm, realm.function_prototype, fn [source, kind, name, mut log] (mut vm VM) !Value {
					assert vm.this_value().number == 42 && vm.argument_count() == 3
					assert voidptr(vm.argument(2).as_object()) == voidptr(source.object)
					index := vm.argument(1).as_i32()
					log.events << 'callback${index}'
					log.values << vm.argument(0)
					// Change this entry after its value was captured, and a future entry before it is read.
					mut array := source
					typed_array_set_element(mut vm, mut array, CanonicalIndex.create(.index,
						u32(index)), if kind.is_bigint() { Value.from_bigint(string_to_bigint(utf16_string('90')) or {
							panic('fixture')}) } else { Value.from_i32(90) })!
					if index == 0 {
						typed_array_set_element(mut vm, mut array,
							CanonicalIndex.create(.index, 1), if kind.is_bigint() { Value.from_bigint(string_to_bigint(utf16_string('8')) or {
								panic('fixture')}) } else { Value.from_i32(8) })!
					}
					return if name == 'filter' {
						Value.from_bool(index != 1)
					} else {
						vm.argument(0)
					}
				}, 3, PropertyName.from_str('callback'), none)
				result := typed_transform_call(mut vm, name, Value.from_object(source.object), [
					Value.from_object(callback.object),
					Value.from_i32(42),
				], parent)!.as_object().typed_array?
				assert result.kind == kind && !result.viewed_buffer.shares_storage_with(buffer)
				expected := if name == 'filter' { [1, 3] } else { [1, 8, 3] }
				assert result.array_length.length() == expected.len
				for index, value in expected {
					assert typed_transform_number_string(typed_array_get_element(result, CanonicalIndex.create(.index,
						u32(index)))) == value.str()
				}
				assert log.values.map(typed_transform_number_string(it)) == ['1', '8', '3']
				assert log.events == if name == 'filter' {
					['callback0', 'callback1', 'callback2', 'species']
				} else {
					['species', 'callback0', 'callback1', 'callback2']
				}
				assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
			}
		}
	}
}

fn test_typed_array_filter_map_fixed_iteration_length_with_live_resizing_and_detachment() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for name in ['filter', 'map'] {
		for mode in ['shrink', 'grow', 'detach'] {
			mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(1), 2, 3], false,
				parent)
			buffer.maximum_byte_length = uint(8)
			mut source := TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
			initialize_typed_array_from_array_buffer(mut vm, mut source, buffer, Value.from_i32(0),
				js_undefined())!
			mut log := &TypedTransformLog{}
			callback := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [name, mode, mut buffer, mut log] (mut vm VM) !Value {
				log.values << vm.argument(0)
				if vm.argument(1).number == 0 {
					if mode == 'detach' { detach_array_buffer(mut vm, mut buffer, none)! } else { assert buffer.try_resize(if mode == 'shrink' {
							uint(1)
						} else {
							uint(5)
						}, true)
					 }
				}
				return if name == 'filter' { Value.from_bool(true) } else { vm.argument(0) }
			}, 3, PropertyName.from_str('callback'), none)
			result := typed_transform_call(mut vm, name, Value.from_object(source.object), [
				Value.from_object(callback.object),
			], parent)!.as_object().typed_array?
			assert result.array_length.length() == 3 && log.values.len == 3
			assert log.values[0].number == 1
			if mode == 'grow' {
				assert result.viewed_buffer.read_bytes(0, 3) == [u8(1), 2, 3]
			} else {
				assert log.values[1].is_undefined() && log.values[2].is_undefined()
				assert result.viewed_buffer.read_bytes(0, 3) == [u8(1), 0, 0]
			}
		}
	}
}

fn test_typed_array_filter_map_species_result_can_change_numeric_kind_and_alias_source() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for name in ['filter', 'map'] {
		for alias in [false, true] {
			buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(1), 2, 3, 4], false,
				parent)
			source := TypedArray.create(vm.realm(), .uint8, 3, buffer, parent)
			mut destination := if alias {
				TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
			} else {
				TypedArray.create(vm.realm(), .float64, 3, ArrayBufferObject.create(mut vm,
					vm.realm(), 24, parent)!, parent)
			}
			if alias {
				initialize_typed_array_from_array_buffer(mut vm, mut destination, buffer,
					Value.from_i32(1), Value.from_i32(3))!
			}
			mut log := &TypedTransformLog{}
			constructor := NativeFunction.create_constructor(mut vm, vm.realm(),
				vm.realm().function_prototype, fn (mut vm VM) !Value {
				return js_undefined()
			}, fn [destination, mut log] (mut vm VM, target &Object) !&Object {
				log.events << 'construct'
				assert vm.argument_count() == 1 && vm.argument(0).number == 3
				return destination.object
			}, 1, PropertyName.from_str('Species'))
			mut holder := Object.create(vm.realm(), none)
			holder.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_species()),
				Value.from_object(constructor.object), 7)
			mut object := source.object
			object.define_direct_property(PropertyName.from_str('constructor'),
				Value.from_object(holder), 7)
			callback := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [name, mut log] (mut vm VM) !Value {
				log.values << vm.argument(0)
				return if name == 'filter' {
					Value.from_bool(true)
				} else {
					Value.from_f64(vm.argument(0).number + 10)
				}
			}, 3, PropertyName.from_str('callback'), none)
			result := typed_transform_call(mut vm, name, Value.from_object(source.object), [
				Value.from_object(callback.object),
			], parent)!.as_object().typed_array?
			assert voidptr(result) == voidptr(destination)
			if name == 'map' && alias {
				assert log.values.map(it.number) == [f64(1), 11, 21]
			} else {
				assert log.values.map(it.number) == [f64(1), 2, 3]
			}
			for index in 0 .. 3 {
				expected := if name == 'filter' {
					f64(index + 1)
				} else if alias {
					f64((index + 1) * 10 + 1)
				} else {
					f64(index + 11)
				}
				assert typed_array_get_element(result, CanonicalIndex.create(.index, u32(index))).number == expected
			}
		}
	}
}

fn test_typed_array_filter_map_callback_errors_and_map_partial_coercion_writes() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for name in ['filter', 'map'] {
		buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(1), 2, 3], false, parent)
		source := TypedArray.create(vm.realm(), .uint8, 3, buffer, parent)
		mut log := &TypedTransformLog{}
		mut object := source.object
		object.define_native_accessor(mut vm, vm.realm(), PropertyName.from_str('constructor'), fn [mut log] (mut vm VM) !Value {
			log.events << 'species'
			return js_undefined()
		}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
		for arguments in [[]Value{}, [js_undefined()], [Value.from_i32(42)]] {
			if _ := typed_transform_call(mut vm, name, Value.from_object(object), arguments, parent) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .type_error
			}
			assert log.events.len == 0
		}
		callback := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut log] (mut vm VM) !Value {
			log.events << 'callback'
			return throw_completion(Value.from_i32(99))
		}, 3, PropertyName.from_str('callback'), none)
		if _ := typed_transform_call(mut vm, name, Value.from_object(object), [
			Value.from_object(callback.object),
		], parent)
		{
			assert false
		} else {
			assert thrown_value(err).number == 99
		}
		assert log.events == if name == 'filter' {
			['callback']
		} else {
			['species', 'callback']
		}
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
	buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(1), 2, 3], false, parent)
	source := TypedArray.create(vm.realm(), .uint8, 3, buffer, parent)
	destination := TypedArray.create(vm.realm(), .uint8, 3, ArrayBufferObject.create(mut vm,
		vm.realm(), 3, parent)!, parent)
	constructor := NativeFunction.create_constructor(mut vm, vm.realm(),
		vm.realm().function_prototype, fn (mut vm VM) !Value {
		return js_undefined()
	}, fn [destination] (mut vm VM, target &Object) !&Object {
		return destination.object
	}, 1, PropertyName.from_str('Species'))
	mut holder := Object.create(vm.realm(), none)
	holder.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_species()),
		Value.from_object(constructor.object), 7)
	mut object := source.object
	object.define_direct_property(PropertyName.from_str('constructor'), Value.from_object(holder),
		7)
	mut mapped := Object.create(vm.realm(), none)
	mapped.define_native_accessor(mut vm, vm.realm(),
		PropertyName.from_symbol(vm.well_known_symbol_to_primitive()), fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(77))
	}, unsafe { nil }, attribute_configurable, vm.realm().function_prototype)
	mut log := &TypedTransformLog{}
	callback := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mapped, mut log] (mut vm VM) !Value {
		log.values << vm.argument(0)
		return if vm.argument(1).number == 0 {
			Value.from_i32(42)
		} else {
			Value.from_object(mapped)
		}
	}, 3, PropertyName.from_str('callback'), none)
	if _ := typed_transform_call(mut vm, 'map', Value.from_object(object), [
		Value.from_object(callback.object),
	], parent)
	{
		assert false
	} else {
		assert thrown_value(err).number == 77
	}
	assert destination.viewed_buffer.read_bytes(0, 3) == [u8(42), 0, 0]
	assert log.values.len == 2
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
