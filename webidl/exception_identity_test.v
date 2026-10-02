module webidl

fn test_dom_exception_value_keeps_one_actual_record_through_native_promise_rejection() {
	exception := DOMException.create_record('SyntaxError', 'Invalid font data')
	value := dom_exception_value_for_record(exception)
	assert value.dom_exception_? == exception
	assert value.opaque_id == u64(voidptr(exception))
	mut promise := create_promise()
	promise.reject(value)
	assert promise.result.dom_exception_? == exception
	assert promise.result.opaque_id == value.opaque_id
	decoded := dom_exception_from_object(promise.result) or { panic('missing native DOMException') }
	assert decoded.name() == exception.name()
	assert decoded.message() == exception.message()
}

fn test_fresh_dom_exception_values_have_distinct_native_identity() {
	first := dom_exception_value(DOMException.create('NetworkError', 'Unavailable'))
	second := dom_exception_value(DOMException.create('NetworkError', 'Unavailable'))
	assert first.opaque_id != 0
	assert first.opaque_id != second.opaque_id
	assert voidptr(first.dom_exception_?) != voidptr(second.dom_exception_?)
}
