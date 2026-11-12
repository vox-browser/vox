module metal

pub enum TextureFilter { nearest linear }
pub enum TextureWrap { clamp repeat mirror_repeat }

pub struct SamplerOptions {
pub:
	min_filter TextureFilter
	mag_filter TextureFilter
	wrap_s TextureWrap
	wrap_t TextureWrap
}

@[heap]
pub struct Texture2D {
mut:
	handle voidptr
	owner &DrawingBuffer
	width int
	height int
}

pub fn Texture2D.create(owner &DrawingBuffer, width int, height int) !&Texture2D {
	if owner.handle == unsafe { nil } || width <= 0 || height <= 0 || width > 16384 || height > 16384 { return error('Invalid Metal texture dimensions or owner') }
	handle := C.vox_metal_texture_create(owner.handle, i32(width), i32(height))
	if handle == unsafe { nil } { return error('Metal texture allocation failed') }
	return &Texture2D{handle: handle, owner: owner, width: width, height: height}
}

pub fn (texture &Texture2D) size() (int, int) { return texture.width, texture.height }

pub fn (mut texture Texture2D) write_pixels(bytes []u8) ! {
	if texture.handle == unsafe { nil } || bytes.len != texture.width * texture.height * 4 { return error('Metal texture upload requires a live texture and exact RGBA8 length') }
	if C.vox_metal_buffer_transfer(texture.handle, bytes.data, u64(bytes.len), 1) != 1 { return error('Metal texture upload failed') }
}

pub fn (texture &Texture2D) read_pixels() ![]u8 {
	if texture.handle == unsafe { nil } { return error('Metal texture is closed') }
	mut pixels := []u8{len: texture.width * texture.height * 4}
	if C.vox_metal_buffer_transfer(texture.handle, pixels.data, u64(pixels.len), 0) != 1 { return error('Metal texture readback failed') }
	return pixels
}

pub fn (mut texture Texture2D) sampler(options SamplerOptions) ! {
	if C.vox_metal_texture_sampler(texture.handle, i32(options.min_filter), i32(options.mag_filter), i32(options.wrap_s), i32(options.wrap_t)) != 1 { return error('Metal sampler allocation failed or texture is closed') }
}

pub fn (mut texture Texture2D) close() {
	C.vox_metal_texture_destroy(texture.handle)
	texture.handle = unsafe { nil }
	texture.width = 0
	texture.height = 0
}
