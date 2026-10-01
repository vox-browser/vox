module libjs

import math

// Native bodies from TypedArrayPrototype.cpp. Boxing dependencies are explicit
// until the full TypedArray/primitive intrinsic graph can be installed.
pub fn typed_array_prototype_at(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	index := vm.argument(0)
	array := typed_array_from_this(mut vm, prototypes)!
	record := validate_typed_array(mut vm, array.object, .seq_cst)!
	length := typed_array_length(record)
	relative := index.to_integer_or_infinity(mut vm)!
	if math.is_inf(relative, 0) { return js_undefined() }
	k := if relative >= 0 { relative } else { f64(length) + relative }
	if k < 0 || k >= f64(length) { return js_undefined() }
	return array.object.get(mut vm, PropertyName.from_number(u32(k)))
}

pub fn typed_array_prototype_buffer_getter(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	array := typed_array_from_this(mut vm, prototypes)!
	return Value.from_object(array.viewed_buffer.object)
}

pub fn typed_array_prototype_byte_length_getter(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	array := typed_array_from_this(mut vm, prototypes)!
	record := make_typed_array_with_buffer_witness_record(array, .seq_cst)
	return Value.from_f64(f64(typed_array_byte_length(record)))
}

pub fn typed_array_prototype_byte_offset_getter(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	array := typed_array_from_this(mut vm, prototypes)!
	record := make_typed_array_with_buffer_witness_record(array, .seq_cst)
	if is_typed_array_out_of_bounds(record) { return Value.from_i32(0) }
	return Value.from_f64(f64(array.byte_offset))
}

pub fn typed_array_prototype_length_getter(mut vm VM, prototypes PrimitiveObjectPrototypes) !Value {
	array := typed_array_from_this(mut vm, prototypes)!
	record := make_typed_array_with_buffer_witness_record(array, .seq_cst)
	if is_typed_array_out_of_bounds(record) { return Value.from_i32(0) }
	return Value.from_f64(f64(typed_array_length(record)))
}

pub fn typed_array_prototype_to_string_tag_getter(mut vm VM) !Value {
	receiver := vm.this_value()
	if !receiver.is_object() { return js_undefined() }
	array := receiver.as_object().typed_array or { return js_undefined() }
	return Value.from_string(vm.create_string_from_str(array.kind.typed_array_name()))
}
