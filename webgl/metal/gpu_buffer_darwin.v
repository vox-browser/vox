module metal

@[heap]
pub struct GPUBuffer {
mut:
	handle voidptr
	owner &DrawingBuffer
	length int
}

pub fn GPUBuffer.create(owner &DrawingBuffer, size int) !&GPUBuffer {
	if owner.handle == unsafe { nil } || size < 0 { return error('Invalid Metal buffer owner or size') }
	handle := C.vox_metal_gpu_buffer_create(owner.handle, u64(size))
	if handle == unsafe { nil } { return error('Metal buffer allocation failed') }
	return &GPUBuffer{handle: handle, owner: owner, length: size}
}

pub fn (buffer &GPUBuffer) size() int { return buffer.length }

pub fn (mut buffer GPUBuffer) write(offset int, data []u8) ! {
	if offset < 0 || offset > buffer.length || data.len > buffer.length - offset { return error('Metal buffer write outside allocation') }
	if C.vox_metal_gpu_buffer_transfer(buffer.handle, u64(offset), u64(data.len), data.data, 1) != 1 { return error('Metal buffer is closed') }
}

pub fn (buffer &GPUBuffer) read(offset int, length int) ![]u8 {
	if offset < 0 || length < 0 || offset > buffer.length || length > buffer.length - offset { return error('Metal buffer read outside allocation') }
	mut data := []u8{len: length}
	if C.vox_metal_gpu_buffer_transfer(buffer.handle, u64(offset), u64(length), data.data, 0) != 1 { return error('Metal buffer is closed') }
	return data
}

pub fn (mut buffer GPUBuffer) close() {
	C.vox_metal_gpu_buffer_destroy(buffer.handle)
	buffer.handle = unsafe { nil }
	buffer.length = 0
}
