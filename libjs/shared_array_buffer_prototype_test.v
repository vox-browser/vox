module libjs

import math

@[heap]
struct SharedPrototypeLog {
mut:
	events []string
}

fn shared_buffer_method(mut vm VM, buffer &ArrayBufferObject, name string, arguments []Value) !Value {
	method := vm.realm().shared_array_buffer_prototype_record().get(mut vm,
		PropertyName.from_str(name))!
	return call(mut vm, method, Value.from_object(buffer.object), arguments)
}

fn test_shared_array_buffer_prototype_metadata_and_brand_checks_match_upstream() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	prototype := realm.shared_array_buffer_prototype_record()
	assert prototype.own_property_keys().map(it.str()) == ['byteLength', 'grow', 'growable',
		'maxByteLength', 'slice', 'constructor', 'Symbol(Symbol.toStringTag)']
	for maximum in [?uint(none), ?uint(8)] {
		buffer := allocate_shared_array_buffer(mut vm,
			realm.shared_array_buffer_constructor_record(), 2, maximum)!
		ordinary := allocate_array_buffer(mut vm, realm.array_buffer_constructor_record(), 2,
			maximum)!
		for name in ['byteLength', 'growable', 'maxByteLength'] {
			descriptor := prototype.internal_get_own_property(PropertyName.from_str(name))?
			assert descriptor.configurable? && !descriptor.enumerable?
				&& descriptor.setter?.is_undefined()
			getter := descriptor.getter?.as_object()
			assert getter.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == 'get ' +
				name
			assert getter.get(mut vm, PropertyName.from_str('length'))!.number == 0
			value := buffer.object.get(mut vm, PropertyName.from_str(name))!
			if name == 'growable' {
				assert value.as_bool() == (maximum != none)
			} else {
				assert value.number == if name == 'byteLength' {
					2.0
				} else {
					f64(maximum or { uint(2) })
				}
			}
			for receiver in [js_null(), Value.from_object(prototype),
				Value.from_object(ordinary.object)] {
				if _ := call(mut vm, Value.from_object(getter), receiver, []Value{}) {
					assert false
				} else {
					assert thrown_value(err).as_object().error_message()?.str() == if
						receiver.is_object()
						&& voidptr(receiver.as_object()) == voidptr(ordinary.object) {
						'The array buffer object must be a SharedArrayBuffer'
					} else {
						'Not an object of type SharedArrayBuffer'
					}
				}
			}
		}
		for index, name in ['grow', 'slice'] {
			descriptor := prototype.internal_get_own_property(PropertyName.from_str(name))?
			assert descriptor.writable? && descriptor.configurable? && !descriptor.enumerable?
			function := descriptor.value?.as_object()
			assert function.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == name
			assert function.get(mut vm, PropertyName.from_str('length'))!.number == index + 1
			if _ := call(mut vm, Value.from_object(function), Value.from_object(prototype), [
				Value.from_i32(-1),
			])
			{
				assert false
			} else {
				assert thrown_value(err).as_object().error_message()?.str() == 'Not an object of type SharedArrayBuffer'
			}
			if _ := shared_buffer_method(mut vm, ordinary, name, [
				Value.from_i32(-1),
			])
			{
				assert false
			} else {
				assert thrown_value(err).as_object().error_message()?.str() == if name == 'grow'
					&& maximum == none {
					'ArrayBuffer is not resizable'
				} else {
					'The array buffer object must be a SharedArrayBuffer'
				}
			}
		}
	}
	tag :=
		prototype.internal_get_own_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()))?
	assert tag.value?.as_string().str() == 'SharedArrayBuffer'
	assert tag.configurable? && !tag.writable? && !tag.enumerable?
}

