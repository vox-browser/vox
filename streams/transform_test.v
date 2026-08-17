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
	transform :=
		TransformStream.construct_impl(Transformer{}, QueuingStrategy{}, QueuingStrategy{})!
	assert transform.controller().desired_size()? == 0
	assert transform.backpressure()
}

fn test_custom_transform_and_flush_feed_readable_side() {
	mut transform := TransformStream.construct_impl(Transformer{
		transform: uppercase_transform
		flush:     flush_marker
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
	}, QueuingStrategy{}, QueuingStrategy{})!
	mut writable := transform.writable()
	mut writer := writable.get_writer()!
	assert writer.write(undefined_value()).state() == .rejected
	assert writable.state() == .errored
	assert transform.readable().state() == .errored
	assert transform.readable().stored_error() == 'transform failed'
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
	if _ := controller.enqueue(string_value('late')) {
		assert false
	}
}

fn test_generic_transform_stream_exposes_same_endpoints() {
	transform :=
		TransformStream.construct_impl(Transformer{}, QueuingStrategy{}, QueuingStrategy{})!
	generic := GenericTransformStream.from_transform(transform)
	assert voidptr(generic.readable()) == voidptr(transform.readable())
	assert voidptr(generic.writable()) == voidptr(transform.writable())
}

fn test_transformer_type_members_are_rejected() {
	if _ := TransformStream.construct_impl(Transformer{
		readable_type: 'bytes'
	}, QueuingStrategy{}, QueuingStrategy{})
	{
		assert false
	} else {
		assert err.msg().contains('readableType')
	}
	if _ := TransformStream.construct_impl(Transformer{
		writable_type: 'bytes'
	}, QueuingStrategy{}, QueuingStrategy{})
	{
		assert false
	} else {
		assert err.msg().contains('writableType')
	}
}
