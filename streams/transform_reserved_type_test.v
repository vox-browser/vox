module streams

import webidl

fn test_transform_reserved_any_values_throw_in_readable_then_writable_order_before_start() {
	original := webidl.dom_exception_value_for_record(webidl.DOMException.create_record('OperationError', 'reserved transformer any value'))
	realm := StreamRealm.create(56)
	TransformStream.create_for_constructor(realm, Transformer{
		readable_type_value: original
		writable_type_value: original
		start: fn () ! { panic('reserved any type must be rejected before start') }
	}, QueuingStrategy{}, QueuingStrategy{}) or {
		assert err.msg() == "RangeError: Invalid use of reserved key 'readableType'"
		TransformStream.create_for_constructor(realm, Transformer{writable_type_value: original, start: fn () ! { panic('reserved writable type must be rejected before start') }}, QueuingStrategy{}, QueuingStrategy{}) or {
			assert err.msg() == "RangeError: Invalid use of reserved key 'writableType'"
			return
		}
		assert false
		return
	}
	assert false
}
