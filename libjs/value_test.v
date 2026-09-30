module libjs

import math

fn test_values_keep_upstream_tags_and_int32_folding() {
	assert js_undefined().is_undefined()
	assert js_null().is_null()
	assert js_null().is_nullish()
	assert js_special_empty_value().is_special_empty_value()
	assert Value{}.is_undefined()
	assert Value.from_bool(true).as_bool()
	assert !Value.from_bool(false).as_bool()
	assert Value.from_i32(-7).as_i32() == -7
	assert Value.from_f64(42.0).is_int32()
	assert Value.from_f64(42.5).is_double()
	assert Value.from_f64(-0.0).is_double()
	assert Value.from_f64(2147483648.0).is_double()
	assert Value.from_f64(3.0).is_number()
	assert Value.from_f64(3.0).as_double() == 3.0
	assert Value.from_f64(math.nan()).is_double()
	assert !js_undefined().is_cell()
}

fn test_values_wrap_cells_and_convert_to_boolean() {
	mut vm := VM.create()
	realm := Realm.create()
	text := vm.create_string(utf16_string('hello'))
	string_value := Value.from_string(text)
	assert string_value.is_string()
	assert string_value.is_cell()
	assert voidptr(string_value.as_string()) == voidptr(text)
	assert string_value.to_boolean()
	assert !Value.from_string(vm.empty_string()).to_boolean()
	symbol := Symbol.create(utf16_string('desc'), .unique)
	symbol_value := Value.from_symbol(symbol)
	assert symbol_value.is_symbol()
	assert symbol_value.as_symbol().descriptive_string().str() == 'Symbol(desc)'
	assert symbol_value.to_boolean()
	object := Object.create(realm, none)
	object_value := Value.from_object(object)
	assert object_value.is_object()
	assert voidptr(object_value.as_object()) == voidptr(object)
	assert object_value.to_boolean()
	assert !js_undefined().to_boolean()
	assert !js_null().to_boolean()
	assert !Value.from_i32(0).to_boolean()
	assert !Value.from_f64(math.nan()).to_boolean()
	assert Value.from_f64(0.5).to_boolean()
	assert Value.from_bool(true).to_boolean()
	assert object_value.str() == '[object Object]'
	assert string_value.str() == '"hello"'
	assert Value.from_f64(1.5).str() == '1.5'
	assert Value.from_i32(3).str() == '3'
}

fn test_same_value_distinguishes_zero_signs_and_equates_nan() {
	assert same_value(js_undefined(), js_undefined())
	assert !same_value(js_undefined(), js_null())
	assert same_value(Value.from_f64(math.nan()), Value.from_f64(math.nan()))
	assert !same_value(Value.from_f64(0.0), Value.from_f64(-0.0))
	assert same_value(Value.from_i32(5), Value.from_f64(5.0))
	mut vm := VM.create()
	first := vm.create_string(utf16_string('shared'))
	second := vm.create_string(utf16_string('shared'))
	assert same_value(Value.from_string(first), Value.from_string(second))
	distinct := &PrimitiveString{
		utf16: utf16_string('shared')
	}
	assert !same_value(Value.from_string(first), Value.from_string(distinct))
}

fn test_completions_travel_through_the_error_channel() {
	normal := normal_completion(Value.from_i32(1))
	assert !normal.is_abrupt()
	assert !normal.is_error()
	thrown := Completion{
		type_: .throw_
		value: Value.from_i32(9)
	}
	assert thrown.is_abrupt()
	assert thrown.is_error()
	err := thrown.release_error()
	assert is_throw_completion(err)
	assert thrown_value(err).as_i32() == 9
	assert completion_from_error(err).type_ == .throw_
	assert err.msg() == 'Uncaught exception: 9'
	assert !is_throw_completion(error('plain'))
}

fn test_error_type_table_matches_upstream_names_and_formatting() {
	assert ErrorType.call_stack_size_exceeded.message() == 'Call stack size limit exceeded'
	assert ErrorType.call_stack_size_exceeded.upstream_name() == 'CallStackSizeExceeded'
	assert ErrorType.module_not_found.formatted('./missing') == "Cannot find/open module: './missing'"
	assert ErrorType.not_enough_memory_to_allocate.formatted('16') == 'Not enough memory to allocate 16 bytes'
	assert ErrorType.uri_malformed.upstream_name() == 'URIMalformed'
	assert ErrorType.get_legacy_reg_exp_static_property_value_empty.upstream_name() == 'GetLegacyRegExpStaticPropertyValueEmpty'
	assert ErrorType.typed_array_out_of_range_byte_offset_or_length.formatted('1', '2', '3') == 'Typed array range 1:2 is out of range for buffer with length 3'
	// Missing arguments leave placeholders in place; surplus arguments are ignored.
	assert ErrorType.bad_arg_count_many.formatted('f') == 'f() needs {} arguments'
	assert ErrorType.out_of_memory.formatted('ignored') == 'Out of memory'
	assert format_error_message('{}{}', ['a', 'b']) == 'ab'
}
