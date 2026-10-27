module libjs

@[heap]
struct TypedSubarrayLog {
mut:
	arguments []Value
	events    []string
}

fn typed_subarray_call(mut vm VM, source &TypedArray, arguments []Value, parent &Object) !&TypedArray {
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
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [lookup, getter] (mut vm VM) !Value {
		return typed_array_prototype_subarray(mut vm, PrimitiveObjectPrototypes{}, lookup, getter)
	}, 2, PropertyName.from_str('subarray'), none)
	result := call(mut vm, Value.from_object(function.object), Value.from_object(source.object),
		arguments)!
	return result.as_object().typed_array or { panic('fixture') }
}

fn test_typed_array_subarray_all_kinds_preserve_buffer_identity_offsets_and_tracking_lengths() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for kind in [BufferElementType.big_int64, .big_uint64, .float16, .float32, .float64, .int8,
		.int16, .int32, .uint8, .uint16, .uint32, .uint8_clamped] {
		for shared_buffer in [false, true] {
			for tracking in [false, true] {
				mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(),
					[]u8{len: int(kind.size() * 5)}, shared_buffer, parent)
				buffer.maximum_byte_length = kind.size() * 8
				mut source := TypedArray.create(vm.realm(), kind, 0, buffer, parent)
				initialize_typed_array_from_array_buffer(mut vm, mut source, buffer,
					Value.from_f64(f64(kind.size())), if tracking {
					js_undefined()
				} else {
					Value.from_i32(4)
				})!
				result := typed_subarray_call(mut vm, source, [
					Value.from_i32(-3)], parent)!
				assert result.kind == kind && result.byte_offset == kind.size() * 2
				assert voidptr(result.viewed_buffer) == voidptr(buffer)
				assert result.array_length.is_auto() == tracking
				assert typed_array_length(make_typed_array_with_buffer_witness_record(result,
					.seq_cst)) == 3
				assert buffer.try_resize(kind.size() * 7, true)
				assert typed_array_length(make_typed_array_with_buffer_witness_record(result,
					.seq_cst)) == if tracking {
					u32(5)
				} else {
					u32(3)
				}
				fixed_result := typed_subarray_call(mut vm, source, [
					Value.from_i32(1),
					Value.from_i32(3),
				], parent)!
				assert !fixed_result.array_length.is_auto()
					&& fixed_result.array_length.length() == 2
				assert fixed_result.byte_offset == kind.size() * 2
			}
		}
	}
}

fn test_typed_array_subarray_species_receives_two_arguments_only_for_tracking_without_end() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for tracking in [false, true] {
		for explicit_end in [false, true] {
			mut buffer := ArrayBufferObject.create(mut vm, vm.realm(), 16, parent)!
			buffer.maximum_byte_length = uint(32)
			mut source := TypedArray.create(vm.realm(), .uint16, 0, buffer, parent)
			initialize_typed_array_from_array_buffer(mut vm, mut source, buffer, Value.from_i32(2), if tracking {
				js_undefined()
			} else {
				Value.from_i32(7)
			})!
			mut log := &TypedSubarrayLog{}
			constructor := NativeFunction.create_constructor(mut vm, vm.realm(),
				vm.realm().function_prototype, fn (mut vm VM) !Value {
				return js_undefined()
			}, fn [parent, mut log] (mut vm VM, target &Object) !&Object {
				log.arguments = vm.running_execution_context().arguments().clone()
				getter := fn [parent] (realm &Realm) &Object {
					return parent
				}
				return construct_typed_array(mut vm, .uint8, target, getter)!.object
			}, 3, PropertyName.from_str('Species'))
			mut holder := Object.create(vm.realm(), none)
			holder.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_species()),
				Value.from_object(constructor.object), 7)
			mut object := source.object
			object.define_direct_property(PropertyName.from_str('constructor'),
				Value.from_object(holder), 7)
			result := typed_subarray_call(mut vm, source, [Value.from_i32(2), if explicit_end {
				Value.from_i32(5)
			} else {
				js_undefined()
			}], parent)!
			assert result.kind == .uint8 && result.byte_offset == 6
			assert voidptr(log.arguments[0].as_object()) == voidptr(buffer.object)
			assert log.arguments[1].number == 6
			assert log.arguments.len == if tracking && !explicit_end {
				2
			} else {
				3
			}
			if log.arguments.len == 3 { assert log.arguments[2].number == if explicit_end {
					3
				} else {
					5
				}
			 }
			assert result.array_length.is_auto() == (tracking && !explicit_end)
			assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
		}
	}
}

fn test_typed_array_subarray_out_of_bounds_source_coerces_begin_and_end_before_default_initialization() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for mode in ['detached', 'out of bounds', 'custom detached'] {
		mut buffer := ArrayBufferObject.create(mut vm, vm.realm(), 4, parent)!
		buffer.maximum_byte_length = uint(8)
		mut source := TypedArray.create(vm.realm(), .uint8, 0, buffer, parent)
		initialize_typed_array_from_array_buffer(mut vm, mut source, buffer, Value.from_i32(2),
			Value.from_i32(2))!
		if mode == 'out of bounds' {
			assert buffer.try_resize(1, true)
		} else {
			detach_array_buffer(mut vm, mut buffer, none)!
		}
		mut log := &TypedSubarrayLog{}
		mut arguments := []Value{}
		for name in ['begin', 'end'] {
			mut object := Object.create(vm.realm(), none)
			function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [name, mut log] (mut vm VM) !Value {
				log.events << name
				return Value.from_i32(1)
			}, 1, PropertyName.from_str(name), none)
			object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
				Value.from_object(function.object), 7)
			arguments << Value.from_object(object)
		}
		mut object := source.object
		if mode == 'custom detached' {
			destination := TypedArray.create(vm.realm(), .uint8, 0, ArrayBufferObject.create(mut vm,
				vm.realm(), 0, parent)!, parent)
			constructor := NativeFunction.create_constructor(mut vm, vm.realm(),
				vm.realm().function_prototype, fn (mut vm VM) !Value {
				return js_undefined()
			}, fn [buffer, destination] (mut vm VM, target &Object) !&Object {
				assert vm.argument_count() == 3 && vm.argument(1).number == 2
					&& vm.argument(2).number == 0
				assert voidptr(vm.argument(0).as_object()) == voidptr(buffer.object)
				return destination.object
			}, 3, PropertyName.from_str('Species'))
			mut holder := Object.create(vm.realm(), none)
			holder.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_species()),
				Value.from_object(constructor.object), 7)
			object.define_direct_property(PropertyName.from_str('constructor'),
				Value.from_object(holder), 7)
		}
		if result := typed_subarray_call(mut vm, source, arguments, parent) {
			assert mode == 'custom detached' && result.array_length.length() == 0
		} else {
			assert mode != 'custom detached'
			assert thrown_value(err).as_object().error_kind()? == if mode == 'detached' {
				ErrorKind.type_error
			} else {
				ErrorKind.range_error
			}
		}
		assert log.events == ['begin', 'end']
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}
