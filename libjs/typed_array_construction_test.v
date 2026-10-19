module libjs

import math

@[heap]
struct TypedArrayConstructionLog {
mut:
	events []string
	index  int
}

// Supply the untranslated intrinsic dependencies explicitly. Only the call
// and construct behaviors are under test; this is not a builtin installation.
fn typed_array_test_constructor(mut vm VM, realm &Realm, kind BufferElementType, prototype &Object, intrinsic_prototype IntrinsicPrototypeGetter) &NativeFunction {
	function := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype, fn [kind] (mut vm VM) !Value {
		return call_typed_array_constructor(mut vm, kind)
	}, fn [kind, intrinsic_prototype] (mut vm VM, target &Object) !&Object {
		array := construct_typed_array(mut vm, kind, target, intrinsic_prototype)!
		return array.object
	}, 3, PropertyName.from_str(kind.typed_array_name()))
	mut object := function.object
	object.define_direct_property(PropertyName.from_str('prototype'), Value.from_object(prototype),
		0)
	return function
}

fn test_typed_array_construction_all_kinds_empty_scalar_lengths_call_errors_and_cleanup() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	parent := Object.create(realm, none)
	for kind in [BufferElementType.big_int64, .big_uint64, .float16, .float32, .float64, .int8,
		.int16, .int32, .uint8, .uint16, .uint32, .uint8_clamped] {
		function := typed_array_test_constructor(mut vm, realm, kind, parent, fn (realm &Realm) &Object {
			return realm.data_view_prototype_record()
		})
		value := Value.from_object(function.object)
		for input in [js_undefined(), js_null(), Value.from_bool(true),
			Value.from_f64(2.9), Value.from_f64(math.nan()),
			Value.from_string(vm.create_string_from_str('3'))] {
			array := construct(mut vm, value, [input], none)!.typed_array?
			length := input.to_index(mut vm)!
			assert array.kind == kind && array.array_length.length() == u32(length)
			assert array.byte_length.length() == u32(length) * u32(kind.size())
				&& array.byte_offset == 0
			assert array.viewed_buffer.is_fixed_length() && !array.viewed_buffer.is_detached()
			assert voidptr(array.object.prototype?) == voidptr(parent)
		}
		assert construct(mut vm, value, []Value{}, none)!.typed_array?.array_length.length() == 0
		if _ := call(mut vm, value, js_undefined(), [Value.from_i32(2)]) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() ==
				kind.typed_array_name() + " constructor must be called with 'new'"
		}
		for input in [Value.from_i32(-1), Value.from_f64(math.inf(1)),
			Value.from_f64(9007199254740992), Value.from_f64(f64(0x7fffffff) / f64(kind.size()) + 1)] {
			if _ := construct(mut vm, value, [input], none) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_message()?.str() == 'Invalid typed array length'
			}
		}
		for input in [Value.from_bigint(string_to_bigint(utf16_string('1')) or { panic('invalid BigInt literal') }),
			Value.from_symbol(Symbol.create(none, .unique))] {
			if _ := construct(mut vm, value, [input], none) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .type_error
			}
		}
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}

fn test_typed_array_construction_uses_new_target_prototype_and_foreign_realm_fallback() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	local := vm.realm()
	foreign := create_simple_execution_context(mut vm).realm?
	vm.pop_execution_context()
	parent := Object.create(local, none)
	function := typed_array_test_constructor(mut vm, local, .uint16, parent, fn (realm &Realm) &Object {
		return realm.data_view_prototype_record()
	})
	for mode in ['fallback', 'object', 'throw'] {
		mut log := &TypedArrayConstructionLog{}
		custom := Object.create(foreign, none)
		target := NativeFunction.create_constructor(mut vm, foreign, foreign.function_prototype, fn (mut vm VM) !Value {
			return js_undefined()
		}, fn (mut vm VM, target &Object) !&Object {
			return Object.create(vm.realm(), none)
		}, 0, PropertyName.from_str('Target'))
		mut object := target.object
		object.define_native_accessor(mut vm, foreign, PropertyName.from_str('prototype'), fn [mut log, custom, mode] (mut vm VM) !Value {
			log.events << 'prototype'
			if mode == 'throw' { return throw_completion(Value.from_i32(17)) }
			return if mode == 'object' { Value.from_object(custom) } else { js_null() }
		}, unsafe { nil }, 0, foreign.function_prototype)
		if result := construct(mut vm, Value.from_object(function.object), [
			Value.from_i32(2),
		], target.object)
		{
			assert mode != 'throw'
			expected := if mode == 'object' { custom } else { foreign.data_view_prototype_record() }
			assert voidptr(result.prototype?) == voidptr(expected)
			assert result.typed_array?.array_length.length() == 2
			assert voidptr(result.typed_array?.viewed_buffer.object.prototype?) == voidptr(local.array_buffer_prototype_record())
		} else {
			assert mode == 'throw' && thrown_value(err).number == 17
		}
		assert log.events == ['prototype']
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}

