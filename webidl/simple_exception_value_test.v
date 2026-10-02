module webidl

fn test_simple_exception_completion_retains_typed_native_record_without_message_substitution() {
	native := &SimpleException{type_: .range_error, message: 'non-number size'}
	value := simple_exception_value_for_record(native)
	actual := exception_value(throw_value(value))
	assert actual.kind == .platform_object && actual.opaque_id == u64(voidptr(native))
	assert voidptr(actual.simple_exception_ or { panic('missing actual exception descriptor') }) == voidptr(native)
	assert native.name() == 'RangeError'
	author_string := string_value('RangeError: authored reason')
	assert exception_value(throw_value(author_string)).kind == .string_
	assert exception_value(throw_value(author_string)).simple_exception_ == none
}
