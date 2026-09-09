module webgl

fn test_get_parameter_reflects_tracked_webgl_state() {
	mut context := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	context.set_size(640, 480)

	assert context.get_parameter(active_texture).integer == texture0
	assert context.get_parameter(dither).boolean
	assert context.get_parameter(viewport).integers == [i64(0), 0, 640, 480]
	assert context.get_parameter(scissor_box).integers == [i64(0), 0, 640, 480]
	assert context.get_parameter(color_writemask).booleans == [true, true, true, true]
	assert context.get_parameter(depth_clear_value).number == 1
	assert context.get_parameter(depth_writemask).boolean
	assert context.get_parameter(pack_alignment).integer == 4

	context.clear_color(0.25, 0.5, 0.75, 1)
	context.color_mask(true, false, true, false)
	context.depth_range(0.2, 0.8)
	context.viewport(1, 2, 300, 200)
	context.scissor(3, 4, 100, 80)
	context.disable(dither)
	context.enable(blend)
	context.pixel_storei(unpack_alignment, 1)

	assert context.get_parameter(color_clear_value).numbers == [0.25, 0.5, 0.75, 1.0]
	assert context.get_parameter(color_writemask).booleans == [true, false, true, false]
	assert context.get_parameter(depth_range).numbers == [0.2, 0.8]
	assert context.get_parameter(viewport).integers == [i64(1), 2, 300, 200]
	assert context.get_parameter(scissor_box).integers == [i64(3), 4, 100, 80]
	assert !context.get_parameter(dither).boolean
	assert context.get_parameter(blend).boolean
	assert context.get_parameter(unpack_alignment).integer == 1
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
	context.pause_transform_feedback()
	sampler := context.create_sampler()
	context.bind_sampler(0, sampler)
	array := context.create_vertex_array()
	context.bind_vertex_array(array)

	assert context.get_parameter(copy_read_buffer).object == copy_buffer.object.handle_
	assert context.get_parameter(pixel_pack_buffer_binding).object == pack_buffer.object.handle_
	assert context.get_parameter(uniform_buffer_binding).object == uniform_buffer_object.object.handle_
	assert context.get_parameter(transform_feedback_buffer_binding).object == feedback_buffer.object.handle_
	assert context.get_parameter(transform_feedback_binding).object == feedback.object.handle_
	assert context.get_parameter(transform_feedback_active).boolean
	assert context.get_parameter(transform_feedback_paused).boolean
	assert context.get_parameter(sampler_binding).object == sampler.object.handle_
	assert context.get_parameter(vertex_array_binding).object == array.object.handle_

	mut webgl1 := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	assert webgl1.get_parameter(transform_feedback_active).kind == .none
	assert webgl1.get_error() == invalid_enum
}
