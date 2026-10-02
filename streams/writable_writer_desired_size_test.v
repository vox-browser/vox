module streams

fn test_source_writer_desired_size_distinguishes_released_erroring_and_closed() {
	mut stream := WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{})!
	mut writer := stream.get_writer()!
	assert writer.desired_size_for_bindings()!.value? == 1
	mut controller := stream.controller()
	writable_stream_default_controller_error_if_needed(mut controller, string_value('source error'))
	assert writer.desired_size_for_bindings()!.value == none
	writer.release_lock()
	writer.desired_size_for_bindings() or {
		assert err.msg() == 'TypeError: Cannot get desired size of writer that has no locked stream'
		mut closed_stream := WritableStream.construct_impl(UnderlyingSink{}, QueuingStrategy{})!
		mut closed_writer := closed_stream.get_writer()!
		assert closed_writer.close().state() == .fulfilled
		assert closed_writer.desired_size_for_bindings()!.value? == 0
		return
	}
	assert false
}