fn test_shared_array_buffer_growth_keeps_bytes_zeroes_extensions_and_updates_data_view_witnesses() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	mut buffer := allocate_shared_array_buffer(mut vm,
		realm.shared_array_buffer_constructor_record(), 5, uint(10))!
	buffer.overwrite(0, [u8(1), 2, 3, 4, 5])
	fixed := DataView.create(realm, buffer, ByteLength.from_u32(2), 1,
		realm.data_view_prototype_record())
	tracking := DataView.create(realm, buffer, ByteLength.auto_length(), 1,
		realm.data_view_prototype_record())
	for size in 5 .. 11 {
		assert shared_buffer_method(mut vm, buffer, 'grow', [
			Value.from_i32(size),
		])!.is_undefined()
		assert buffer.is_shared_array_buffer() && buffer.byte_length() == uint(size)
		assert buffer.read_bytes(0, 5) == [u8(1), 2, 3, 4, 5]
		assert buffer.read_bytes(5, uint(size - 5)) == []u8{len: size - 5}
		assert fixed.object.get(mut vm, PropertyName.from_str('byteLength'))!.number == 2
		assert tracking.object.get(mut vm, PropertyName.from_str('byteLength'))!.number == size - 1
	}
	assert buffer.max_byte_length() == 10 && buffer.data_block().capacity() >= 10
	setter := realm.data_view_prototype_record().get(mut vm, PropertyName.from_str('setUint8'))!
	assert call(mut vm, setter, Value.from_object(tracking.object), [
		Value.from_i32(8),
		Value.from_i32(42),
	])!.is_undefined()
	assert buffer.read_bytes(9, 1) == [u8(42)]
}

fn test_shared_array_buffer_growth_calls_host_before_equality_and_limits_and_restores_abrupt_frames() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	for mode in ['handled', 'unhandled', 'throw'] {
		for size in [-1, 1, 2, 3, 5] {
			mut log := &SharedPrototypeLog{}
			vm.host_grow_shared_array_buffer = fn [mut log, mode] (mut buffer ArrayBuffer, new_size uint) !HandledByHost {
				log.events << 'host ${new_size}'
				if mode == 'throw' { return throw_completion(Value.from_i32(42)) }
				return if mode == 'handled' {
					HandledByHost.handled
				} else {
					HandledByHost.unhandled
				}
			}
			buffer := allocate_shared_array_buffer(mut vm,
				realm.shared_array_buffer_constructor_record(), 2, uint(4))!
			if _ := shared_buffer_method(mut vm, buffer, 'grow', [
				Value.from_i32(size),
			])
			{
				assert size >= 0 && (mode == 'handled' || (mode == 'unhandled' && size in [2, 3]))
			} else {
				if mode == 'throw' && size >= 0 {
					assert thrown_value(err).number == 42
				} else {
					assert thrown_value(err).as_object().error_kind()? == .range_error
				}
			}
			assert log.events == if size < 0 {
				[]string{}
			} else {
				['host ${size}']
			}
			assert buffer.byte_length() == if mode == 'unhandled' && size == 3 {
				uint(3)
			} else {
				uint(2)
			}
			assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
		}
	}
}

