// Direct Metal drawing-buffer foundation. This package never imports webgl's
// EGL service: it can be built and exercised without ANGLE installed or loaded.
module metal

@[heap]
pub struct DrawingBuffer {
mut:
	handle voidptr
	width int
	height int
}

pub fn DrawingBuffer.create(width int, height int) !&DrawingBuffer {
	handle := C.vox_metal_buffer_create()
	if handle == unsafe { nil } { return error('Metal device or command queue unavailable') }
	mut buffer := &DrawingBuffer{handle: handle}
	buffer.resize(width, height) or {
		buffer.close()
		return err
	}
	return buffer
}

pub fn (buffer &DrawingBuffer) size() (int, int) {
	return buffer.width, buffer.height
}

pub fn (mut buffer DrawingBuffer) resize(width int, height int) ! {
	if buffer.handle == unsafe { nil } { return error('Metal drawing buffer is closed') }
	if width <= 0 || height <= 0 || width > 16384 || height > 16384 {
		return error('Metal drawing-buffer dimensions must be in 1..16384')
	}
	if width == buffer.width && height == buffer.height { return }
	if C.vox_metal_buffer_resize(buffer.handle, i32(width), i32(height)) != 1 {
		return error('Metal drawing-buffer allocation or initialization failed')
	}
	buffer.width = width
	buffer.height = height
}

fn clear_component(value f64) f64 {
	if value != value || value < 0 { return 0 }
	if value > 1 { return 1 }
	return value
}

pub fn (mut buffer DrawingBuffer) clear(red f64, green f64, blue f64, alpha f64) ! {
	if C.vox_metal_buffer_clear(buffer.handle, clear_component(red), clear_component(green),
		clear_component(blue), clear_component(alpha)) != 1 {
		return error('Metal clear failed or drawing buffer is closed')
	}
}

// Pixel transfers are top-row-first, tightly packed, straight-alpha RGBA8.
// WebGL coordinate conversion and compositor premultiplication belong in V
// when the browser's WebGL dispatch is connected to this backend.
pub fn (mut buffer DrawingBuffer) write_pixels(pixels []u8) ! {
	if buffer.handle == unsafe { nil } { return error('Metal drawing buffer is closed') }
	if pixels.len != buffer.width * buffer.height * 4 {
		return error('Metal upload must contain exactly width * height * 4 bytes')
	}
	if C.vox_metal_buffer_transfer(buffer.handle, pixels.data, u64(pixels.len), 1) != 1 {
		return error('Metal upload failed')
	}
}

pub fn (mut buffer DrawingBuffer) read_pixels() ![]u8 {
	if buffer.handle == unsafe { nil } { return error('Metal drawing buffer is closed') }
	mut pixels := []u8{len: buffer.width * buffer.height * 4}
	if C.vox_metal_buffer_transfer(buffer.handle, pixels.data, u64(pixels.len), 0) != 1 {
		return error('Metal readback failed')
	}
	return pixels
}

pub fn (mut buffer DrawingBuffer) close() {
	C.vox_metal_buffer_destroy(buffer.handle)
	buffer.handle = unsafe { nil }
	buffer.width = 0
	buffer.height = 0
}
