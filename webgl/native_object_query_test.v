module webgl

fn test_native_is_queries_distinguish_generated_names_from_bound_gl_objects() {
	mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
	buffer:=context.create_buffer()
	fbo:=context.create_framebuffer()
	rbo:=context.create_renderbuffer()
	texture:=context.create_texture()
	shader:=context.create_shader(vertex_shader) or {panic('shader')}
	program:=context.create_program()
	assert !context.is_buffer(buffer)
	assert !context.is_framebuffer(fbo)
	assert !context.is_renderbuffer(rbo)
	assert !context.is_texture(texture)
	assert context.is_shader(shader)
	assert context.is_program(program)
	context.bind_buffer(array_buffer,buffer)
	context.bind_framebuffer(framebuffer,fbo)
	context.bind_renderbuffer(renderbuffer,rbo)
	context.bind_texture(texture_2d,texture)
	assert context.is_buffer(buffer)
	assert context.is_framebuffer(fbo)
	assert context.is_renderbuffer(rbo)
	assert context.is_texture(texture)
	// Native deletion cannot be disguised by the retained V wrapper map.
	context.native.make_current()
	C.vox_gl_delete_object(3,texture.object.native_handle_)
	assert !context.is_texture(texture)
	context.delete_buffer(buffer)
	context.delete_framebuffer(fbo)
	context.delete_renderbuffer(rbo)
	context.delete_shader(shader)
	context.delete_program(program)
	assert !context.is_buffer(buffer)
	assert !context.is_framebuffer(fbo)
	assert !context.is_renderbuffer(rbo)
	assert !context.is_shader(shader)
	assert !context.is_program(program)
	assert context.get_error()==no_error
	mut foreign:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
	assert !foreign.is_texture(texture)
	assert foreign.get_error()==invalid_operation
}
