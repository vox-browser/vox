module webgl

fn test_get_parameter_reads_actual_webgl_driver_state() {
	mut context := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	context.set_size(640, 480)

	assert context.get_parameter(active_texture).integer == texture0
	assert context.get_parameter(dither).boolean
	assert context.get_parameter(viewport).integers == [i64(0), 0, 640, 480]
	assert context.get_parameter(scissor_box).integers == [i64(0), 0, 0, 0]
	assert context.get_parameter(color_writemask).booleans == [true, true, true, true]
	assert context.get_parameter(depth_clear_value).number == 1
	assert context.get_parameter(depth_writemask).boolean
	assert context.get_parameter(pack_alignment).integer == 4
	assert context.get_parameter(blend_equation_rgb).integer == func_add
	assert context.get_parameter(blend_src_alpha).integer == gl_one
	assert context.get_parameter(cull_face_mode).integer == back
	assert context.get_parameter(depth_func).integer == less
	assert context.get_parameter(front_face).integer == ccw
	assert context.get_parameter(sample_coverage_value).number == 1
	assert context.get_parameter(stencil_func).integer == always
	assert context.get_parameter(stencil_writemask).integer == -1

	context.clear_color(0.25, 0.5, 0.75, 1)
	context.blend_color(-1, 0.5, 2, 1)
	context.color_mask(true, false, true, false)
	context.depth_range(0.2, 0.8)
	context.viewport(1, 2, 300, 200)
	context.scissor(3, 4, 100, 80)
	context.disable(dither)
	context.enable(blend)
	context.pixel_storei(unpack_alignment, 1)
	context.blend_equation_separate(func_subtract, func_reverse_subtract)
	context.blend_func_separate(0x0302, 0x0303, 0x0304, 0x0305)
	context.cull_face(front)
	context.depth_func(gequal)
	context.front_face(cw)
	context.hint(generate_mipmap_hint, nicest)
	context.polygon_offset(1.25, -2.5)
	context.sample_coverage(0.75, true)
	context.stencil_func_separate(front, notequal, 7, 0xf0)
	context.stencil_mask_separate(back, 0x0f)
	context.stencil_op_separate(front, replace, incr, decr_wrap)

	assert context.get_parameter(color_clear_value).numbers == [0.25, 0.5, 0.75, 1.0]
	assert context.get_parameter(blend_color).numbers == [0.0, 0.5, 1.0, 1.0]
	assert context.get_parameter(color_writemask).booleans == [true, false, true, false]
	assert context.get_parameter(depth_range).numbers == [f64(f32(0.2)), f64(f32(0.8))]
	assert context.get_parameter(viewport).integers == [i64(1), 2, 300, 200]
	assert context.get_parameter(scissor_box).integers == [i64(3), 4, 100, 80]
	assert !context.get_parameter(dither).boolean
	assert context.get_parameter(blend).boolean
	assert context.get_parameter(unpack_alignment).integer == 1
	assert context.get_parameter(blend_equation_rgb).integer == func_subtract
	assert context.get_parameter(blend_equation_alpha).integer == func_reverse_subtract
	assert context.get_parameter(blend_src_rgb).integer == 0x0302
	assert context.get_parameter(blend_dst_alpha).integer == 0x0305
	assert context.get_parameter(cull_face_mode).integer == front
	assert context.get_parameter(depth_func).integer == gequal
	assert context.get_parameter(front_face).integer == cw
	assert context.get_parameter(generate_mipmap_hint).integer == nicest
	assert context.get_parameter(polygon_offset_factor).number == 1.25
	assert context.get_parameter(polygon_offset_units).number == -2.5
	assert context.get_parameter(sample_coverage_value).number == 0.75
	assert context.get_parameter(sample_coverage_invert).boolean
	assert context.get_parameter(stencil_func).integer == notequal
	assert context.get_parameter(stencil_ref).integer == 7
	assert context.get_parameter(stencil_value_mask).integer == 0xf0
	assert context.get_parameter(stencil_back_writemask).integer == 0x0f
	assert context.get_parameter(stencil_fail).integer == replace
	assert context.get_parameter(stencil_pass_depth_fail).integer == incr
	assert context.get_parameter(stencil_pass_depth_pass).integer == decr_wrap
}

fn test_source_empty_reset_preserves_actual_driver_state() {
	mut context := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	context.blend_equation(func_subtract)
	context.cull_face(front)
	context.sample_coverage(-2, true)
	context.stencil_mask(0x1234)
	assert context.get_parameter(sample_coverage_value).number == 0

 context.reset_to_default_state()
 assert context.get_parameter(blend_equation_rgb).integer==func_subtract
 assert context.get_parameter(cull_face_mode).integer==front
 assert context.get_parameter(sample_coverage_value).number==0
 assert context.get_parameter(sample_coverage_invert).boolean
 assert context.get_parameter(stencil_writemask).integer==0x1234

}

fn test_invalid_native_state_enums_do_not_change_tracked_values() {
	mut context := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	context.cull_face(0xdead)
	assert context.get_parameter(cull_face_mode).integer == back
	assert context.get_error() == invalid_enum
	context.depth_func(0xdead)
	assert context.get_parameter(depth_func).integer == less
	assert context.get_error() == invalid_enum
	context.stencil_op(front, keep, keep)
	assert context.get_parameter(stencil_fail).integer == keep
	assert context.get_error() == invalid_enum
	context.blend_func(0xdead, gl_zero)
	assert context.get_parameter(blend_src_rgb).integer == gl_one
	assert context.get_error() == invalid_enum
	context.blend_func(constant_color, constant_alpha)
	assert context.get_parameter(blend_src_rgb).integer == gl_one
	assert context.get_error() == invalid_operation
}

