module libjs

import math

// Runtime/ArrayBufferPrototype.{h,cpp}, including all accessors and methods.
@[heap]
pub struct ArrayBufferPrototype {
pub:
	object &Object
}

pub fn ArrayBufferPrototype.create(mut vm VM, realm &Realm, object_prototype ?&Object) &ArrayBufferPrototype {
	mut object := Object.create(realm, object_prototype)
	getters := [NativeFunctionPointer(array_buffer_byte_length_getter), array_buffer_detached_getter,
		array_buffer_max_byte_length_getter, array_buffer_resizable_getter]
	for index, name in ['byteLength', 'detached', 'maxByteLength', 'resizable'] {
		object.define_native_accessor(mut vm, realm, PropertyName.from_str(name), getters[index],
			unsafe { nil }, attribute_configurable, realm.function_prototype)
	}
	methods := [NativeFunctionPointer(array_buffer_resize), array_buffer_slice, array_buffer_transfer,
		array_buffer_transfer_to_fixed_length]
	for index, name in ['resize', 'slice', 'transfer', 'transferToFixedLength'] {
		function := NativeFunction.create_raw(mut vm, realm, realm.function_prototype,
			methods[index], [1, 2, 0, 0][index], PropertyName.from_str(name), none)
		object.define_direct_property(PropertyName.from_str(name),
			Value.from_object(function.object), attribute_writable | attribute_configurable)
	}
	object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()),
		Value.from_string(vm.create_string_from_str('ArrayBuffer')), attribute_configurable)
	return &ArrayBufferPrototype{
		object: object
	}
}

fn this_array_buffer(mut vm VM) !&ArrayBufferObject {
	value := vm.this_value()
	if value.is_object() {
		if buffer := value.as_object().array_buffer { return buffer }
	}
	return vm.throw_error_type(.type_error, .not_an_object_of_type, 'ArrayBuffer')
}

fn require_unshared_buffer(mut vm VM, buffer &ArrayBufferObject) ! {
	if buffer.is_shared_array_buffer() {
		return vm.throw_error_type(.type_error, .shared_array_buffer)
	}
}

fn array_buffer_byte_length_getter(mut vm VM) !Value {
	buffer := this_array_buffer(mut vm)!
	require_unshared_buffer(mut vm, buffer)!
	return Value.from_f64(f64(buffer.byte_length()))
}

fn array_buffer_detached_getter(mut vm VM) !Value {
	buffer := this_array_buffer(mut vm)!
	require_unshared_buffer(mut vm, buffer)!
	return Value.from_bool(buffer.is_detached())
}

fn array_buffer_max_byte_length_getter(mut vm VM) !Value {
	buffer := this_array_buffer(mut vm)!
	require_unshared_buffer(mut vm, buffer)!
	if buffer.is_detached() { return Value.from_i32(0) }
	return Value.from_f64(f64(if buffer.is_fixed_length() {
		buffer.byte_length()
	} else {
		buffer.max_byte_length()
	}))
}

fn array_buffer_resizable_getter(mut vm VM) !Value {
	buffer := this_array_buffer(mut vm)!
	require_unshared_buffer(mut vm, buffer)!
	return Value.from_bool(!buffer.is_fixed_length())
}

fn array_buffer_resize(mut vm VM) !Value {
	mut buffer := this_array_buffer(mut vm)!
	if buffer.is_fixed_length() { return vm.throw_error_type(.type_error, .fixed_array_buffer) }
	require_unshared_buffer(mut vm, buffer)!
	new_size := uint(vm.argument(0).to_index(mut vm)!)
	if buffer.is_detached() { return vm.throw_error_type(.type_error, .detached_array_buffer) }
	if new_size > buffer.max_byte_length() {
		return vm.throw_error_type(.range_error, .byte_length_exceeds_max_byte_length,
			new_size.str(), buffer.max_byte_length().str())
	}
	if vm.host_resize_array_buffer(mut buffer, new_size)! == .handled { return js_undefined() }
	mut block := create_byte_data_block(mut vm, new_size, none)!
	old_size := buffer.byte_length()
	buffer.data_block().copy_to(mut block, 0, 0, if new_size < old_size {
		new_size
	} else {
		old_size
	})
	buffer.set_data_block(block)
	return js_undefined()
}

fn buffer_slice_index(length uint, relative f64) uint {
	if math.is_inf(relative, -1) { return 0 }
	return uint(if relative < 0 {
		math.max(f64(length) + relative, 0)
	} else {
		math.min(relative, f64(length))
	})
}

fn array_buffer_slice(mut vm VM) !Value {
	buffer := this_array_buffer(mut vm)!
	require_unshared_buffer(mut vm, buffer)!
	if buffer.is_detached() { return vm.throw_error_type(.type_error, .detached_array_buffer) }
	length := buffer.byte_length()
	first := buffer_slice_index(length, vm.argument(0).to_integer_or_infinity(mut vm)!)
	end := vm.argument(1)
	final := buffer_slice_index(length, if end.is_undefined() {
		f64(length)
	} else {
		end.to_integer_or_infinity(mut vm)!
	})
	new_length := if final > first { final - first } else { uint(0) }
	constructor := species_constructor(mut vm, buffer.object,
		vm.realm().array_buffer_constructor_record())!
	object := construct(mut vm, Value.from_object(constructor), [
		Value.from_f64(f64(new_length)),
	], none)!
	mut target := object.array_buffer or {
		return vm.throw_error_type(.type_error, .species_constructor_did_not_create,
			'an ArrayBuffer')
	}

	require_unshared_buffer(mut vm, target)!
	if target.is_detached() {
		return vm.throw_error_type(.type_error, .species_constructor_returned,
			'a detached ArrayBuffer')
	}
	if voidptr(target) == voidptr(buffer) {
		return vm.throw_error_type(.type_error, .species_constructor_returned,
			'same ArrayBuffer instance')
	}
	if target.byte_length() < new_length {
		return vm.throw_error_type(.type_error, .species_constructor_returned,
			'an ArrayBuffer smaller than requested')
	}
	if buffer.is_detached() { return vm.throw_error_type(.type_error, .detached_array_buffer) }
	current_length := buffer.byte_length()
	if first < current_length {
		available := current_length - first
		buffer.copy_data_to(mut target, first, 0, if new_length < available {
			new_length
		} else {
			available
		})
	}
	return Value.from_object(target.object)
}

fn array_buffer_transfer(mut vm VM) !Value {
	mut buffer := this_array_buffer(mut vm)!
	result := array_buffer_copy_and_detach(mut vm, mut buffer, vm.argument(0),
		.preserve_resizability)!
	return Value.from_object(result.object)
}

fn array_buffer_transfer_to_fixed_length(mut vm VM) !Value {
	mut buffer := this_array_buffer(mut vm)!
	result := array_buffer_copy_and_detach(mut vm, mut buffer, vm.argument(0), .fixed_length)!
	return Value.from_object(result.object)
}
