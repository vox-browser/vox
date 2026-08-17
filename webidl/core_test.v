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
	assert constructed.name == 'Second'
	assert constructed.message == 'first'
}

fn test_quota_exceeded_error_validation_and_round_trip() {
	error_ := QuotaExceededError.construct('full', QuotaExceededErrorOptions{
		quota:     10
		requested: 12
	})!
	assert error_.base.code() == 22
	assert error_.quota? == 10
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
