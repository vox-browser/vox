module libjs

// Runtime/SharedArrayBufferPrototype.{h,cpp}. All active accessor and method
// bodies are translated; upstream's concurrent growth loop remains pending.
@[heap]
pub struct SharedArrayBufferPrototype {
pub:
	object &Object
}

pub fn SharedArrayBufferPrototype.create(mut vm VM, realm &Realm, object_prototype ?&Object) &SharedArrayBufferPrototype {
	mut object := Object.create(realm, object_prototype)
	object.define_native_accessor(mut vm, realm, PropertyName.from_str('byteLength'),
		shared_array_buffer_byte_length_getter, unsafe { nil }, attribute_configurable,
		realm.function_prototype)
	grow := NativeFunction.create_raw(mut vm, realm, realm.function_prototype,
		shared_array_buffer_grow, 1, PropertyName.from_str('grow'), none)
	object.define_direct_property(PropertyName.from_str('grow'), Value.from_object(grow.object),
		attribute_writable | attribute_configurable)
	for index, name in ['growable', 'maxByteLength'] {
		getters := [NativeFunctionPointer(shared_array_buffer_growable_getter),
			shared_array_buffer_max_byte_length_getter]
		object.define_native_accessor(mut vm, realm, PropertyName.from_str(name), getters[index],
			unsafe { nil }, attribute_configurable, realm.function_prototype)
	}
	slice := NativeFunction.create_raw(mut vm, realm, realm.function_prototype,
		shared_array_buffer_slice, 2, PropertyName.from_str('slice'), none)
	object.define_direct_property(PropertyName.from_str('slice'), Value.from_object(slice.object),
		attribute_writable | attribute_configurable)
	object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()),
		Value.from_string(vm.create_string_from_str('SharedArrayBuffer')), attribute_configurable)
	return &SharedArrayBufferPrototype{
		object: object
	}
}

fn this_shared_array_buffer(mut vm VM) !&ArrayBufferObject {
	value := vm.this_value()
	if value.is_object() {
		if buffer := value.as_object().array_buffer { return buffer }
	}
	return vm.throw_error_type(.type_error, .not_an_object_of_type, 'SharedArrayBuffer')
}

fn require_shared_buffer(mut vm VM, buffer &ArrayBufferObject) ! {
	if !buffer.is_shared_array_buffer() {
		return vm.throw_error_type(.type_error, .not_a_shared_array_buffer)
	}
}

fn shared_array_buffer_byte_length_getter(mut vm VM) !Value {
	buffer := this_shared_array_buffer(mut vm)!
	require_shared_buffer(mut vm, buffer)!
	return Value.from_f64(f64(buffer.byte_length()))
}

fn shared_array_buffer_growable_getter(mut vm VM) !Value {
	buffer := this_shared_array_buffer(mut vm)!
	require_shared_buffer(mut vm, buffer)!
	return Value.from_bool(!buffer.is_fixed_length())
}

fn shared_array_buffer_max_byte_length_getter(mut vm VM) !Value {
	buffer := this_shared_array_buffer(mut vm)!
	require_shared_buffer(mut vm, buffer)!
	return Value.from_f64(f64(if buffer.is_fixed_length() {
		buffer.byte_length()
	} else {
		buffer.max_byte_length()
	}))
}

fn shared_array_buffer_grow(mut vm VM) !Value {
	mut buffer := this_shared_array_buffer(mut vm)!
	if buffer.is_fixed_length() { return vm.throw_error_type(.type_error, .fixed_array_buffer) }
	require_shared_buffer(mut vm, buffer)!
	new_size := uint(vm.argument(0).to_index(mut vm)!)
	// Host growth precedes even equality and maximum checks in the source.
	if vm.host_grow_shared_array_buffer(mut buffer, new_size)! == .handled { return js_undefined() }
	current_size := buffer.byte_length()
	if new_size == current_size { return js_undefined() }
	if new_size < current_size {
		return vm.throw_error_type(.range_error, .byte_length_less_than_previous_byte_length,
			new_size.str(), current_size.str())
	}
	if new_size > buffer.max_byte_length() {
		return vm.throw_error_type(.range_error, .byte_length_exceeds_max_byte_length,
			new_size.str(), buffer.max_byte_length().str())
	}
	if !buffer.try_resize(new_size, true) {
		return vm.throw_error_type(.range_error, .not_enough_memory_to_allocate, new_size.str())
	}
	return js_undefined()
}

fn shared_array_buffer_slice(mut vm VM) !Value {
	buffer := this_shared_array_buffer(mut vm)!
	require_shared_buffer(mut vm, buffer)!
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
		vm.realm().shared_array_buffer_constructor_record())!
	object := construct(mut vm, Value.from_object(constructor), [
		Value.from_f64(f64(new_length)),
	], none)!
	mut target := object.array_buffer or {
		return vm.throw_error_type(.type_error, .species_constructor_did_not_create,
			'an ArrayBuffer')
	}

	require_shared_buffer(mut vm, target)!
	// Upstream compares object identity here, even though the spec comment
	// describes backing-store identity. Preserve that pinned check.
	if voidptr(target.object) == voidptr(buffer.object) {
		return vm.throw_error_type(.type_error, .species_constructor_returned,
			'same ArrayBuffer instance')
	}
	if target.byte_length() < new_length {
		return vm.throw_error_type(.type_error, .species_constructor_returned,
			'an ArrayBuffer smaller than requested')
	}
	buffer.copy_data_to(mut target, first, 0, new_length)
	return Value.from_object(target.object)
}
