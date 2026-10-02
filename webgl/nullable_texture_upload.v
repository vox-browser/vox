// WebGLRenderingContextOverloads / WebGL2RenderingContextOverloads nullable
// texture variants. NULL is distinct from an empty ArrayBufferView.
module webgl

pub fn (mut context WebGLRenderingContext) tex_image2d_null(target GLenum, level int, internal_format int, width int, height int, border int, format GLenum, type_ GLenum) {
	if context.version == .webgl2 {
		if !context.command('tex_image2d', target, level, internal_format, width, height, border, format, type_, 0) {
			return
		}
		C.vox_gl_tex_image2d(target, level, internal_format, width, height, border, format, type_, 0, unsafe { nil })
		context.native.collect_native_error()
		return
	}
	if (type_ == unsigned_short_5_6_5 && format != rgb)
		|| (type_ in [unsigned_short_4_4_4_4, unsigned_short_5_5_5_1] && format != rgba) {
		context.set_error(invalid_operation)
		return
	}
	mut bytes := u64(0)
	match format {
		alpha, luminance, luminance_alpha {
			if type_ != unsigned_byte {
				context.set_error(invalid_enum)
				return
			}
			bytes = if format == luminance_alpha { u64(2) } else { u64(1) }
		}
		rgb, rgba {
			match type_ {
				unsigned_byte { bytes = if format == rgb { u64(3) } else { u64(4) } }
				unsigned_short_4_4_4_4, unsigned_short_5_5_5_1, unsigned_short_5_6_5 { bytes = 2 }
				else {
					context.set_error(invalid_enum)
					return
				}
			}
		}
		else {
			context.set_error(invalid_enum)
			return
		}
	}
	// AK::Checked<size_t> detects negative dimensions and multiplication overflow
	// before the source's zeroed ByteBuffer allocation.
	if width < 0 || height < 0 {
		context.set_error(invalid_operation)
		return
	}
	bytes = checked_mul_u64(bytes, u64(width)) or {
		context.set_error(invalid_operation)
		return
	}
	bytes = checked_mul_u64(bytes, u64(height)) or {
		context.set_error(invalid_operation)
		return
	}
	// Native V arrays and GLsizei capacities cannot represent larger storage.
	if bytes > u64(max_int) {
		context.set_error(out_of_memory)
		return
	}
	pixels := []u8{len: int(bytes)}
	if !context.command('tex_image2d', target, level, internal_format, width, height, border, format, type_, pixels.len) {
		return
	}
	C.vox_gl_tex_image2d(target, level, internal_format, width, height, border, format, type_, pixels.len, pixels.data)
	context.native.collect_native_error()
}

pub fn (mut context WebGLRenderingContext) tex_sub_image2d_null(target GLenum, level int, x_offset int, y_offset int, width int, height int, format GLenum, type_ GLenum) {
	if context.version == .webgl1 {
		context.set_error(invalid_value)
		return
	}
	if !is_valid_2d_pixel_unpack_state(width, context.unpack_state_) {
		context.set_error(invalid_operation)
		return
	}
	if !context.command('tex_sub_image2d', target, level, x_offset, y_offset, width, height, format, type_, 0) {
		return
	}
	C.vox_gl_tex_sub_image2d(target, level, x_offset, y_offset, width, height, format, type_, 0, unsafe { nil })
	context.native.collect_native_error()
}

pub fn (mut context WebGLRenderingContext) tex_image3d_null(target GLenum, level int, internal_format int, width int, height int, depth int, border int, format GLenum, type_ GLenum) {
	if !context.require_webgl2() { return }
	if !context.command('tex_image3d', target, level, internal_format, width, height, depth, border, format, type_, 0) {
		return
	}
	C.vox_gl_tex_image3d(target, level, internal_format, width, height, depth, border, format, type_, 0, unsafe { nil })
	context.native.collect_native_error()
}

pub fn (mut context WebGLRenderingContext) tex_sub_image3d_null(target GLenum, level int, x_offset int, y_offset int, z_offset int, width int, height int, depth int, format GLenum, type_ GLenum) {
	if !context.require_webgl2() { return }
	if !context.command('tex_sub_image3d', target, level, x_offset, y_offset, z_offset, width, height, depth, format, type_, 0) {
		return
	}
	C.vox_gl_tex_sub_image3d(target, level, x_offset, y_offset, z_offset, width, height, depth, format, type_, 0, unsafe { nil })
	context.native.collect_native_error()
}
