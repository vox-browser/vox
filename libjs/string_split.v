module libjs

// Runtime/StringPrototype.cpp::split. The current realm's Array prototype is
// supplied explicitly until Array intrinsics exist. RegExp's builtin shortcut
// is pending; @@split uses the complete ordinary GetMethod/Call path.
pub fn string_prototype_split(mut vm VM, array_prototype &Object) !Value {
	realm := vm.realm()
	separator_argument := vm.argument(0)
	limit_argument := vm.argument(1)
	this_value := vm.this_value()
	require_object_coercible(mut vm, this_value)!
	if separator_argument.is_object() {
		splitter := separator_argument.as_object().get_method(mut vm,
			PropertyName.from_symbol(vm.well_known_symbol_split()))!
		if !splitter.is_undefined() {
			return call(mut vm, splitter, separator_argument, [this_value, limit_argument])
		}
	}
	text := this_value.to_primitive_string(mut vm)!
	array := ArrayObject.create(mut vm, realm, 0, array_prototype)!
	mut object := array.object
	mut array_length := u32(0)
	limit := if limit_argument.is_undefined() {
		u32(0xffffffff)
	} else {
		limit_argument.to_u32(mut vm)!
	}
	separator := separator_argument.to_primitive_string(mut vm)!.utf16
	if limit == 0 { return Value.from_object(object) }
	string_length := text.utf16.len()
	if separator_argument.is_undefined() {
		defined := object.create_data_property_or_throw(mut vm, PropertyName.from_number(0),
			Value.from_string(text))!
		assert defined
		return Value.from_object(object)
	}
	separator_length := separator.len()
	if separator_length == 0 {
		out_length := if limit < u32(string_length) { int(limit) } else { string_length }
		for index in 0 .. out_length {
			unit := vm.create_string(Utf16String.from_slice(text.utf16.data[index..index + 1]))
			defined := object.create_data_property_or_throw(mut vm,
				PropertyName.from_number(u32(index)), Value.from_string(unit))!
			assert defined
		}
		return Value.from_object(object)
	}
	if string_length == 0 {
		defined := object.create_data_property_or_throw(mut vm, PropertyName.from_number(0),
			Value.from_string(text))!
		assert defined
		return Value.from_object(object)
	}
	mut search_start := 0
	mut match_index := string_index_of(text.utf16, separator, uint(search_start))
	for {
		index := match_index or { break }
		substring :=
			vm.create_string(Utf16String.from_slice(text.utf16.data[search_start..int(index)]))
		defined := object.create_data_property_or_throw(mut vm, PropertyName.from_number(array_length),
			Value.from_string(substring))!
		assert defined
		array_length++
		if array_length == limit { return Value.from_object(object) }
		search_start = int(index) + separator_length
		match_index = string_index_of(text.utf16, separator, uint(search_start))
	}
	substring := vm.create_string(Utf16String.from_slice(text.utf16.data[search_start..]))
	defined := object.create_data_property_or_throw(mut vm, PropertyName.from_number(array_length),
		Value.from_string(substring))!
	assert defined
	return Value.from_object(object)
}
