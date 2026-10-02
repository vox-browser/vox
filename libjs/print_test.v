module libjs

import math

fn printed(mut vm VM, value Value) string {
	return (inspect_value(mut vm, value, PrintOptions{ strip_ansi: true }) or { panic(err) }).str()
}

fn test_print_primitives_preserves_upstream_escaping_raw_strings_ansi_and_negative_zero() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert printed(mut vm, js_special_empty_value()) == '<empty>'
	assert printed(mut vm, js_undefined()) == 'undefined'
	assert printed(mut vm, js_null()) == 'null'
	assert printed(mut vm, Value.from_bool(true)) == 'true'
	assert printed(mut vm, Value.from_f64(-0.0)) == '-0'
	assert printed(mut vm, Value.from_f64(math.nan())) == 'NaN'
	assert printed(mut vm, Value.from_f64(math.inf(1))) == 'Infinity'
	units := Utf16String.from_slice([u16(`\r`), u16(`\v`), u16(`\f`), u16(`\b`), u16(`\n`), u16(`\\`),
		u16(`\t`), u16(`"`), u16(0xd800)])
	value := Value.from_string(vm.create_string(units))
	escaped := inspect_value(mut vm, value, PrintOptions{ strip_ansi: true })!
	mut expected := utf16_string('"\\r\\v\\f\\b\\n\\\\\t"').data.clone()
	expected << u16(0xd800)
	expected << u16(`"`)
	assert escaped.data == expected
	assert inspect_value(mut vm, value, PrintOptions{ strip_ansi: true, raw_strings: true })! == units
	assert inspect_value(mut vm, Value.from_i32(42), PrintOptions{})!.str() == '\x1b[35;1m42\x1b[0m'
	assert value.to_utf16_string_without_side_effects() == units
}

fn test_print_objects_includes_inherited_enumerables_shadowing_and_numeric_order_without_symbols_or_private_fields() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut prototype := Object.create(vm.realm(), none)
	prototype.create_data_property(mut vm, PropertyName.from_str('inherited'), Value.from_i32(17))!
	prototype.create_data_property(mut vm, PropertyName.from_str('hidden'), Value.from_i32(18))!
	mut object := Object.create(vm.realm(), prototype)
	object.create_data_property(mut vm, PropertyName.from_str('own'), Value.from_bool(true))!
	object.create_data_property(mut vm, PropertyName.from_number(2), Value.from_i32(2))!
	object.create_data_property(mut vm, PropertyName.from_number(0), Value.from_i32(0))!
	object.define_direct_property(PropertyName.from_str('hidden'), Value.from_i32(99), 0)
	object.create_data_property(mut vm, PropertyName.from_symbol(Symbol.create(utf16_string('symbol'), .unique)), Value.from_i32(100))!
	object.private_field_add(mut vm, PrivateName{ unique_id: 1, description: utf16_string('#field') }, Value.from_i32(101))!
	assert printed(mut vm, Value.from_object(object)) == 'Object{ "0": 0, "2": 2, "own": true, "inherited": 17 }'
	assert printed(mut vm, Value.from_object(Object.create(vm.realm(), none))) == 'Object{}'
}

fn test_print_repeated_identity_and_cycles_are_marked_without_reprinting() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut object := Object.create(vm.realm(), none)
	object.create_data_property(mut vm, PropertyName.from_str('self'), Value.from_object(object))!
	assert printed(mut vm, Value.from_object(object)) == 'Object{ "self": <already printed Object ${voidptr(object)}> }'
	mut other := Object.create(vm.realm(), none)
	other.create_data_property(mut vm, PropertyName.from_str('a'), Value.from_object(object))!
	other.create_data_property(mut vm, PropertyName.from_str('b'), Value.from_object(object))!
	assert printed(mut vm, Value.from_object(other)) == 'Object{ "a": Object{ "self": <already printed Object ${voidptr(object)}> }, "b": <already printed Object ${voidptr(object)}> }'
}

fn test_print_arrays_skip_holes_use_observable_getters_and_limit_to_101_entries() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut prototype := Object.create(vm.realm(), none)
	prototype.create_data_property(mut vm, PropertyName.from_number(0), Value.from_i32(99))!
	array := ArrayObject.create(mut vm, vm.realm(), 4, prototype)!
	mut object := array.object
	object.create_data_property(mut vm, PropertyName.from_number(2), Value.from_i32(42))!
	getter := NativeFunction.create(mut vm, vm.realm(), none, fn (mut vm VM) !Value {
		assert vm.this_value().is_object()
		return Value.from_i32(17)
	}, 0, PropertyName.from_number(3), 'get')
	object.define_direct_accessor(PropertyName.from_number(3), getter.object, none, 0)
	assert printed(mut vm, Value.from_object(object)) == '[ 42, 17 ]'
	assert printed(mut vm, Value.from_object(ArrayObject.create(mut vm, vm.realm(), 3, prototype)!.object)) == '[]'
	mut elements := []Value{}
	for index in 0 .. 102 { elements << Value.from_i32(index) }
	long_array := ArrayObject.create_from(mut vm, vm.realm(), elements, prototype)!
	long_output := printed(mut vm, Value.from_object(long_array.object))
	assert long_output.ends_with('99, 100, ... ]')
	assert !long_output.contains('101')
	// The upstream loop reads the live indexed-array-like size after each Get.
	// A getter that appends an element must make that element visible here.
	growing := ArrayObject.create(mut vm, vm.realm(), 1, prototype)!
	mut growing_object := growing.object
	grow := NativeFunction.create(mut vm, vm.realm(), none, fn [mut growing_object] (mut vm VM) !Value {
		growing_object.create_data_property(mut vm, PropertyName.from_number(1), Value.from_i32(18))!
		return Value.from_i32(17)
	}, 0, PropertyName.from_number(0), 'get')
	growing_object.define_direct_accessor(PropertyName.from_number(0), grow.object, none, 0)
	assert printed(mut vm, Value.from_object(growing_object)) == '[ 17, 18 ]'
}

