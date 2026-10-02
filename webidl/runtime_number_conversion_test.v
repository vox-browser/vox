module webidl

fn test_runtime_to_number_uses_actual_hook_without_promoting_the_value_brand() {
	value := runtime_value(RuntimeValue{
		number_conversion: fn () !f64 { return 4294967297.75 }
		string_conversion: fn () !string { panic('ToNumber must not substitute string conversion') }
	})
	assert value.number_primitive() == none
	assert value_to_number(value)! == 4294967297.75
	assert convert_to_int(value, 32, true, .no, .no)! == 1
	reason := dom_exception_value_for_record(DOMException.create_record('OperationError', 'actual numeric conversion failure'))
	throwing := runtime_value(RuntimeValue{
		number_conversion: fn [reason] () !f64 { return throw_value(reason) }
		string_conversion: fn () !string { panic('numeric failure must not stringify') }
	})
	if _ := value_to_number(throwing) {
		assert false
	} else {
		assert err is ValueException
		if err is ValueException {
			assert err.value.opaque_id == reason.opaque_id
		}
	}
}
