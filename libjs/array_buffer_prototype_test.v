module libjs

import math

@[heap]
struct BufferPrototypeLog {
mut:
	events []string
}

fn buffer_method(mut vm VM, buffer &ArrayBufferObject, name string, arguments []Value) !Value {
	method := vm.realm().array_buffer_prototype_record().get(mut vm, PropertyName.from_str(name))!
	return call(mut vm, method, Value.from_object(buffer.object), arguments)
}

fn test_array_buffer_prototype_metadata_getters_and_shared_brand_rejection() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	prototype := realm.array_buffer_prototype_record()
	assert prototype.own_property_keys().map(it.str()) == ['byteLength', 'detached', 'maxByteLength',
		'resizable', 'resize', 'slice', 'transfer', 'transferToFixedLength', 'constructor',
		'Symbol(Symbol.toStringTag)']
	mut buffer := allocate_array_buffer(mut vm, realm.array_buffer_constructor_record(), 2,
		uint(8))!
	assert buffer.object.get(mut vm, PropertyName.from_str('byteLength'))!.number == 2
	assert buffer.object.get(mut vm, PropertyName.from_str('maxByteLength'))!.number == 8
	assert buffer.object.get(mut vm, PropertyName.from_str('resizable'))!.as_bool()
	assert !buffer.object.get(mut vm, PropertyName.from_str('detached'))!.as_bool()
	shared_buffer := ArrayBufferObject.create_from_bytes(realm, [u8(1), 2], true, prototype)
	for name in ['byteLength', 'detached', 'maxByteLength', 'resizable'] {
		descriptor := prototype.internal_get_own_property(PropertyName.from_str(name))?
		assert descriptor.configurable? && !descriptor.enumerable? && descriptor.setter?.is_undefined()
		getter := descriptor.getter?.as_object()
		assert getter.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == 'get ' + name
		assert getter.get(mut vm, PropertyName.from_str('length'))!.number == 0
		for receiver in [js_undefined(), Value.from_object(prototype),
			Value.from_object(shared_buffer.object)] {
			if _ := call(mut vm, Value.from_object(getter), receiver, []Value{}) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .type_error
			}
		}
	}
	for index, name in ['resize', 'slice', 'transfer', 'transferToFixedLength'] {
		descriptor := prototype.internal_get_own_property(PropertyName.from_str(name))?
		assert descriptor.writable? && descriptor.configurable? && !descriptor.enumerable?
		function := descriptor.value?.as_object()
		assert function.get(mut vm, PropertyName.from_str('length'))!.number == [1, 2, 0, 0][index]
		assert function.get(mut vm, PropertyName.from_str('name'))!.as_string().str() == name
		if _ := call(mut vm, Value.from_object(function), Value.from_i32(42), [
			Value.from_i32(-1),
		])
		{
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == 'Not an object of type ArrayBuffer'
		}
		if _ := buffer_method(mut vm, shared_buffer, name, [Value.from_i32(0)]) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == if name == 'resize' {
				'ArrayBuffer is not resizable'
			} else {
				'The array buffer object cannot be a SharedArrayBuffer'
			}
		}
	}
	tag :=
		prototype.internal_get_own_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()))?
	assert tag.value?.as_string().str() == 'ArrayBuffer'
	assert tag.configurable? && !tag.writable? && !tag.enumerable?
	buffer.detach_buffer()
	assert buffer.object.get(mut vm, PropertyName.from_str('byteLength'))!.number == 0
	assert buffer.object.get(mut vm, PropertyName.from_str('maxByteLength'))!.number == 0
	assert buffer.object.get(mut vm, PropertyName.from_str('resizable'))!.as_bool()
	assert buffer.object.get(mut vm, PropertyName.from_str('detached'))!.as_bool()
}

fn test_array_buffer_resize_uses_default_and_unhandled_host_paths_and_zeroes_regrowth() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	for unhandled in [false, true] {
		if unhandled {
			vm.host_resize_array_buffer = fn (mut buffer ArrayBuffer, new_length uint) !HandledByHost {
				return .unhandled
			}
		}
		mut buffer := allocate_array_buffer(mut vm, realm.array_buffer_constructor_record(), 4,
			uint(8))!
		buffer.overwrite(0, [u8(1), 2, 3, 4])
		assert buffer_method(mut vm, buffer, 'resize', [Value.from_i32(2)])!.is_undefined()
		assert buffer_method(mut vm, buffer, 'resize', [Value.from_i32(6)])!.is_undefined()
		assert buffer.read_bytes(0, 6) == [u8(1), 2, 0, 0, 0, 0]
		assert buffer.max_byte_length() == 8
		assert buffer_method(mut vm, buffer, 'resize', []Value{})!.is_undefined()
		assert !buffer.is_detached() && buffer.byte_length() == 0
	}
}

