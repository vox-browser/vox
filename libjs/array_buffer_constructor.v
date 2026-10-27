module libjs

// Runtime/ArrayBufferConstructor.{h,cpp}. The prototype record is created first
// by realm initialization, before the constructor and its back-reference.
@[heap]
pub struct ArrayBufferConstructor {
pub:
	object &Object
}

pub fn ArrayBufferConstructor.create(mut vm VM, realm &Realm) &ArrayBufferConstructor {
	function := NativeFunction.create_constructor_record(mut vm, realm, realm.function_prototype,
		array_buffer_constructor_call, array_buffer_constructor_construct,
		PropertyName.from_str('ArrayBuffer'))
	mut object := function.object
	object.define_direct_property(PropertyName.from_str('prototype'),
		Value.from_object(realm.array_buffer_prototype_record()), 0)
	is_view := NativeFunction.create_raw(mut vm, realm, realm.function_prototype,
		array_buffer_constructor_is_view, 1, PropertyName.from_str('isView'), none)
	object.define_direct_property(PropertyName.from_str('isView'),
		Value.from_object(is_view.object), attribute_writable | attribute_configurable)
	object.define_native_accessor(mut vm, realm,
		PropertyName.from_symbol(vm.well_known_symbol_species()), array_buffer_constructor_species,
		unsafe { nil }, attribute_configurable, realm.function_prototype)
	object.set_function_length(1)
	object.set_function_name(mut vm, PropertyName.from_str('ArrayBuffer'), none)
	return &ArrayBufferConstructor{
		object: object
	}
}

fn array_buffer_constructor_call(mut vm VM) !Value {
	return vm.throw_error_type(.type_error, .constructor_without_new, 'ArrayBuffer')
}

fn array_buffer_constructor_construct(mut vm VM, new_target &Object) !&Object {
	byte_length := vm.argument(0).to_index(mut vm) or {
		value := thrown_value(err)
		if value.is_object() {
			if kind := value.as_object().error_kind() {
				if kind == .range_error {
					return vm.throw_error_type(.range_error, .invalid_length, 'array buffer')
				}
			}
		}
		return err
	}
	maximum := get_array_buffer_max_byte_length_option(mut vm, vm.argument(1))!
	buffer := allocate_array_buffer(mut vm, new_target, uint(byte_length), maximum.value)!
	return buffer.object
}

fn array_buffer_constructor_is_view(mut vm VM) !Value {
	value := vm.argument(0)
	return Value.from_bool(value.is_object() && (value.as_object().data_view != none || value.as_object().typed_array != none))
}

fn array_buffer_constructor_species(mut vm VM) !Value {
	return vm.this_value()
}
