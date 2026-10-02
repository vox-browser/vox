module streams

import webidl

fn test_writable_constructor_rejects_reserved_any_type_without_coercion_or_start() {
	original := webidl.dom_exception_value_for_record(webidl.DOMException.create_record('OperationError', 'reserved any-valued sink type'))
	WritableStream.create_for_constructor(StreamRealm{}, UnderlyingSink{
		type_value: original
		start: fn () ! { panic('reserved type must be rejected before start') }
	}, QueuingStrategy{}) or {
		assert err.msg() == "RangeError: Invalid use of reserved key 'type'"
		return
	}
	assert false
}