fn test_print_getter_removals_and_throws_follow_upstream_partial_output() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut object := Object.create(vm.realm(), none)
	getter := NativeFunction.create(mut vm, vm.realm(), none, fn [mut object] (mut vm VM) !Value {
		assert object.internal_delete(PropertyName.from_str('removed'))
		return Value.from_i32(42)
	}, 0, PropertyName.from_str('first'), 'get')
	object.define_direct_accessor(PropertyName.from_str('first'), getter.object, none, attribute_enumerable)
	object.create_data_property(mut vm, PropertyName.from_str('removed'), Value.from_i32(99))!
	assert printed(mut vm, Value.from_object(object)) == 'Object{ "first": 42 }'
	abrupt := NativeFunction.create(mut vm, vm.realm(), none, fn (mut vm VM) !Value {
		return throw_completion(Value.from_i32(17))
	}, 0, PropertyName.from_str('abrupt'), 'get')
	mut throwing := Object.create(vm.realm(), none)
	throwing.define_direct_accessor(PropertyName.from_str('abrupt'), abrupt.object, none, attribute_enumerable)
	assert printed(mut vm, Value.from_object(throwing)) == 'Object{ "abrupt": '
	array := ArrayObject.create(mut vm, vm.realm(), 1, throwing)!
	mut array_object := array.object
	array_object.define_direct_accessor(PropertyName.from_number(0), abrupt.object, none, 0)
	assert printed(mut vm, Value.from_object(array_object)) == '[ '
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}

fn test_print_native_functions_wrappers_and_errors_does_not_use_coercion_hooks() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut prototype := Object.create(vm.realm(), none)
	function := NativeFunction.create(mut vm, vm.realm(), none, fn (mut vm VM) !Value {
		return js_undefined()
	}, 0, PropertyName.from_str('name'), none)
	assert printed(mut vm, Value.from_object(function.object)) == '[Function] name'
	assert printed(mut vm, Value.from_object(BooleanObject.create(vm.realm(), false).object)) == '[Boolean] false'
	assert printed(mut vm, Value.from_object(NumberObject.create(vm.realm(), -0.0, prototype).object)) == '[Number] -0'
	assert printed(mut vm, Value.from_object(StringObject.create(vm.realm(), vm.create_string(utf16_string('text')), prototype).object)) == '[String] "text"'
	mut error_object := create_error(mut vm, vm.realm(), .type_error, utf16_string('message'))
	error_object.create_data_property(mut vm, PropertyName.from_str('name'), Value.from_string(vm.create_string(utf16_string('TypeError'))))!
	assert printed(mut vm, Value.from_object(error_object)) == '[TypeError] message'
	error_object.define_direct_accessor(PropertyName.from_str('name'), function.object, none, 0)
	assert printed(mut vm, Value.from_object(error_object)) == '<already printed Object ${voidptr(error_object)}>'
	prototype.define_direct_property(PropertyName.from_str('toString'), Value.from_object(function.object), 0)
	assert Value.from_object(prototype).to_utf16_string_without_side_effects().str() == '[object Object]'
}

fn test_print_buffers_views_and_typed_arrays_keep_lengths_offsets_bytes_and_detachment() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	prototype := Object.create(vm.realm(), none)
	mut bytes := []u8{}
	for index in 0 .. 34 { bytes << u8(index) }
	mut buffer := ArrayBufferObject.create_from_bytes(vm.realm(), bytes, false, prototype)
	assert printed(mut vm, Value.from_object(buffer.object)) == '[ArrayBuffer]\n  byteLength: 34\n00 01 02 03 04 05 06 07 08 09 0a 0b 0c 0d 0e 0f  10 11 12 13 14 15 16 17 18 19 1a 1b 1c 1d 1e 1f\n20 21'
	view := DataView.create(vm.realm(), buffer, ByteLength.from_u32(2), 1, prototype)
	assert printed(mut vm, Value.from_object(view.object)) == '[DataView]\n  buffer: [ArrayBuffer] @ ${voidptr(buffer)}\n  byteLength: 2\n  byteOffset: 1'
	array := TypedArray.create(vm.realm(), .uint8, 34, buffer, prototype)
	output := printed(mut vm, Value.from_object(array.object))
	assert output.starts_with('[Uint8Array]\n  buffer: [ArrayBuffer] @ ${voidptr(buffer)}\n  length: 34\n  byteLength: 34\n[ 0, 1, 2')
	assert output.ends_with('32, 33 ]')
	buffer.detach_buffer()
	assert printed(mut vm, Value.from_object(buffer.object)) == '[ArrayBuffer]\n  byteLength: 0\n  Detached'
	assert printed(mut vm, Value.from_object(view.object)) == '[DataView]\n  buffer: [ArrayBuffer] @ ${voidptr(buffer)}\n  <out of bounds>'
	assert printed(mut vm, Value.from_object(array.object)) == '[Uint8Array]\n  buffer: [ArrayBuffer] @ ${voidptr(buffer)}\n  <out of bounds>'
}