fn test_array_buffer_resize_checks_slots_coercion_detachment_and_maximum_before_host() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	mut log := &BufferPrototypeLog{}
	vm.host_resize_array_buffer = fn [mut log] (mut buffer ArrayBuffer, new_length uint) !HandledByHost {
		log.events << 'host'
		return throw_completion(Value.from_i32(17))
	}
	mut argument := Object.create(realm, none)
	convert := NativeFunction.create(mut vm, realm, realm.function_prototype, fn [mut log] (mut vm VM) !Value {
		log.events << 'coerce'
		return throw_completion(Value.from_i32(42))
	}, 1, PropertyName.from_str('convert'), none)
	argument.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(convert.object), 7)
	mut fixed := allocate_array_buffer(mut vm, realm.array_buffer_constructor_record(), 2, none)!
	if _ := buffer_method(mut vm, fixed, 'resize', [Value.from_object(argument)]) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == 'ArrayBuffer is not resizable'
	}
	assert log.events.len == 0
	mut buffer := allocate_array_buffer(mut vm, realm.array_buffer_constructor_record(), 2,
		uint(4))!
	buffer.detach_buffer()
	if _ := buffer_method(mut vm, buffer, 'resize', [Value.from_object(argument)]) {
		assert false
	} else {
		assert thrown_value(err).number == 42
	}
	assert log.events == ['coerce']
	log.events.clear()
	if _ := buffer_method(mut vm, buffer, 'resize', [Value.from_i32(1)]) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_message()?.str() == 'ArrayBuffer is detached'
	}
	mut attached := allocate_array_buffer(mut vm, realm.array_buffer_constructor_record(), 2,
		uint(4))!
	if _ := buffer_method(mut vm, attached, 'resize', [Value.from_i32(5)]) {
		assert false
	} else {
		assert thrown_value(err).as_object().error_kind()? == .range_error
	}
	assert log.events.len == 0
	if _ := buffer_method(mut vm, attached, 'resize', [Value.from_i32(3)]) {
		assert false
	} else {
		assert thrown_value(err).number == 17
	}
	assert log.events == ['host'] && attached.byte_length() == 2
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_array_buffer_slice_clamps_relative_indices_and_returns_independent_fixed_storage() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	mut source := allocate_array_buffer(mut vm, realm.array_buffer_constructor_record(), 5,
		uint(8))!
	source.overwrite(0, [u8(1), 2, 3, 4, 5])
	starts := [math.inf(-1), -3.0, 2.9, math.nan(), math.inf(1)]
	ends := [3.0, -1.0, 4.9, math.inf(1), 8.0]
	expected := [[u8(1), 2, 3], [u8(3), 4], [u8(3), 4], [u8(1), 2, 3, 4, 5],
		[]u8{}]
	for i, start in starts {
		result := buffer_method(mut vm, source, 'slice', [Value.from_f64(start),
			Value.from_f64(ends[i])])!.as_object().array_buffer?
		assert result.is_fixed_length() && !result.shares_storage_with(source)
		assert result.read_bytes(0, result.byte_length()) == expected[i]
	}
	whole := buffer_method(mut vm, source, 'slice', []Value{})!.as_object().array_buffer?
	assert whole.read_bytes(0, whole.byte_length()) == [u8(1), 2, 3, 4, 5]
	mut global := realm.global_object_record()
	global.define_direct_property(PropertyName.from_str('ArrayBuffer'), js_undefined(), 7)
	defaulted := buffer_method(mut vm, source, 'slice', [Value.from_i32(3)])!.as_object().array_buffer?
	assert defaulted.read_bytes(0, 2) == [u8(4), 5]
}

fn test_array_buffer_slice_species_validation_precedes_source_detachment_and_copies_current_length() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	for mode in ['normal', 'shrink', 'wrong type', 'shared', 'detached target', 'same source',
		'short', 'detach source', 'detach source wrong type'] {
		mut source := allocate_array_buffer(mut vm, realm.array_buffer_constructor_record(), 6,
			uint(8))!
		source.overwrite(0, [u8(1), 2, 3, 4, 5, 6])
		mut target := allocate_array_buffer(mut vm, realm.array_buffer_constructor_record(), if mode == 'short' {
			uint(2)
		} else {
			uint(3)
		}, none)!
		if mode == 'detached target' { target.detach_buffer() }
		result := if mode in ['wrong type', 'detach source wrong type'] {
			Object.create(realm, none)
		} else if mode == 'same source' {
			source.object
		} else if mode == 'shared' {
			ArrayBufferObject.create_from_bytes(realm, [u8(0), 0, 0], true,
				realm.array_buffer_prototype_record()).object
		} else {
			target.object
		}
		constructor := NativeFunction.create_constructor(mut vm, realm, realm.function_prototype, fn (mut vm VM) !Value {
			return js_undefined()
		}, fn [mut source, result, mode] (mut vm VM, new_target &Object) !&Object {
			assert vm.argument(0).number == 3
			if mode == 'shrink' { assert source.try_resize(3, true)
			 }
			if mode in ['detach source', 'detach source wrong type'] { source.detach_buffer() }
			return result
		}, 1, PropertyName.from_str('Species'))
		mut holder := Object.create(realm, none)
		holder.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_species()),
			Value.from_object(constructor.object), 7)
		mut object := source.object
		object.define_direct_property(PropertyName.from_str('constructor'),
			Value.from_object(holder), 7)
		if value := buffer_method(mut vm, source, 'slice', [Value.from_i32(-4),
			Value.from_i32(5)])
		{
			assert mode in ['normal', 'shrink']
			buffer := value.as_object().array_buffer?
			assert voidptr(buffer) == voidptr(target)
			assert buffer.read_bytes(0, 3) == if mode == 'normal' {
				[u8(3), 4, 5]
			} else {
				[u8(3), 0, 0]
			}
		} else {
			assert thrown_value(err).as_object().error_kind()? == .type_error
			message := thrown_value(err).as_object().error_message()?.str()
			assert message == match mode {
				'wrong type', 'detach source wrong type' { 'Species constructor did not create an ArrayBuffer' }
				'shared' { 'The array buffer object cannot be a SharedArrayBuffer' }
				'detached target' { 'Species constructor returned a detached ArrayBuffer' }
				'same source' { 'Species constructor returned same ArrayBuffer instance' }
				'short' { 'Species constructor returned an ArrayBuffer smaller than requested' }
				else { 'ArrayBuffer is detached' }
			}
		}
		assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
	}
}