fn test_typed_array_construction_object_branch_never_uses_to_index_and_gets_prototype_before_offsets() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	parent := Object.create(realm, none)
	function := typed_array_test_constructor(mut vm, realm, .uint16, parent, fn (realm &Realm) &Object {
		return realm.data_view_prototype_record()
	})
	mut source := Object.create(realm, none)
	convert := NativeFunction.create(mut vm, realm, realm.function_prototype, fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(99))
	}, 0, PropertyName.from_str('valueOf'), none)
	source.define_direct_property(PropertyName.from_str('valueOf'),
		Value.from_object(convert.object), 7)
	source.define_direct_property(PropertyName.from_str('length'), Value.from_i32(1), 7)
	source.define_direct_property(PropertyName.from_number(0), Value.from_i32(42), 7)
	array := construct(mut vm, Value.from_object(function.object), [
		Value.from_object(source),
	], none)!.typed_array?
	assert array.array_length.length() == 1
		&& typed_array_get_element(array, CanonicalIndex.create(.index, 0)).number == 42
	for mode in ['success', 'prototype throws', 'prototype detaches', 'offset throws'] {
		mut log := &TypedArrayConstructionLog{}
		mut buffer := ArrayBufferObject.create(mut vm, realm, 8, parent)!
		target := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype, fn (mut vm VM) !Value {
			return js_undefined()
		}, fn (mut vm VM, target &Object) !&Object {
			return Object.create(vm.realm(), none)
		}, 0, PropertyName.from_str('Target'))
		mut target_object := target.object
		target_object.define_native_accessor(mut vm, realm, PropertyName.from_str('prototype'), fn [mut log, mut buffer, parent, mode] (mut vm VM) !Value {
			log.events << 'prototype'
			if mode == 'prototype throws' { return throw_completion(Value.from_i32(17)) }
			if mode == 'prototype detaches' { detach_array_buffer(mut vm, mut buffer, none)! }
			return Value.from_object(parent)
		}, unsafe { nil }, 0, realm.function_prototype)
		mut offset := Object.create(realm, none)
		offset_method := NativeFunction.create(mut vm, realm, realm.function_prototype, fn [mut log, mode] (mut vm VM) !Value {
			log.events << 'offset'
			if mode == 'offset throws' { return throw_completion(Value.from_i32(42)) }
			return Value.from_i32(2)
		}, 0, PropertyName.from_str('valueOf'), none)
		offset.define_direct_property(PropertyName.from_str('valueOf'),
			Value.from_object(offset_method.object), 7)
		if result := construct(mut vm, Value.from_object(function.object), [
			Value.from_object(buffer.object),
			Value.from_object(offset),
		], target.object)
		{
			assert mode == 'success' && result.typed_array?.byte_offset == 2
				&& result.typed_array?.array_length.length() == 3
		} else {
			if mode == 'prototype detaches' {
				assert thrown_value(err).as_object().error_kind()? == .type_error
			} else {
				assert thrown_value(err).number == if mode == 'prototype throws' {
					17
				} else {
					42
				}
			}
		}
		assert log.events == if mode == 'prototype throws' {
			['prototype']
		} else {
			['prototype', 'offset']
		}
	}
}

