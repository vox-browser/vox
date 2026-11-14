module metal

import math

fn test_metal_gpu_clear_initialization_and_resize() {
	mut buffer := DrawingBuffer.create(3, 2)!
	defer { buffer.close() }
	assert buffer.read_pixels()! == []u8{len: 24}
	buffer.clear(1, 0.25, 0.5, 1)!
	assert buffer.read_pixels()! == [u8(255), 64, 128, 255].repeat(6)
	buffer.resize(3, 2)!
	assert buffer.read_pixels()! == [u8(255), 64, 128, 255].repeat(6)
	buffer.resize(2, 3)!
	width, height := buffer.size()
	assert width == 2 && height == 3
	assert buffer.read_pixels()! == []u8{len: 24}
	buffer.clear(-1, 2, math.nan(), 0.5)!
	assert buffer.read_pixels()! == [u8(0), 255, 0, 128].repeat(6)
}

fn test_metal_gpu_transfer_keeps_rows_channels_and_context_ownership() {
	mut first := DrawingBuffer.create(3, 2)!
	mut second := DrawingBuffer.create(3, 2)!
	defer {
		first.close()
		second.close()
	}
	pixels := [u8(1), 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12,
		13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24]
	first.write_pixels(pixels)!
	assert first.read_pixels()! == pixels
	assert second.read_pixels()! == []u8{len: 24}
	mut rejected := false
	first.resize(0, 5) or { rejected = true }
	assert rejected
	width, height := first.size()
	assert width == 3 && height == 2
	assert first.read_pixels()! == pixels
}

fn test_metal_invalid_upload_and_closed_context_are_rejected() {
	mut buffer := DrawingBuffer.create(1, 1)!
	mut rejected := false
	buffer.write_pixels([u8(1), 2, 3]) or { rejected = true }
	assert rejected
	assert buffer.read_pixels()! == [u8(0), 0, 0, 0]
	buffer.close()
	buffer.close()
	rejected = false
	buffer.clear(1, 1, 1, 1) or { rejected = true }
	assert rejected
	rejected = false
	buffer.read_pixels() or { rejected = true }
	assert rejected
}
