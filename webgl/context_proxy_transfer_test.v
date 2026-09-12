module webgl

fn test_context_proxy_records_size_pixel_pack_and_presentation_commands() {
	mut proxy := WebGLContextProxyBase.new(.webgl2, []string{}, 256)!
	proxy.set_size(WebGLIntSize{ width: 320, height: 200 })!
	proxy.read_pixels_into_pixel_pack_buffer(1, 2, 3, 4, 0x1908, 0x1401, 64)!
	proxy.present_canvas_for_compositing(true)

	assert proxy.drawing_buffer_size_ == WebGLIntSize{ width: 320, height: 200 }
	assert proxy.presentation_requests_ == [true]
	batches := proxy.transmitted_batches()
	assert batches.len == 1
	records := WebGLCommandList.for_each_command(batches[0].bytes)!
	assert records.map(it.type_) == [webgl_command_set_drawing_buffer_size,
		webgl_command_read_pixels_into_pixel_pack_buffer]
	assert records[0].payload.len == 8
	assert records[1].payload.len == 40
}

fn test_context_proxy_readback_flushes_and_rejects_invalid_bitmaps() {
	mut proxy := WebGLContextProxyBase.new(.webgl1, []string{}, 128)!
	proxy.record_bytes(1, [u8(9)], []u8{})!
	proxy.set_next_readback_bitmap(WebGLBitmap{
		width: 2
		height: 1
		pixels: [u8(1), 2, 3, 4, 5, 6, 7, 8]
	})
	bitmap := proxy.read_back_drawing_buffer(WebGLIntRect{ width: 2, height: 1 }) or {
		panic('valid readback bitmap expected')
	}
	assert bitmap.pixels == [u8(1), 2, 3, 4, 5, 6, 7, 8]
	assert proxy.transmitted_batches().len == 1

	proxy.set_next_readback_bitmap(WebGLBitmap{ width: 2, height: 2, pixels: [u8(1)] })
	assert proxy.read_back_drawing_buffer(WebGLIntRect{ width: 2, height: 2 }) == none
	proxy.set_lost()
	assert proxy.read_back_drawing_buffer(WebGLIntRect{}) == none
}

fn test_context_proxy_copies_shared_pixel_and_buffer_responses() {
	mut proxy := WebGLContextProxyBase.new(.webgl2, []string{}, 128)!
	proxy.set_next_read_pixels_response(WebGLReadPixelsResult{
		length: 4
		columns: 1
		rows: 1
	}, [u8(11), 22, 33, 44])
	output := proxy.read_pixels_robust_angle(0, 0, 1, 1, 0x1908, 0x1401, 4)
	assert output.length == 4
	assert output.columns == 1
	assert output.rows == 1
	assert output.pixels == [u8(11), 22, 33, 44]

	proxy.set_next_buffer_sub_data([u8(7), 8, 9], true)
	mut destination := []u8{len: 3}
	assert proxy.read_buffer_sub_data(0x8892, 4, mut destination)
	assert destination == [u8(7), 8, 9]
	proxy.set_next_buffer_sub_data([]u8{}, false)
	assert !proxy.read_buffer_sub_data(0x8892, 0, mut destination)
}

fn test_context_proxy_marks_malformed_shared_pixel_reply_lost() {
	mut proxy := WebGLContextProxyBase.new(.webgl1, []string{}, 128)!
	proxy.set_next_read_pixels_response(WebGLReadPixelsResult{ length: 5 }, [u8(1), 2])
	assert proxy.read_pixels_robust_angle(0, 0, 1, 1, 0x1908, 0x1401, 4).length == 0
	assert proxy.is_lost()
}
