module streams

fn uppercase_transform(value Value) ![]Value {
	if value.kind != .string_ {
		return error('expected string')
	}
	return [string_value(value.text.to_upper())]
}

fn flush_marker() ![]Value {
	return [string_value('FLUSH')]
}

fn failing_transform(_ Value) ![]Value {
	return error('transform failed')
}

fn failing_transform_start() ! {
	return error('transform start failed')
}

fn test_default_transform_is_identity() {
	mut transform := TransformStream.construct_impl(Transformer{}, QueuingStrategy{}, QueuingStrategy{
		high_water_mark: 2
	})!
	mut readable := transform.readable()
	mut reader := readable.get_default_reader()!
	mut writable := transform.writable()
	mut writer := writable.get_writer()!
	assert writer.write(number_value(9)).state() == .fulfilled
	assert reader.read().result().value.number == 9
	assert writer.close().state() == .fulfilled
	assert reader.read().result().done
}

fn test_default_readable_strategy_has_zero_high_water_mark() {
	transform := TransformStream.construct_impl(Transformer{}, QueuingStrategy{}, QueuingStrategy{})!
	assert transform.controller().desired_size()? == 0
	assert transform.backpressure()
}

fn test_default_backpressure_holds_write_until_readable_pull() {
	mut transform := TransformStream.construct_impl(Transformer{}, QueuingStrategy{}, QueuingStrategy{})!
	mut writable := transform.writable()
	mut writer := writable.get_writer()!
	write := writer.write(string_value('held'))
	assert write.state() == .pending
	assert writable.written_values().len == 0

	mut readable := transform.readable()
	mut reader := readable.get_default_reader()!
	read := reader.read()
	assert read.state() == .fulfilled
	assert read.result().value.text == 'held'
	assert write.state() == .fulfilled
	assert transform.backpressure()
}

fn test_custom_transform_and_flush_feed_readable_side() {
	mut transform := TransformStream.construct_impl(Transformer{
		transform: uppercase_transform
		flush: flush_marker
	}, QueuingStrategy{}, QueuingStrategy{
		high_water_mark: 4
	})!
	mut writable := transform.writable()
	mut writer := writable.get_writer()!
	assert writer.write(string_value('hello')).state() == .fulfilled
	assert writer.close().state() == .fulfilled
	mut readable := transform.readable()
	mut reader := readable.get_default_reader()!
	assert reader.read().result().value.text == 'HELLO'
	assert reader.read().result().value.text == 'FLUSH'
	assert reader.read().result().done
}

fn test_transform_failure_errors_both_sides() {
	mut transform := TransformStream.construct_impl(Transformer{
		transform: failing_transform
	}, QueuingStrategy{}, QueuingStrategy{
		high_water_mark: 1
	})!
	mut writable := transform.writable()
	mut writer := writable.get_writer()!
	assert writer.write(undefined_value()).state() == .rejected
	assert writable.state() == .errored
	assert transform.readable().state() == .errored
	assert transform.readable().stored_error() == 'transform failed'
	if _ := transform.controller().transform_algorithm() {
		assert false
	}
	if _ := transform.controller().flush_algorithm() {
		assert false
	}
	if _ := transform.controller().cancel_algorithm() {
		assert false
	}
}

fn test_controller_enqueue_error_and_terminate() {
	mut transform := TransformStream.construct_impl(Transformer{}, QueuingStrategy{}, QueuingStrategy{
		high_water_mark: 2
	})!
	mut controller := transform.controller()
	controller.enqueue(string_value('manual'))!
	mut readable := transform.readable()
	mut reader := readable.get_default_reader()!
	assert reader.read().result().value.text == 'manual'
	controller.terminate()
	assert readable.state() == .closed
	assert transform.writable().state() == .errored
	assert transform.writable().stored_error() == 'TypeError: Stream has been terminated.'
	if _ := controller.transform_algorithm() {
		assert false
	}
	if _ := controller.enqueue(string_value('late')) {
		assert false
	}
}

fn test_close_uses_one_finish_promise_and_clears_algorithms() {
	mut transform := TransformStream.construct_impl(Transformer{
		transform: uppercase_transform
		flush: flush_marker
	}, QueuingStrategy{}, QueuingStrategy{
		high_water_mark: 4
	})!
	first := transform_stream_default_sink_close_algorithm(mut transform)
	second := transform_stream_default_sink_close_algorithm(mut transform)
	assert voidptr(first) == voidptr(second)
	assert first.state() == .fulfilled
	mut readable := transform.readable()
	mut reader := readable.get_default_reader()!
	assert reader.read().result().value.text == 'FLUSH'
	assert reader.read().result().done
	assert transform.readable().state() == .closed
	if _ := transform.controller().transform_algorithm() {
		assert false
	}
	if _ := transform.controller().flush_algorithm() {
		assert false
	}
	if _ := transform.controller().cancel_algorithm() {
		assert false
	}
}

fn test_abort_and_cancel_follow_side_specific_finish_steps() {
	mut aborted := TransformStream.construct_impl(Transformer{}, QueuingStrategy{}, QueuingStrategy{
		high_water_mark: 1
	})!
	abort_result := transform_stream_default_sink_abort_algorithm(mut aborted, string_value('abort reason'))
	assert abort_result.state() == .fulfilled
	assert aborted.readable().state() == .errored
	assert aborted.readable().stored_error() == 'abort reason'
	if _ := aborted.controller().cancel_algorithm() {
		assert false
	}

	mut cancelled := TransformStream.construct_impl(Transformer{}, QueuingStrategy{}, QueuingStrategy{})!
	assert cancelled.backpressure()
	cancel_result := transform_stream_default_source_cancel_algorithm(mut cancelled, string_value('cancel reason'))
	assert cancel_result.state() == .fulfilled
	assert cancelled.writable().state() == .errored
	assert cancelled.writable().stored_error() == 'cancel reason'
	assert !cancelled.backpressure()
	if _ := cancelled.controller().cancel_algorithm() {
		assert false
	}
}

fn test_source_pull_returns_the_new_backpressure_change_promise() {
	mut transform := TransformStream.construct_impl(Transformer{}, QueuingStrategy{}, QueuingStrategy{})!
	old_promise := transform.backpressure_change_promise()
	new_promise := transform_stream_default_source_pull_algorithm(mut transform)
	assert old_promise.state() == .fulfilled
	assert new_promise.state() == .pending
	assert voidptr(new_promise) == voidptr(transform.backpressure_change_promise())
}

fn test_generic_transform_stream_exposes_same_endpoints() {
	transform := TransformStream.construct_impl(Transformer{}, QueuingStrategy{}, QueuingStrategy{})!
	generic := GenericTransformStream.from_transform(transform)
	assert voidptr(generic.readable()) == voidptr(transform.readable())
	assert voidptr(generic.writable()) == voidptr(transform.writable())
}

fn test_transformer_type_members_are_rejected() {
	if _ := TransformStream.construct_impl(Transformer{
		readable_type: 'bytes'
	}, QueuingStrategy{}, QueuingStrategy{}) {
		assert false
	} else {
		assert err.msg().contains('readableType')
	}
	if _ := TransformStream.construct_impl(Transformer{
		writable_type: 'bytes'
	}, QueuingStrategy{}, QueuingStrategy{}) {
		assert false
	} else {
		assert err.msg().contains('writableType')
	}
}

fn test_transform_start_exception_is_propagated() {
	if _ := TransformStream.construct_impl(Transformer{
		start: failing_transform_start
	}, QueuingStrategy{}, QueuingStrategy{}) {
		assert false
	} else {
		assert err.msg() == 'transform start failed'
	}
}
