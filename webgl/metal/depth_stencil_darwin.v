module metal

@[heap]
pub struct DepthStencil {
mut:
	handle voidptr
	owner &DrawingBuffer
	width int
	height int
}

pub fn DepthStencil.create(owner &DrawingBuffer, width int, height int) !&DepthStencil {
	if owner.handle == unsafe { nil } || width < 1 || height < 1 || width > 16384 || height > 16384 { return error('Invalid Metal depth/stencil owner or dimensions') }
	handle := C.vox_metal_depth_stencil_create(owner.handle, i32(width), i32(height))
	if handle == unsafe { nil } { return error('Metal depth/stencil allocation failed') }
	return &DepthStencil{handle: handle, owner: owner, width: width, height: height}
}

pub fn (mut storage DepthStencil) clear(depth f64, stencil u32) ! {
	if C.vox_metal_depth_stencil_clear(storage.handle, clear_component(depth), stencil & 255) != 1 { return error('Metal depth/stencil clear failed or resource is closed') }
}

pub fn (mut storage DepthStencil) close() {
	C.vox_metal_depth_stencil_destroy(storage.handle)
	storage.handle = unsafe { nil }
	storage.width = 0
	storage.height = 0
}
