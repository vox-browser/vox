module libjs

// Runtime/DataViewPrototype.{h,cpp}. Capturing native functions select the same
// concrete element types as the source's template wrappers, with their metadata
// and argument order retained. Every getter and setter body is installed here.
@[heap]
pub struct DataViewPrototype {
pub:
	object &Object
}

pub fn DataViewPrototype.create(mut vm VM, realm &Realm, object_prototype ?&Object) &DataViewPrototype {
	mut object := Object.create(realm, object_prototype)
	types := [BufferElementType.big_int64, .big_uint64, .float16, .float32, .float64, .int8, .int16,
		.int32, .uint8, .uint16, .uint32]
	names := ['BigInt64', 'BigUint64', 'Float16', 'Float32', 'Float64', 'Int8', 'Int16', 'Int32',
		'Uint8', 'Uint16', 'Uint32']
	for setting in [false, true] {
		for index, kind in types {
			name := (if setting { 'set' } else { 'get' }) + names[index]
			behaviour := if setting {
				NativeFunctionPointer(fn [kind] (mut vm VM) !Value {
					endian := if kind.size() == 1 { Value.from_bool(true) } else { vm.argument(2) }
					return set_view_value(mut vm, vm.argument(0), endian, kind, vm.argument(1))
				})
			} else {
				NativeFunctionPointer(fn [kind] (mut vm VM) !Value {
					endian := if kind.size() == 1 { Value.from_bool(true) } else { vm.argument(1) }
					return get_view_value(mut vm, vm.argument(0), endian, kind)
				})
			}
			function := NativeFunction.create(mut vm, realm, realm.function_prototype, behaviour, if setting {
				2
			} else {
				1
			}, PropertyName.from_str(name), none)
			object.define_direct_property(PropertyName.from_str(name),
				Value.from_object(function.object), attribute_writable | attribute_configurable)
		}
	}
	getters := [NativeFunctionPointer(data_view_buffer_getter), data_view_byte_length_getter,
		data_view_byte_offset_getter]
	for index, name in ['buffer', 'byteLength', 'byteOffset'] {
		object.define_native_accessor(mut vm, realm, PropertyName.from_str(name), getters[index],
			unsafe { nil }, attribute_configurable, realm.function_prototype)
	}
	object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()),
		Value.from_string(vm.create_string_from_str('DataView')), attribute_configurable)
	return &DataViewPrototype{
		object: object
	}
}

fn this_data_view(mut vm VM) !&DataView {
	value := vm.this_value()
	if value.is_object() {
		if view := value.as_object().data_view { return view }
	}
	return vm.throw_error_type(.type_error, .not_an_object_of_type, 'DataView')
}

fn view_buffer(view &DataView) &ArrayBufferObject {
	return view.viewed_buffer or { panic('DataView requires an installed buffer') }
}

fn checked_view_index(mut vm VM, view &DataView, index uint, kind BufferElementType) !uint {
	record := make_data_view_with_buffer_witness_record(view, .unordered)
	if is_view_out_of_bounds(record) {
		return vm.throw_error_type(.type_error, .buffer_out_of_bounds, 'DataView')
	}
	size := uint(get_view_byte_length(record))
	// Difference checks retain the source's checked-add overflow behavior before
	// constructing either the end index or the underlying buffer index.
	if index > size || kind.size() > size - index {
		return vm.throw_error_type(.range_error, .data_view_out_of_range_byte_offset, index.str(),
			size.str())
	}
	offset := uint(view.byte_offset())
	if index > ~uint(0) - offset {
		return vm.throw_error_type(.range_error, .data_view_out_of_range_byte_offset, index.str(),
			size.str())
	}
	return index + offset
}

fn get_view_value(mut vm VM, request_index Value, is_little_endian Value, kind BufferElementType) !Value {
	view := this_data_view(mut vm)!
	index := uint(request_index.to_index(mut vm)!)
	little_endian := is_little_endian.to_boolean()
	buffer_index := checked_view_index(mut vm, view, index, kind)!
	return view_buffer(view).get_value(mut vm, buffer_index, kind, false, .unordered, little_endian)
}

fn set_view_value(mut vm VM, request_index Value, is_little_endian Value, kind BufferElementType, value Value) !Value {
	view := this_data_view(mut vm)!
	index := uint(request_index.to_index(mut vm)!)
	number := if kind.is_bigint() {
		Value.from_bigint(value.to_bigint(mut vm)!)
	} else {
		value.to_number(mut vm)!
	}
	little_endian := is_little_endian.to_boolean()
	buffer_index := checked_view_index(mut vm, view, index, kind)!
	mut buffer := view_buffer(view)
	buffer.set_value(mut vm, buffer_index, kind, number, false, .unordered, little_endian)
	return js_undefined()
}

fn data_view_buffer_getter(mut vm VM) !Value {
	view := this_data_view(mut vm)!
	return Value.from_object(view_buffer(view).object)
}

fn data_view_byte_length_getter(mut vm VM) !Value {
	view := this_data_view(mut vm)!
	record := make_data_view_with_buffer_witness_record(view, .seq_cst)
	if is_view_out_of_bounds(record) {
		return vm.throw_error_type(.type_error, .buffer_out_of_bounds, 'DataView')
	}
	return Value.from_f64(f64(get_view_byte_length(record)))
}

fn data_view_byte_offset_getter(mut vm VM) !Value {
	view := this_data_view(mut vm)!
	record := make_data_view_with_buffer_witness_record(view, .seq_cst)
	if is_view_out_of_bounds(record) {
		return vm.throw_error_type(.type_error, .buffer_out_of_bounds, 'DataView')
	}
	return Value.from_f64(f64(view.byte_offset()))
}