fn test_blend_minmax_and_derivative_hint_follow_version_and_extension_gates() {
	mut webgl1 := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	webgl1.blend_equation(gl_min)
	assert webgl1.get_parameter(blend_equation_rgb).integer == func_add
	assert webgl1.get_error() == invalid_enum
	assert webgl1.get_parameter(fragment_shader_derivative_hint).kind == .none
	assert webgl1.get_error() == invalid_enum

	mut webgl2 := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	webgl2.blend_equation(gl_max)
	webgl2.hint(fragment_shader_derivative_hint, fastest)
	assert webgl2.get_parameter(blend_equation_rgb).integer == gl_max
	assert webgl2.get_parameter(fragment_shader_derivative_hint).integer == fastest
}

fn test_get_parameter_returns_live_object_bindings_and_rejects_unknown_names() {
	mut context := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	buffer := context.create_buffer()
	texture := context.create_texture()
	framebuffer_object := context.create_framebuffer()
	renderbuffer_object := context.create_renderbuffer()

	assert context.get_parameter(array_buffer_binding).kind == .none
	context.bind_buffer(array_buffer, buffer)
	context.bind_texture(texture_2d, texture)
	context.bind_framebuffer(framebuffer, framebuffer_object)
	context.bind_renderbuffer(renderbuffer, renderbuffer_object)
	assert context.get_parameter(array_buffer_binding).object == buffer.object.handle_
	assert context.get_parameter(texture_binding_2d).object == texture.object.handle_
	assert context.get_parameter(framebuffer_binding).object == framebuffer_object.object.handle_
	assert context.get_parameter(renderbuffer_binding).object == renderbuffer_object.object.handle_

	assert context.get_parameter(0xdeadbeef).kind == .none
	assert context.get_error() == invalid_enum
}

fn test_pixel_store_alignment_rejects_values_outside_the_webgl_set() {
	mut context := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	context.pixel_storei(pack_alignment, 3)
	assert context.get_parameter(pack_alignment).integer == 4
	assert context.get_error() == invalid_value
}

fn test_get_parameter_exposes_webgl2_bindings_and_transform_feedback_state() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	copy_buffer := context.create_buffer()
	pack_buffer := context.create_buffer()
	uniform_buffer_object := context.create_buffer()
	feedback_buffer := context.create_buffer()
	context.bind_buffer(copy_read_buffer, copy_buffer)
	context.bind_buffer(pixel_pack_buffer, pack_buffer)
	context.bind_buffer(uniform_buffer, uniform_buffer_object)
	context.bind_buffer(transform_feedback_buffer, feedback_buffer)

	feedback := context.create_transform_feedback()
	context.bind_transform_feedback(transform_feedback, feedback)
	context.begin_transform_feedback(0x0004)
	assert context.get_error() == invalid_operation
	context.pause_transform_feedback()
	assert context.get_error() == invalid_operation
	sampler := context.create_sampler()
	context.bind_sampler(0, sampler)
	array := context.create_vertex_array()
	context.bind_vertex_array(array)
	texture3d := context.create_texture()
	array_texture := context.create_texture()
	context.bind_texture(texture_3d, texture3d)
	context.bind_texture(texture_2d_array, array_texture)
	context.pixel_storei(pack_row_length, 16)
	context.pixel_storei(unpack_skip_images, 3)

	assert context.get_parameter(copy_read_buffer).object == copy_buffer.object.handle_
	assert context.get_parameter(pixel_pack_buffer_binding).object == pack_buffer.object.handle_
	assert context.get_parameter(uniform_buffer_binding).object == uniform_buffer_object.object.handle_
	assert context.get_parameter(transform_feedback_buffer_binding).object == feedback_buffer.object.handle_
	// The source declares this retained slot but never fills it on bind.
	assert context.get_parameter(transform_feedback_binding).kind == .none
	mut native_feedback := i32(0)
	C.vox_gl_int_parameter(transform_feedback_binding, &native_feedback)
	assert GLuint(native_feedback) == feedback.object.native_handle_
	assert !context.get_parameter(transform_feedback_active).boolean
	assert !context.get_parameter(transform_feedback_paused).boolean
	assert (context.get_parameter(sampler_binding).sampler or {panic("sampler")}).object.native_handle_ == sampler.object.native_handle_
	assert context.get_parameter(vertex_array_binding).object == array.object.handle_
	assert context.get_parameter(texture_binding_3d).object == texture3d.object.handle_
	assert context.get_parameter(texture_binding_2d_array).object == array_texture.object.handle_
	assert context.get_parameter(pack_row_length).integer == 16
	assert context.get_parameter(unpack_skip_images).integer == 3
	assert context.get_parameter(pack_skip_pixels).integer == 0

	mut webgl1 := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	assert webgl1.get_parameter(transform_feedback_active).kind == .none
	assert webgl1.get_error() == invalid_enum
	webgl1.pixel_storei(pack_row_length, 4)
	assert webgl1.get_error() == invalid_enum
	webgl1.bind_texture(texture_3d, webgl1.create_texture())
	assert webgl1.get_parameter(texture_binding_3d).kind == .none
	assert webgl1.get_error() == invalid_enum
}

fn test_webgl2_pixel_store_rejects_negative_values_without_changing_state() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	context.pixel_storei(unpack_row_length, 12)
	context.pixel_storei(unpack_row_length, -1)
	assert context.get_parameter(unpack_row_length).integer == 12
	assert context.get_error() == invalid_value
}
