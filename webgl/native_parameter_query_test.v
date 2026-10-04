module webgl

fn test_source_parameter_queries_use_actual_driver_and_preserve_real_client_unpack_state() {
	for version in [WebGLVersion.webgl1, .webgl2] {
		mut context := WebGLRenderingContext.new(version, WebGLContextAttributes{stencil: true}, [])
		context.pixel_storei(unpack_alignment, 1)
		C.vox_gl_pixel_storei(unpack_alignment, 8)
		C.vox_gl_pixel_storei(pack_alignment, 2)
		C.vox_gl_cull_face(front)
		C.vox_gl_depth_func(gequal)
		C.vox_gl_stencil_func(equal, 8, 0xf0)
		assert context.get_parameter(unpack_alignment).integer == 8
		assert context.get_parameter(pack_alignment).integer == 2
		assert context.get_parameter(cull_face_mode).integer == front
		assert context.get_parameter(depth_func).integer == gequal
		assert context.get_parameter(stencil_ref).integer == 8
		// Source retains its client bitmap-unpack state separately from GL queries.
		assert context.unpack_state_.alignment == 1
		if version == .webgl2 {
			context.pixel_storei(pack_row_length, 5)
			context.pixel_storei(unpack_row_length, 2)
			C.vox_gl_pixel_storei(pack_row_length, 7)
			C.vox_gl_pixel_storei(unpack_row_length, 4)
			assert context.get_parameter(pack_row_length).integer == 7
			assert context.get_parameter(unpack_row_length).integer == 4
			assert context.unpack_state_.row_length == 2
		}
		assert context.get_error() == no_error
	}
}

fn test_driver_parameter_queries_include_capabilities_types_and_actual_state() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	assert context.get_parameter(GLenum(0x0d33)).integer >= 64 // MAX_TEXTURE_SIZE
	assert context.get_parameter(GLenum(0x8869)).integer >= 8 // MAX_VERTEX_ATTRIBS
	assert context.get_parameter(GLenum(0x0d3a)).integers.len == 2
	assert context.get_parameter(GLenum(0x846d)).numbers.len == 2
	assert context.get_parameter(GLenum(0x1f02)).text.contains('OpenGL ES')
	assert context.get_parameter(GLenum(0x1f00)).text.len > 0
	assert context.get_parameter(GLenum(0x8a30)).kind == .number // 64-bit limit -> JS Number
	assert context.get_parameter(GLenum(0x8a30)).number >= 16384
	assert context.get_parameter(GLenum(0x8b49)).integer > 0
	assert context.get_parameter(GLenum(0x8dfc)).integer > 0
	// The GPU remains authoritative when native state changes outside V caches.
	context.native.dispatch('blend_equation',func_subtract)
	assert context.get_parameter(blend_equation_rgb).integer == func_subtract
	context.native.make_current()
	C.vox_gl_clear_color(0.125,0.25,0.5,0.75)
	assert context.get_parameter(color_clear_value).numbers == [0.125,0.25,0.5,0.75]
	assert context.get_error() == no_error
	mut legacy := WebGLRenderingContext.new(.webgl1,WebGLContextAttributes{},[])
	assert legacy.get_parameter(GLenum(0x8a30)).kind == .none
	assert legacy.get_error() == invalid_enum
	assert legacy.get_parameter(fragment_shader_derivative_hint).kind == .none
	assert legacy.get_error() == invalid_enum
	legacy.get_extension('OES_standard_derivatives',false) or {panic('derivatives')}
	assert legacy.get_parameter(fragment_shader_derivative_hint).integer == dont_care
	legacy.get_extension('OES_vertex_array_object',false) or {panic('vertex arrays')}
	vao := legacy.create_vertex_array_oes()
	legacy.bind_vertex_array_oes(vao)
	assert legacy.get_parameter(vertex_array_binding).object == vao.object.handle_
	assert legacy.get_error() == no_error
}

fn test_texture_and_renderbuffer_parameter_queries_use_native_defaults_and_validation() {
	mut context := WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
	texture := context.create_texture()
	context.bind_texture(texture_2d,texture)
	assert context.get_tex_parameter(texture_2d,texture_mag_filter).integer == 0x2601
	assert context.get_tex_parameter(texture_2d,texture_min_filter).integer == 0x2702
	assert context.get_tex_parameter(texture_2d,texture_wrap_s).integer == 0x2901
	context.native.make_current()
	C.vox_gl_tex_parameteri(texture_2d,texture_mag_filter,0x2600)
	assert context.get_tex_parameter(texture_2d,texture_mag_filter).integer == 0x2600
	assert context.get_tex_parameter(texture_2d,GLenum(0x912f)).kind == .boolean
	// Current upstream intentionally preserved: LOD queries return immutable-format Boolean.
	assert context.get_tex_parameter(texture_2d,texture_min_lod).kind == .boolean
	assert context.get_tex_parameter(texture_2d,0xbad).kind == .none
	assert context.get_error() == invalid_enum
	assert context.get_tex_parameter(0xbad,texture_mag_filter).integer == 0
	assert context.get_error() == invalid_enum
	render_target := context.create_renderbuffer()
	context.bind_renderbuffer(renderbuffer,render_target)
	context.renderbuffer_storage(renderbuffer,GLenum(0x8058),7,5)
	assert context.get_renderbuffer_parameter(renderbuffer,GLenum(0x8d42)).integer == 7
	assert context.get_renderbuffer_parameter(renderbuffer,GLenum(0x8d43)).integer == 5
	assert context.get_renderbuffer_parameter(renderbuffer,GLenum(0x8d44)).integer == 0x8058
	assert context.get_renderbuffer_parameter(renderbuffer,GLenum(0x8d50)).integer == 8
	assert context.get_renderbuffer_parameter(renderbuffer,0xbad).kind == .none
	assert context.get_error() == invalid_enum
	assert context.get_renderbuffer_parameter(0xbad,GLenum(0x8d42)).integer == 0
	assert context.get_error() == invalid_enum
}
