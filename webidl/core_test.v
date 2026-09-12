module webidl

fn test_dom_exception_legacy_codes_and_serialization() {
	for name, code in {
		'IndexSizeError':  u16(1)
		'SecurityError':   u16(18)
		'AbortError':      u16(20)
		'DataCloneError':  u16(25)
		'EncodingError':   u16(0)
		'ValidationError': u16(0)
	} {
		exception := DOMException.create(name, 'message')
		assert exception.code() == code
		assert DOMException.deserialize(exception.serialize())! == exception
	}
	constructed := DOMException.construct('first', 'Second')
	assert constructed.name() == 'Second'
	assert constructed.message() == 'first'
	constructed_for_bindings := DOMException.create_for_constructor('binding message', 'AbortError')
	assert constructed_for_bindings.name() == 'AbortError'
	assert constructed_for_bindings.message() == 'binding message'
	details := dom_exception_report_details(dom_exception_value(constructed_for_bindings)) or {
		assert false
		return
	}
	assert details.name == 'AbortError'
	assert details.message == 'binding message'
	assert dom_exception_from_object(object_value(map[string]Value{})) == none
}

fn test_quota_exceeded_error_validation_and_round_trip() {
	error_ := QuotaExceededError.construct('full', QuotaExceededErrorOptions{
		quota:     10
		requested: 12
	})!
	assert error_.base.code() == 22
	assert error_.quota()? == 10
	assert QuotaExceededError.deserialize(error_.serialize()) == error_
	for options in [
		QuotaExceededErrorOptions{
			quota: -1
		},
		QuotaExceededErrorOptions{
			requested: -1
		},
		QuotaExceededErrorOptions{
			quota:     10
			requested: 9
		},
	] {
		if _ := QuotaExceededError.construct('', options) {
			assert false, 'invalid quota options must fail'
		} else {
			assert err.msg().starts_with('RangeError:')
		}
	}
}

fn test_string_conversions_and_trace_formatting() {
	assert to_byte_string(string_value('Aÿ'))! == 'Aÿ'
	if _ := to_byte_string(string_value('A€')) {
		assert false
	} else {
		assert err.msg().starts_with('TypeError:')
	}
	assert to_string(undefined_value())! == 'undefined'
	assert to_string(number_value(12))! == '12'
	mut trace := TraceState{}
	trace.log_trace('hidden', [string_value('x')])
	assert trace.lines.len == 0
	trace.set_enable_idl_tracing(true)
	trace.log_trace('call', [string_value('x\n'), boolean_value(true)])
	assert trace.lines == ['call("x\\u000a", true)']
}

fn test_abstract_integer_utf16_and_list_operations() {
	assert to_utf16_string(string_value('A😀'))! == [u16(0x41), 0xd83d, 0xde00]
	assert to_utf16_usv_string(string_value('A'))! == [u16(0x41)]
	assert integer_part(-3.9) == -3
	assert convert_to_int(number_value(257), 8, false, .no, .no)! == 1
	assert convert_to_int(number_value(255), 8, true, .no, .no)! == -1
	assert convert_to_int(number_value(2.5), 8, false, .no, .yes)! == 2
	assert convert_to_int(number_value(3.5), 8, false, .no, .yes)! == 4
	if _ := convert_to_int(number_value(256), 8, false, .yes, .no) {
		assert false
	} else {
		assert err.msg().starts_with('TypeError:')
	}
	assert lists_contain_same_elements([u64(1), 2], [u64(2), 1])
	assert !lists_contain_same_elements([u64(1)], [u64(1), 2])
}

fn test_exception_named_steps_and_completion_surface() {
	exception := DOMException.construct_impl('message', 'AbortError')
	assert exception.name() == 'AbortError'
	assert exception.message() == 'message'
	assert get_legacy_code_for_name(exception.name()) == 20
	mut restored := DOMException.create('', '')
	restored.deserialization_steps(exception.serialization_steps())!
	assert restored == exception
	if _ := throw_completion(exception) {
		assert false
	} else {
		assert err.msg().contains('AbortError')
	}
	mut quota := QuotaExceededError.construct_impl('full', QuotaExceededErrorOptions{
		quota: 4
		requested: 8
	})!
	assert quota.quota()? == 4
	assert quota.requested()? == 8
	serialized := quota.serialization_steps()
	mut restored_quota := QuotaExceededError.create('')
	restored_quota.deserialization_steps(serialized)
	assert restored_quota == quota
}
