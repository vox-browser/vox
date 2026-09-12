module webgl

fn test_framebuffer_tracks_typed_texture_and_renderbuffer_attachments() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	mut framebuffer_object := context.create_framebuffer()
	mut texture_object := context.create_texture()
	mut renderbuffer_object := context.create_renderbuffer()
	context.bind_framebuffer(framebuffer, framebuffer_object)

	context.framebuffer_texture2d(framebuffer, color_attachment0, texture_cube_map_positive_x, texture_object, 2)
	texture_attachment := framebuffer_object.attachment(color_attachment0) or {
		panic('missing texture attachment')
	}
	assert texture_attachment.texture or { panic('missing texture') } == texture_object
	assert texture_attachment.renderbuffer == none
	assert texture_attachment.texture_target == texture_cube_map_positive_x
	assert texture_attachment.texture_level == 2
	assert context.get_framebuffer_attachment_parameter(framebuffer, color_attachment0, framebuffer_attachment_object_type).integer == gl_texture
	assert context.get_framebuffer_attachment_parameter(framebuffer, color_attachment0, framebuffer_attachment_object_name).object == texture_object.object.handle_
	assert context.get_framebuffer_attachment_parameter(framebuffer, color_attachment0, framebuffer_attachment_texture_level).integer == 2
	assert context.get_framebuffer_attachment_parameter(framebuffer, color_attachment0, framebuffer_attachment_texture_cube_map_face).integer == texture_cube_map_positive_x

	context.framebuffer_renderbuffer(framebuffer, color_attachment0, renderbuffer, renderbuffer_object)
	renderbuffer_attachment := framebuffer_object.attachment(color_attachment0) or {
		panic('missing renderbuffer attachment')
	}
	assert renderbuffer_attachment.texture == none
	assert renderbuffer_attachment.renderbuffer or { panic('missing renderbuffer') } == renderbuffer_object
	assert context.get_framebuffer_attachment_parameter(framebuffer, color_attachment0, framebuffer_attachment_object_type).integer == renderbuffer

	context.framebuffer_renderbuffer(framebuffer, color_attachment0, renderbuffer, none)
	assert framebuffer_object.attachment(color_attachment0) == none
	assert context.get_framebuffer_attachment_parameter(framebuffer, color_attachment0, framebuffer_attachment_object_type).integer == 0
}

fn test_framebuffer_attachment_validation_matches_context_version() {
	mut context := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	mut framebuffer_object := context.create_framebuffer()
	mut texture_object := context.create_texture()
	context.bind_framebuffer(framebuffer, framebuffer_object)
	context.framebuffer_texture2d(framebuffer, color_attachment0 + 1, texture_2d, texture_object, 0)
	assert context.get_error() == invalid_enum
	context.framebuffer_texture2d(framebuffer, color_attachment0, texture_2d, texture_object, 1)
	assert context.get_error() == invalid_value
	context.framebuffer_texture2d(framebuffer, color_attachment0, GLenum(0), texture_object, 0)
	assert context.get_error() == invalid_enum

	context.bind_framebuffer(framebuffer, none)
	context.framebuffer_texture2d(framebuffer, color_attachment0, texture_2d, texture_object, 0)
	assert context.get_error() == invalid_operation
}
