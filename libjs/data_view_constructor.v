module libjs

// Runtime/DataViewConstructor.{h,cpp}, including both bounds checks around
// NewTarget.prototype lookup and the pinned ByteLength u32 narrowing.
@[heap]
pub struct DataViewConstructor {
pub:
	object &Object
}

pub fn DataViewConstructor.create(mut vm VM, realm &Realm) &DataViewConstructor {
	function := NativeFunction.create_constructor_record(mut vm, realm, realm.function_prototype,
		data_view_constructor_call, data_view_constructor_construct,
		PropertyName.from_str('DataView'))
	mut object := function.object
	object.define_direct_property(PropertyName.from_str('prototype'),
		Value.from_object(realm.data_view_prototype_record()), 0)
	object.set_function_length(1)
	object.set_function_name(mut vm, PropertyName.from_str('DataView'), none)
	return &DataViewConstructor{
		object: object
	}
}

fn data_view_constructor_call(mut vm VM) !Value {
	return vm.throw_error_type(.type_error, .constructor_without_new, 'DataView')
}

fn data_view_constructor_construct(mut vm VM, new_target &Object) !&Object {
	argument := vm.argument(0)
	// Value::as_if returns a GC::Ptr. AK formats a failed pointer as a
	// zero-padded hexadecimal address, rather than the original argument.
	invalid_buffer := '0x' + '0'.repeat(int(2 * sizeof(voidptr)))
	buffer := if argument.is_object() {
		argument.as_object().array_buffer or {
			return vm.throw_error_type(.type_error, .is_not_an, invalid_buffer, 'ArrayBuffer')
		}
	} else {
		return vm.throw_error_type(.type_error, .is_not_an, invalid_buffer, 'ArrayBuffer')
	}
	offset := uint(vm.argument(1).to_index(mut vm)!)
	if buffer.is_detached() { return vm.throw_error_type(.type_error, .detached_array_buffer) }
	initial_size := array_buffer_byte_length(buffer, .seq_cst)
	if offset > initial_size {
		return vm.throw_error_type(.range_error, .data_view_out_of_range_byte_offset, offset.str(),
			initial_size.str())
	}
	requested_length := vm.argument(2)
	length := if requested_length.is_undefined() {
		if buffer.is_fixed_length() {
			ByteLength.from_u32(u32(initial_size - offset))
		} else {
			ByteLength.auto_length()
		}
	} else {
		ByteLength.from_u32(u32(requested_length.to_index(mut vm)!))
	}
	if !requested_length.is_undefined() && uint(length.length()) > initial_size - offset {
		return vm.throw_error_type(.range_error, .invalid_length, 'DataView')
	}
	prototype := get_prototype_from_constructor(mut vm, new_target, fn (realm &Realm) &Object {
		return realm.data_view_prototype_record()
	})!
	view := DataView.create(vm.realm(), buffer, length, offset, prototype)
	if buffer.is_detached() { return vm.throw_error_type(.type_error, .detached_array_buffer) }
	current_size := array_buffer_byte_length(buffer, .seq_cst)
	if offset > current_size {
		return vm.throw_error_type(.range_error, .data_view_out_of_range_byte_offset, offset.str(),
			current_size.str())
	}
	if !requested_length.is_undefined() && uint(length.length()) > current_size - offset {
		return vm.throw_error_type(.range_error, .invalid_length, 'DataView')
	}
	return view.object
}
