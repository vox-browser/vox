module webgl

fn test_multisample_framebuffer_blit_resolves_real_renderbuffer_pixels() {
	mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
	sample_counts:=context.get_internalformat_parameter(renderbuffer,GLenum(0x8058),samples).integers
	assert sample_counts.len>0
	count:=int(sample_counts[0])
	ms:=context.create_renderbuffer()
	context.bind_renderbuffer(renderbuffer,ms)
	context.renderbuffer_storage_multisample(renderbuffer,count,GLenum(0x8058),2,2)
	assert context.get_renderbuffer_parameter(renderbuffer,GLenum(0x8cab)).integer==count
	assert context.get_renderbuffer_parameter(renderbuffer,GLenum(0x8d42)).integer==2
	source:=context.create_framebuffer()
	context.bind_framebuffer(framebuffer,source)
	context.framebuffer_renderbuffer(framebuffer,color_attachment0,renderbuffer,ms)
	assert context.check_framebuffer_status(framebuffer)==GLenum(0x8cd5)
	context.clear_color(1,0.5,0,1)
	context.clear(GLenum(0x4000))
	texture:=context.create_texture()
	context.bind_texture(texture_2d,texture)
	context.tex_storage2d(texture_2d,1,GLenum(0x8058),2,2)
	destination:=context.create_framebuffer()
	context.bind_framebuffer(framebuffer,destination)
	context.framebuffer_texture2d(framebuffer,color_attachment0,texture_2d,texture,0)
	context.bind_framebuffer(read_framebuffer,source)
	context.bind_framebuffer(draw_framebuffer,destination)
	context.blit_framebuffer(0,0,2,2,0,0,2,2,GLenum(0x4000),GLenum(0x2600))
	context.bind_framebuffer(framebuffer,destination)
	assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(255),128,0,255]
	assert context.get_error()==no_error
	context.blit_framebuffer(0,0,2,2,0,0,2,2,GLenum(0x4000),0xbad)
	assert context.get_error()==invalid_enum
	context.invalidate_framebuffer(framebuffer,[GLenum(0xbad)])
	assert context.get_error()==invalid_enum
	context.invalidate_sub_framebuffer(framebuffer,[color_attachment0],0,0,-1,2)
	assert context.get_error()==invalid_value
	context.invalidate_sub_framebuffer(framebuffer,[color_attachment0],0,0,2,2)
	assert context.get_error()==no_error
}

fn test_draw_buffers_and_read_buffer_select_actual_color_attachments() {
	mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
	fbo:=context.create_framebuffer()
	context.bind_framebuffer(framebuffer,fbo)
	for index in 0..2 {
	 texture:=context.create_texture()
	 context.bind_texture(texture_2d,texture)
	 context.tex_storage2d(texture_2d,1,GLenum(0x8058),2,2)
	 context.framebuffer_texture2d(framebuffer,color_attachment0+GLenum(index),texture_2d,texture,0)
	}
	context.draw_buffers([color_attachment0,color_attachment0+1])
	context.clear_bufferfv(GLenum(0x1800),0,[f32(1),0,0,1])
	context.clear_bufferfv(GLenum(0x1800),1,[f32(0),0,1,1])
	context.read_buffer(color_attachment0)
	assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(255),0,0,255]
	context.read_buffer(color_attachment0+1)
	assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(0),0,255,255]
	assert context.get_error()==no_error
	context.read_buffer(GLenum(0xbad))
	assert context.get_error()==invalid_enum
	context.draw_buffers([GLenum(0xbad)])
	assert context.get_error()==invalid_enum
}