fn test_array_buffer_slice_observes_start_end_constructor_and_species_in_order() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	realm := vm.realm()
	mut log := &BufferPrototypeLog{}
	mut source := allocate_array_buffer(mut vm, realm.array_buffer_constructor_record(), 4, none)!
	mut arguments := []Value{}
	for name in ['start', 'end'] {
		mut argument := Object.create(realm, none)
		convert := NativeFunction.create(mut vm, realm, realm.function_prototype, fn [mut log, name] (mut vm VM) !Value {
			log.events << name
			return Value.from_i32(if name == 'start' { 1 } else { 3 })
		}, 1, PropertyName.from_str('convert'), none)
		argument.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
			Value.from_object(convert.object), 7)
		arguments << Value.from_object(argument)
	}
	mut holder := Object.create(realm, none)
	holder.define_native_accessor(mut vm, realm,
		PropertyName.from_symbol(vm.well_known_symbol_species()), fn [mut log] (mut vm VM) !Value {
		log.events << 'species'
		return Value.from_object(vm.realm().array_buffer_constructor_record())
	}, unsafe { nil }, 0, realm.function_prototype)
	mut object := source.object
	object.define_native_accessor(mut vm, realm, PropertyName.from_str('constructor'), fn [mut log, holder] (mut vm VM) !Value {
		log.events << 'constructor'
		return Value.from_object(holder)
	}, unsafe { nil }, 0, realm.function_prototype)
	assert buffer_method(mut vm, source, 'slice', arguments)!.as_object().array_buffer?.byte_length() == 2
	assert log.events == ['start', 'end', 'constructor', 'species']
}

fn test_array_buffer_transfer_methods_ignore_species_and_observe_coercion_before_detachment() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	realm := vm.realm()
	for name in ['transfer', 'transferToFixedLength'] {
		mut source := allocate_array_buffer(mut vm, realm.array_buffer_constructor_record(), 2,
			uint(4))!
		source.overwrite(0, [u8(1), 2])
		mut object := source.object
		object.define_native_accessor(mut vm, realm, PropertyName.from_str('constructor'), fn (mut vm VM) !Value {
			assert false, 'transfer must use the intrinsic constructor without species lookup'
			return js_undefined()
		}, unsafe { nil }, 0, realm.function_prototype)
		result := buffer_method(mut vm, source, name, []Value{})!.as_object().array_buffer?
		assert source.is_detached() && result.read_bytes(0, 2) == [u8(1), 2]
		assert result.is_fixed_length() == (name == 'transferToFixedLength')
		mut argument := Object.create(realm, none)
		convert := NativeFunction.create(mut vm, realm, realm.function_prototype, fn (mut vm VM) !Value {
			return throw_completion(Value.from_i32(42))
		}, 1, PropertyName.from_str('convert'), none)
		argument.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
			Value.from_object(convert.object), 7)
		if _ := buffer_method(mut vm, source, name, [Value.from_object(argument)]) {
			assert false
		} else {
			assert thrown_value(err).number == 42
		}
		mut live := allocate_array_buffer(mut vm, realm.array_buffer_constructor_record(), 2, none)!
		detach := NativeFunction.create(mut vm, realm, realm.function_prototype, fn [mut live] (mut vm VM) !Value {
			live.detach_buffer()
			return Value.from_i32(1)
		}, 1, PropertyName.from_str('detach'), none)
		argument.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
			Value.from_object(detach.object), 7)
		if _ := buffer_method(mut vm, live, name, [Value.from_object(argument)]) {
			assert false
		} else {
			assert thrown_value(err).as_object().error_message()?.str() == 'ArrayBuffer is detached'
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