fn test_typed_array_construction_collects_iterators_before_converting_and_does_not_close_on_next_errors() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	parent := Object.create(realm, none)
	function := typed_array_test_constructor(mut vm, realm, .uint8, parent, fn (realm &Realm) &Object {
		return realm.data_view_prototype_record()
	})
	for mode in ['success', 'next throws', 'conversion throws'] {
		mut log := &TypedArrayConstructionLog{}
		mut iterator := Object.create(realm, none)
		mut source := Object.create(realm, none)
		next := NativeFunction.create(mut vm, realm, realm.function_prototype, fn [mut log, mode] (mut vm VM) !Value {
			index := log.index
			log.index++
			log.events << 'next ${index}'
			if index == 1 && mode == 'next throws' { return throw_completion(Value.from_i32(17)) }
			if index == 2 {
				return Value.from_object(create_iterator_result_object(vm.realm(), js_undefined(),
					true, none))
			}
			mut value := Object.create(vm.realm(), none)
			convert := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut log, index, mode] (mut vm VM) !Value {
				log.events << 'convert ${index}'
				if index == 1 && mode == 'conversion throws' {
					return throw_completion(Value.from_i32(42))
				}
				return Value.from_i32(42 + index)
			}, 0, PropertyName.from_str('valueOf'), none)
			value.define_direct_property(PropertyName.from_str('valueOf'),
				Value.from_object(convert.object), 7)
			return Value.from_object(create_iterator_result_object(vm.realm(),
				Value.from_object(value), false, none))
		}, 0, PropertyName.from_str('next'), none)
		iterator.define_direct_property(PropertyName.from_str('next'),
			Value.from_object(next.object), 7)
		close := NativeFunction.create(mut vm, realm, realm.function_prototype, fn [mut log] (mut vm VM) !Value {
			log.events << 'return'
			return js_undefined()
		}, 0, PropertyName.from_str('return'), none)
		iterator.define_direct_property(PropertyName.from_str('return'),
			Value.from_object(close.object), 7)
		method := NativeFunction.create(mut vm, realm, realm.function_prototype, fn [mut log, iterator, source] (mut vm VM) !Value {
			assert same_value(vm.this_value(), Value.from_object(source))
			log.events << 'iterator'
			return Value.from_object(iterator)
		}, 0, PropertyName.from_str('iterator'), none)
		source.define_native_accessor(mut vm, realm,
			PropertyName.from_symbol(vm.well_known_symbol_iterator()), fn [mut log, method] (mut vm VM) !Value {
			log.events << 'get iterator'
			return Value.from_object(method.object)
		}, unsafe { nil }, 0, realm.function_prototype)
		source.define_native_accessor(mut vm, realm, PropertyName.from_str('length'), fn (mut vm VM) !Value {
			return throw_completion(Value.from_i32(99))
		}, unsafe { nil }, 0, realm.function_prototype)
		if result := construct(mut vm, Value.from_object(function.object), [
			Value.from_object(source),
		], none)
		{
			assert mode == 'success'
				&& result.typed_array?.viewed_buffer.read_bytes(0, 2) == [u8(42), 43]
		} else {
			assert mode != 'success' && thrown_value(err).number == if mode == 'next throws' {
				17
			} else {
				42
			}
		}
		assert log.events == if mode == 'next throws' {
			['get iterator', 'iterator', 'next 0', 'next 1']
		} else {
			['get iterator', 'iterator', 'next 0', 'next 1', 'next 2', 'convert 0', 'convert 1']
		}
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}

fn test_typed_array_construction_copies_records_before_iterator_lookup_and_supports_bound_construction() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	parent := Object.create(realm, none)
	function := typed_array_test_constructor(mut vm, realm, .uint16, parent, fn (realm &Realm) &Object {
		return realm.data_view_prototype_record()
	})
	buffer := ArrayBufferObject.create_from_bytes(realm, [u8(42), 17], false, parent)
	source := TypedArray.create(realm, .uint8, 2, buffer, parent)
	mut object := source.object
	object.define_native_accessor(mut vm, realm,
		PropertyName.from_symbol(vm.well_known_symbol_iterator()), fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(99))
	}, unsafe { nil }, 0, realm.function_prototype)
	copy := construct(mut vm, Value.from_object(function.object), [
		Value.from_object(object),
	], none)!.typed_array?
	assert copy.viewed_buffer.read_bytes(0, 4) == [u8(42), 0, 17, 0]
	assert !copy.viewed_buffer.shares_storage_with(buffer)
	bound := BoundFunction.create(realm, function.object, js_null(), [
		Value.from_object(object),
	])
	bound_copy := construct(mut vm, Value.from_object(bound.object), []Value{}, none)!.typed_array?
	assert bound_copy.array_length.length() == 2
		&& bound_copy.viewed_buffer.read_bytes(0, 4) == [u8(42), 0, 17, 0]
	assert voidptr(bound_copy.object.prototype?) == voidptr(parent)
}

fn test_typed_array_construction_bad_iterator_method_precedes_array_like_length() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	parent := Object.create(realm, none)
	function := typed_array_test_constructor(mut vm, realm, .uint8, parent, fn (realm &Realm) &Object {
		return realm.data_view_prototype_record()
	})
	for method in [Value.from_i32(1), Value.from_bool(true), Value.from_object(parent)] {
		mut source := Object.create(realm, none)
		source.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_iterator()),
			method, 7)
		source.define_native_accessor(mut vm, realm, PropertyName.from_str('length'), fn (mut vm VM) !Value {
			return throw_completion(Value.from_i32(99))
		}, unsafe { nil }, 0, realm.function_prototype)
		if _ := construct(mut vm, Value.from_object(function.object), [
			Value.from_object(source),
		], none)
		{
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
}