fn test_shared_array_buffer_growth_checks_slots_before_coercion_and_uses_length_after_reentrant_growth() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	mut log := &SharedPrototypeLog{}
	vm.host_grow_shared_array_buffer = fn [mut log] (mut buffer ArrayBuffer, size uint) !HandledByHost {
		log.events << 'host ${size}'
		return .unhandled
	}
	mut buffer := allocate_shared_array_buffer(mut vm,
		realm.shared_array_buffer_constructor_record(), 2, uint(10))!
	mut argument := Object.create(realm, none)
	convert := NativeFunction.create(mut vm, realm, realm.function_prototype, fn [mut log, buffer] (mut vm VM) !Value {
		log.events << 'coerce'
		shared_buffer_method(mut vm, buffer, 'grow', [Value.from_i32(8)])!
		return Value.from_i32(4)
	}, 1, PropertyName.from_str('convert'), none)
	argument.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(convert.object), 7)
	fixed := allocate_shared_array_buffer(mut vm, realm.shared_array_buffer_constructor_record(),
		2, none)!
	ordinary :=
		allocate_array_buffer(mut vm, realm.array_buffer_constructor_record(), 2, uint(10))!
	for receiver in [fixed, ordinary] {
		if _ := shared_buffer_method(mut vm, receiver, 'grow', [
			Value.from_object(argument),
		])
		{
			assert false
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
		}
	}
	assert log.events.len == 0
	if _ := shared_buffer_method(mut vm, buffer, 'grow', [Value.from_object(argument)]) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == 'SharedArrayBuffer byte length of 4 is less than the previous byte length of 8'
	}
	assert buffer.byte_length() == 8 && log.events == ['coerce', 'host 8', 'host 4']
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_shared_array_buffer_slice_uses_relative_indices_and_independent_fixed_shared_storage() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	mut source := allocate_shared_array_buffer(mut vm,
		realm.shared_array_buffer_constructor_record(), 5, uint(10))!
	source.overwrite(0, [u8(1), 2, 3, 4, 5])
	starts := [math.inf(-1), -3.0, 2.9, math.nan(), math.inf(1)]
	expected := [[u8(1), 2, 3, 4, 5], [u8(3), 4, 5], [u8(3), 4, 5],
		[u8(1), 2, 3, 4, 5], []u8{}]
	for index, start in starts {
		mut target := shared_buffer_method(mut vm, source, 'slice', [
			Value.from_f64(start),
		])!.as_object().array_buffer?
		assert target.is_shared_array_buffer() && target.is_fixed_length()
		assert !target.shares_storage_with(source)
			&& target.read_bytes(0, target.byte_length()) == expected[index]
		assert voidptr(target.object.internal_get_prototype_of()?) == voidptr(realm.shared_array_buffer_prototype_record())
		if target.byte_length() > 0 { target.overwrite(0, [u8(99)]) }
		assert source.read_bytes(0, 5) == [u8(1), 2, 3, 4, 5]
	}
	for end in [math.inf(-1), -1.0, 3.9, math.inf(1)] {
		target := shared_buffer_method(mut vm, source, 'slice', [
			Value.from_i32(1),
			Value.from_f64(end),
		])!.as_object().array_buffer?
		assert target.byte_length() == if math.is_inf(end, -1) {
			uint(0)
		} else if end == -1 {
			uint(3)
		} else if math.is_inf(end, 1) {
			uint(4)
		} else {
			uint(2)
		}
	}
}

fn test_shared_array_buffer_slice_species_validation_coercion_order_and_source_growth_use_snapshot_length() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	for mode in ['normal', 'grow source', 'wrong type', 'unshared', 'same source', 'short', 'throw'] {
		mut log := &SharedPrototypeLog{}
		mut source := allocate_shared_array_buffer(mut vm,
			realm.shared_array_buffer_constructor_record(), 5, uint(10))!
		source.overwrite(0, [u8(1), 2, 3, 4, 5])
		target := allocate_shared_array_buffer(mut vm,
			realm.shared_array_buffer_constructor_record(), if mode == 'short' {
			uint(1)
		} else {
			uint(4)
		}, none)!
		result := if mode == 'wrong type' {
			Object.create(realm, none)
		} else if mode == 'unshared' {
			allocate_array_buffer(mut vm, realm.array_buffer_constructor_record(), 4, none)!.object
		} else if mode == 'same source' {
			source.object
		} else {
			target.object
		}
		constructor := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype,
			shared_array_buffer_constructor_call, fn [mut log, source, result, mode] (mut vm VM, new_target &Object) !&Object {
			log.events << 'construct'
			assert vm.argument(0).number == 4
			if mode == 'grow source' { shared_buffer_method(mut vm, source, 'grow', [
					Value.from_i32(8),
				])! }
			if mode == 'throw' { return throw_completion(Value.from_i32(42)) }
			return result
		}, 1, PropertyName.from_str('Species'))
		mut holder := Object.create(realm, none)
		holder.define_native_accessor(mut vm, realm,
			PropertyName.from_symbol(vm.well_known_symbol_species()), fn [mut log, constructor] (mut vm VM) !Value {
			log.events << 'species'
			return Value.from_object(constructor.object)
		}, unsafe { nil }, 0, realm.function_prototype)
		mut object := source.object
		object.define_native_accessor(mut vm, realm, PropertyName.from_str('constructor'), fn [mut log, holder] (mut vm VM) !Value {
			log.events << 'constructor'
			return Value.from_object(holder)
		}, unsafe { nil }, 0, realm.function_prototype)
		mut start := Object.create(realm, none)
		convert := NativeFunction.create(mut vm, realm, realm.function_prototype, fn [mut log] (mut vm VM) !Value {
			log.events << 'start'
			return Value.from_i32(-4)
		}, 1, PropertyName.from_str('convert'), none)
		start.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
			Value.from_object(convert.object), 7)
		if value := shared_buffer_method(mut vm, source, 'slice', [
			Value.from_object(start),
			js_undefined(),
		])
		{
			assert mode in ['normal', 'grow source']
			assert voidptr(value.as_object()) == voidptr(target.object)
			assert target.read_bytes(0, 4) == [u8(2), 3, 4, 5]
		} else {
			if mode == 'throw' {
				assert thrown_value(err).number == 42
			} else {
				assert thrown_value(err).as_object().error_message()?.str() == match mode {
					'wrong type' { 'Species constructor did not create an ArrayBuffer' }
					'unshared' { 'The array buffer object must be a SharedArrayBuffer' }
					'same source' { 'Species constructor returned same ArrayBuffer instance' }
					else { 'Species constructor returned an ArrayBuffer smaller than requested' }
				}
			}
		}
		assert log.events == ['start', 'constructor', 'species', 'construct']
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}

