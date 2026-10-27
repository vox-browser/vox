module libjs

import math

@[heap]
struct TypedArrayCopyLog {
mut:
	events []string
}

fn test_typed_array_same_type_copy_preserves_bytes_offsets_and_independent_fixed_storage() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	for shared_buffer in [false, true] {
		// A noncanonical quiet-NaN payload must survive a same-type byte clone.
		mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), [u8(1), 2, 3, 4, 5, 6, 7,
			8, 0xef, 0xbe, 0xad, 0xde, 0, 0, 0xf8, 0x7f, 0, 0, 0, 0, 0, 0, 0, 0x80, 9],
			shared_buffer, parent)
		buffer.maximum_byte_length = uint(32)
		mut source := TypedArray.create(vm.realm(), .float64, 0, buffer, parent)
		initialize_typed_array_from_array_buffer(mut vm, mut source, buffer, Value.from_i32(8),
			js_undefined())!
		empty := ArrayBufferObject.create(mut vm, vm.realm(), 0, parent)!
		mut target := TypedArray.create(vm.realm(), .float64, 0, empty, parent)
		initialize_typed_array_from_typed_array(mut vm, mut target, source)!
		assert target.array_length.length() == 2 && target.byte_length.length() == 16
			&& target.byte_offset == 0
		assert target.viewed_buffer.is_fixed_length()
			&& !target.viewed_buffer.is_shared_array_buffer()
		assert !target.viewed_buffer.shares_storage_with(buffer)
		assert target.viewed_buffer.read_bytes(0, 16) == buffer.read_bytes(8, 16)
		assert math.is_nan(typed_array_get_element(target, CanonicalIndex.create(.index, 0)).number)
		assert math.signbit(typed_array_get_element(target, CanonicalIndex.create(.index, 1)).number)
		typed_array_set_element(mut vm, mut target, CanonicalIndex.create(.index, 0),
			Value.from_i32(42))!
		assert buffer.read_bytes(8, 8) == [u8(0xef), 0xbe, 0xad, 0xde, 0, 0, 0xf8, 0x7f]
		assert target.object.properties.len == 0
	}
}

fn test_typed_array_cross_type_copy_converts_numbers_clamping_and_bigint_modulo() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	parent := Object.create(vm.realm(), none)
	empty := ArrayBufferObject.create(mut vm, vm.realm(), 0, parent)!
	mut source := TypedArray.create(vm.realm(), .float64, 0, empty, parent)
	initialize_typed_array_from_list(mut vm, mut source, [Value.from_f64(2.5),
		Value.from_f64(3.5), Value.from_i32(-1), Value.from_i32(300)])!
	mut clamped := TypedArray.create(vm.realm(), .uint8_clamped, 0, empty, parent)
	initialize_typed_array_from_typed_array(mut vm, mut clamped, source)!
	assert clamped.viewed_buffer.read_bytes(0, 4) == [u8(2), 4, 0, 255]
	mut signed := TypedArray.create(vm.realm(), .int8, 0, empty, parent)
	initialize_typed_array_from_typed_array(mut vm, mut signed, source)!
	assert signed.viewed_buffer.read_bytes(0, 4) == [u8(2), 3, 255, 44]
	mut big_source := TypedArray.create(vm.realm(), .big_int64, 0, empty, parent)
	initialize_typed_array_from_list(mut vm, mut big_source, [
		Value.from_bigint(string_to_bigint(utf16_string('-1')) or { panic('invalid BigInt literal') }),
		Value.from_bigint(string_to_bigint(utf16_string('42')) or { panic('invalid BigInt literal') }),
	])!
	mut big_unsigned := TypedArray.create(vm.realm(), .big_uint64, 0, empty, parent)
	initialize_typed_array_from_typed_array(mut vm, mut big_unsigned, big_source)!
	assert typed_array_get_element(big_unsigned, CanonicalIndex.create(.index, 0)).str() == '18446744073709551615n'
	assert typed_array_get_element(big_unsigned, CanonicalIndex.create(.index, 1)).str() == '42n'
	assert big_unsigned.byte_length.length() == 16
		&& !big_unsigned.viewed_buffer.shares_storage_with(big_source.viewed_buffer)
}

fn test_typed_array_copy_checks_source_bounds_before_allocation_and_content_type_after_allocation() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	parent := Object.create(realm, none)
	for mode in ['mismatch', 'prototype throws', 'out of bounds', 'detached'] {
		mut source_buffer := ArrayBufferObject.create(mut vm, realm, 4, parent)!
		source_buffer.maximum_byte_length = uint(8)
		source := TypedArray.create(realm, .int32, 1, source_buffer, parent)
		empty := ArrayBufferObject.create(mut vm, realm, 0, parent)!
		mut target := TypedArray.create(realm, .big_int64, 0, empty, parent)
		mut log := &TypedArrayCopyLog{}
		// Host-controlled intrinsic dependency makes allocation observable.
		constructor := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype, fn (mut vm VM) !Value {
			return js_undefined()
		}, fn (mut vm VM, target &Object) !&Object {
			return Object.create(vm.realm(), none)
		}, 1, PropertyName.from_str('HostBuffer'))
		mut object := constructor.object
		object.define_native_accessor(mut vm, realm, PropertyName.from_str('prototype'), fn [mut log, mode, parent] (mut vm VM) !Value {
			log.events << 'allocate'
			if mode == 'prototype throws' { return throw_completion(Value.from_i32(17)) }
			return Value.from_object(parent)
		}, unsafe { nil }, 0, realm.function_prototype)
		old := realm.array_buffer_constructor
		mut current := unsafe { &Realm(realm) }
		current.array_buffer_constructor = object
		if mode == 'out of bounds' { assert source_buffer.try_resize(3, true)
		 }
		if mode == 'detached' { detach_array_buffer(mut vm, mut source_buffer, none)! }
		if _ := initialize_typed_array_from_typed_array(mut vm, mut target, source) {
			assert false
		} else {
			if mode == 'prototype throws' {
				assert thrown_value(err).number == 17
			} else {
				assert thrown_value(err).as_object().error_kind()? == .type_error
			}
			if mode == 'mismatch' { assert thrown_value(err).as_object().error_message()?.str() == ErrorType.typed_array_content_type_mismatch.formatted('BigInt64Array', 'Int32Array')
			 }
		}
		current.array_buffer_constructor = old
		assert log.events == if mode in ['mismatch', 'prototype throws'] {
			['allocate']
		} else {
			[]string{}
		}
		assert voidptr(target.viewed_buffer) == voidptr(empty) && target.array_length.length() == 0
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}
