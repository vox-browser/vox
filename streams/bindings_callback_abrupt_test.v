module streams

import webidl

fn test_bindings_pull_and_write_adapters_preserve_original_abrupt_completion_value() {
	realm := StreamRealm.create(985)
	original := webidl.dom_exception_value_for_record(webidl.DOMException.create_record('OperationError', 'binding callback completion'))
	mut readable := ReadableStream.create(realm, UnderlyingSource{}, QueuingStrategy{high_water_mark: 0})!
	mut bytes := ReadableStream.create(realm, UnderlyingSource{type_: .bytes}, QueuingStrategy{})!
	mut writable := WritableStream.create(realm, UnderlyingSink{}, QueuingStrategy{})!
	results := [
		invoke_readable_stream_pull_algorithm_callback(realm, fn [original] (_ Value, _ &ReadableStreamDefaultController) ! { return webidl.throw_value(original) }, undefined_value(), readable.default_controller()!),
		invoke_readable_byte_stream_pull_algorithm_callback(realm, fn [original] (_ Value, _ &ReadableByteStreamController) ! { return webidl.throw_value(original) }, undefined_value(), bytes.byte_controller()!),
		invoke_writable_stream_write_algorithm_callback(realm, fn [original] (_ Value, _ Value, _ &WritableStreamDefaultController) ! { return webidl.throw_value(original) }, undefined_value(), string_value('chunk'), writable.controller()),
	]
	for result in results {
		assert result.state() == .rejected
		actual := result.as_webidl_promise().result
		assert actual.opaque_id == original.opaque_id
		actual_record := actual.dom_exception_ or { panic('lost native thrown record') }
		original_record := original.dom_exception_ or { panic('missing native thrown record') }
		assert voidptr(actual_record) == voidptr(original_record)
	}
}
