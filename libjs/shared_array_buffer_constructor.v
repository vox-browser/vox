module libjs

// Runtime/SharedArrayBufferConstructor.{h,cpp}.
@[heap]
pub struct SharedArrayBufferConstructor {
pub:
	object &Object
}

pub fn SharedArrayBufferConstructor.create(mut vm VM, realm &Realm) &SharedArrayBufferConstructor {
	function := NativeFunction.create_constructor_record(mut vm, realm, realm.function_prototype,
		shared_array_buffer_constructor_call, shared_array_buffer_constructor_construct,
		PropertyName.from_str('SharedArrayBuffer'))
	mut object := function.object
	object.define_direct_property(PropertyName.from_str('prototype'),
		Value.from_object(realm.shared_array_buffer_prototype_record()), 0)
	object.define_native_accessor(mut vm, realm,
		PropertyName.from_symbol(vm.well_known_symbol_species()),
		shared_array_buffer_constructor_species, unsafe { nil }, attribute_configurable,
		realm.function_prototype)
	object.set_function_length(1)
	object.set_function_name(mut vm, PropertyName.from_str('SharedArrayBuffer'), none)
	return &SharedArrayBufferConstructor{
		object: object
	}
}

fn shared_array_buffer_constructor_call(mut vm VM) !Value {
	return vm.throw_error_type(.type_error, .constructor_without_new, 'SharedArrayBuffer')
}

fn shared_array_buffer_constructor_construct(mut vm VM, new_target &Object) !&Object {
	byte_length := vm.argument(0).to_index(mut vm) or {
		value := thrown_value(err)
		if value.is_object() {
			if kind := value.as_object().error_kind() {
				if kind == .range_error {
					return vm.throw_error_type(.range_error, .invalid_length, 'shared array buffer')
				}
			}
		}
		return err
	}
	maximum := get_array_buffer_max_byte_length_option(mut vm, vm.argument(1))!
	buffer := allocate_shared_array_buffer(mut vm, new_target, uint(byte_length), maximum.value)!
	return buffer.object
}

fn shared_array_buffer_constructor_species(mut vm VM) !Value {
	return vm.this_value()
}