fn test_shared_array_buffer_slice_saves_length_before_start_end_and_species_coercions() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	mut log := &SharedPrototypeLog{}
	mut source := allocate_shared_array_buffer(mut vm,
		realm.shared_array_buffer_constructor_record(), 5, uint(10))!
	source.overwrite(0, [u8(1), 2, 3, 4, 5])
	mut arguments := []Value{}
	for name in ['start', 'end'] {
		mut argument := Object.create(realm, none)
		convert := NativeFunction.create(mut vm, realm, realm.function_prototype, fn [mut log, source, name] (mut vm VM) !Value {
			log.events << name
			if name == 'start' {
				shared_buffer_method(mut vm, source, 'grow', [
					Value.from_i32(8)])!
				return Value.from_i32(1)
			}
			return Value.from_f64(math.inf(1))
		}, 1, PropertyName.from_str('convert'), none)
		argument.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
			Value.from_object(convert.object), 7)
		arguments << Value.from_object(argument)
	}
	mut holder := Object.create(realm, none)
	holder.define_native_accessor(mut vm, realm,
		PropertyName.from_symbol(vm.well_known_symbol_species()), fn [mut log] (mut vm VM) !Value {
		log.events << 'species'
		return Value.from_object(vm.realm().shared_array_buffer_constructor_record())
	}, unsafe { nil }, 0, realm.function_prototype)
	mut object := source.object
	object.define_native_accessor(mut vm, realm, PropertyName.from_str('constructor'), fn [mut log, holder] (mut vm VM) !Value {
		log.events << 'constructor'
		return Value.from_object(holder)
	}, unsafe { nil }, 0, realm.function_prototype)
	target := shared_buffer_method(mut vm, source, 'slice', arguments)!.as_object().array_buffer?
	assert log.events == ['start', 'end', 'constructor', 'species']
	assert source.byte_length() == 8 && target.byte_length() == 4
	assert target.read_bytes(0, 4) == [u8(2), 3, 4, 5]
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_shared_array_buffer_slice_preserves_upstream_object_identity_check_for_aliasing_host_buffers() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	storage := &ByteBufferStorage{
		bytes: [u8(42)]
	}
	mut source := ArrayBufferObject.create_from_host_buffer(realm, storage, true,
		realm.shared_array_buffer_prototype_record())
	alias := ArrayBufferObject.create_from_host_buffer(realm, storage, true,
		realm.shared_array_buffer_prototype_record())
	assert source.shares_storage_with(alias)
	constructor := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype,
		shared_array_buffer_constructor_call, fn [alias] (mut vm VM, new_target &Object) !&Object {
		return alias.object
	}, 1, PropertyName.from_str('Species'))
	mut holder := Object.create(realm, none)
	holder.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_species()),
		Value.from_object(constructor.object), 7)
	mut object := source.object
	object.define_direct_property(PropertyName.from_str('constructor'), Value.from_object(holder),
		7)
	result := shared_buffer_method(mut vm, source, 'slice', [
		Value.from_i32(0), Value.from_i32(0)])!
	assert voidptr(result.as_object()) == voidptr(alias.object)
}
