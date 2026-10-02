module webgl

fn test_native_3d_texture_upload_layer_selection_subimage_and_immutable_storage() {
	mut context := WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
	texture := context.create_texture()
	context.bind_texture(texture_3d,texture)
	mut upload := []u8{}
	for _ in 0..4 {upload << [u8(255),0,0,255]}
	for _ in 0..4 {upload << [u8(0),0,255,255]}
	context.tex_image3d(texture_3d,0,GLenum(0x8058),2,2,2,0,rgba,unsigned_byte,upload)
	fbo := context.create_framebuffer()
	context.bind_framebuffer(framebuffer,fbo)
	context.framebuffer_texture_layer(framebuffer,color_attachment0,texture,0,0)
	assert context.check_framebuffer_status(framebuffer)==GLenum(0x8cd5)
	assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(255),0,0,255]
	context.framebuffer_texture_layer(framebuffer,color_attachment0,texture,0,1)
	assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(0),0,255,255]
	context.tex_sub_image3d(texture_3d,0,1,1,1,1,1,1,rgba,unsigned_byte,[u8(0),255,0,255])
	assert context.read_pixels(1,1,1,1,rgba,unsigned_byte)==[u8(0),255,0,255]
	assert context.get_error()==no_error
	context.tex_sub_image3d(texture_3d,0,0,0,0,1,1,1,rgba,unsigned_byte,[u8(7)])
	assert context.get_error()==invalid_operation
	immutable := context.create_texture()
	context.bind_texture(texture_2d_array,immutable)
	context.tex_storage3d(texture_2d_array,1,GLenum(0x8058),2,2,2)
	assert context.get_tex_parameter(texture_2d_array,GLenum(0x912f)).boolean
	assert context.get_tex_parameter(texture_2d_array,GLenum(0x82df)).integer==1
	context.tex_sub_image3d(texture_2d_array,0,0,0,1,1,1,1,rgba,unsigned_byte,[u8(255),255,0,255])
	context.framebuffer_texture_layer(framebuffer,color_attachment0,immutable,0,1)
	assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(255),255,0,255]
	context.tex_storage3d(texture_2d_array,1,GLenum(0x8058),2,2,2)
	assert context.get_error()==invalid_operation
	context.framebuffer_texture_layer(framebuffer,color_attachment0,none,0,0)
	assert context.check_framebuffer_status(framebuffer)==GLenum(0x8cd7)
	mut foreign := WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
	foreign_texture:=foreign.create_texture()
	context.framebuffer_texture_layer(framebuffer,color_attachment0,foreign_texture,0,0)
	assert context.get_error()==invalid_operation
}

fn test_native_copy_tex_image_and_subimage_preserve_framebuffer_pixels() {
	mut context := WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
	context.set_size(2,2)
	context.clear_color(1,0.25,0.5,1)
	context.clear(GLenum(0x4000))
	texture:=context.create_texture()
	context.bind_texture(texture_2d,texture)
	context.copy_tex_image2d(texture_2d,0,rgba,0,0,2,2,0)
	context.clear_color(0,1,0,1)
	context.clear(GLenum(0x4000))
	context.copy_tex_sub_image2d(texture_2d,0,1,1,0,0,1,1)
	fbo:=context.create_framebuffer()
	context.bind_framebuffer(framebuffer,fbo)
	context.framebuffer_texture2d(framebuffer,color_attachment0,texture_2d,texture,0)
	assert context.check_framebuffer_status(framebuffer)==GLenum(0x8cd5)
	assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(255),64,128,255]
	assert context.read_pixels(1,1,1,1,rgba,unsigned_byte)==[u8(0),255,0,255]
	assert context.get_error()==no_error
	immutable:=context.create_texture()
	context.bind_texture(texture_2d,immutable)
	context.tex_storage2d(texture_2d,1,GLenum(0x8058),2,2)
	assert context.get_tex_parameter(texture_2d,GLenum(0x912f)).boolean
	assert context.get_tex_parameter(texture_2d,GLenum(0x82df)).integer==1
}
