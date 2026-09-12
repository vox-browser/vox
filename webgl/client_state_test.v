module webgl

fn test_current_vertex_array_binding_tracks_webgl2_and_oes_objects() {
	mut webgl2 := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	array := webgl2.create_vertex_array()
	webgl2.bind_vertex_array(array)
	assert (webgl2.current_vertex_array_binding() or { panic('WebGL2 binding expected') }).handle_ == array.object.handle_
	webgl2.bind_vertex_array(none)
	assert webgl2.current_vertex_array_binding() == none

	mut webgl1 := WebGLRenderingContext.new(.webgl1, WebGLContextAttributes{}, [])
	oes_array := webgl1.create_vertex_array_oes()
	webgl1.bind_vertex_array_oes(oes_array)
	assert (webgl1.current_vertex_array_binding() or { panic('OES binding expected') }).handle_ == oes_array.object.handle_
	webgl1.delete_vertex_array_oes(oes_array)
	assert webgl1.current_vertex_array_binding() == none
}

fn test_reset_client_side_webgl_state_clears_all_object_bindings() {
	mut context := WebGLRenderingContext.new(.webgl2, WebGLContextAttributes{}, [])
	buffer := context.create_buffer()
	context.bind_buffer(array_buffer, buffer)
	framebuffer_object := context.create_framebuffer()
	context.bind_framebuffer(framebuffer, framebuffer_object)
	renderbuffer_object := context.create_renderbuffer()
	context.bind_renderbuffer(renderbuffer, renderbuffer_object)
	texture := context.create_texture()
	context.bind_texture(texture_2d, texture)
	array := context.create_vertex_array()
	context.bind_vertex_array(array)
	mut query := context.create_query()
	context.begin_query(any_samples_passed, mut query)

	context.reset_client_side_webgl_state()
	assert context.bound_buffers.len == 0
	assert context.bound_framebuffer == 0
	assert context.bound_renderbuffer == 0
	assert context.bound_textures.len == 0
	assert context.current_program == none
	assert context.current_queries.len == 0
	assert context.current_vertex_array == none
	assert context.current_vertex_array_oes == none
	assert context.current_vertex_array_binding() == none
}
