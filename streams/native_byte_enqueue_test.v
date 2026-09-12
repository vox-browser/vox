module streams

fn test_native_byte_enqueue_fulfils_pending_default_read_without_copy_path() {
	realm := StreamRealm.create(17)
	mut stream := ReadableStream.create(realm, UnderlyingSource{
		type_: .bytes
	}, QueuingStrategy{})!
	mut reader := ReadableStreamDefaultReader.create(realm, mut stream)!
	read := reader.read()
	assert read.state() == .pending

	mut controller := stream.byte_controller()!
	readable_byte_stream_controller_enqueue_native_bytes(mut controller, [u8(4), 5, 6])!
	assert read.state() == .fulfilled
	assert read.result().value.bytes_ == [u8(4), 5, 6]
	assert read.realm() == realm
}

fn test_transferred_byte_enqueue_honours_view_bounds_and_queues_the_view() {
	mut stream := ReadableStream.construct_impl(UnderlyingSource{
		type_: .bytes
	}, QueuingStrategy{})!
	mut controller := stream.byte_controller()!
	buffer := ArrayBuffer.from_bytes([u8(10), 20, 30, 40])
	readable_byte_stream_controller_enqueue_transferred_buffer(mut controller, buffer, 1, 2)!
	assert controller.queue_total_size() == 2

	mut reader := stream.get_default_reader()!
	read := reader.read()
	assert read.state() == .fulfilled
	assert read.result().value.bytes_ == [u8(20), 30]

	if _ := readable_byte_stream_controller_enqueue_transferred_buffer(mut controller, buffer,
		3, 2) {
		assert false
	} else {
		assert err.msg().contains('out of bounds')
	}
}

fn test_native_byte_enqueue_is_ignored_after_close_is_requested() {
	mut stream := ReadableStream.construct_impl(UnderlyingSource{
		type_: .bytes
	}, QueuingStrategy{})!
	mut controller := stream.byte_controller()!
	controller.close()!
	readable_byte_stream_controller_enqueue_native_bytes(mut controller, [u8(1), 2])!
	assert controller.queue_total_size() == 0
}
