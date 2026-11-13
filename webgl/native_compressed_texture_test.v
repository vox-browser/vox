module webgl

fn compressed_texture_sampling_program(mut context WebGLRenderingContext, array_texture bool) {
	mut vertex:=context.create_shader(vertex_shader) or {panic('vertex')}
	mut fragment:=context.create_shader(fragment_shader) or {panic('fragment')}
	context.shader_source(mut vertex,'#version 300 es\nvoid main(){vec2 positions[3]=vec2[3](vec2(-1,-1),vec2(3,-1),vec2(-1,3));gl_Position=vec4(positions[gl_VertexID],0,1);}')
	context.shader_source(mut fragment,if array_texture {'#version 300 es\nprecision highp float;precision highp sampler2DArray;uniform sampler2DArray inputTexture;out vec4 color;void main(){color=texture(inputTexture,vec3(0.5,0.5,1));}'} else {'#version 300 es\nprecision highp float;uniform sampler2D inputTexture;out vec4 color;void main(){color=texture(inputTexture,vec2(0.5));}'})
	context.compile_shader(mut vertex)
	context.compile_shader(mut fragment)
	assert context.get_shader_parameter(vertex, compile_status).boolean, context.get_shader_info_log(vertex) or {''}
	assert context.get_shader_parameter(fragment, compile_status).boolean, context.get_shader_info_log(fragment) or {''}
	mut program:=context.create_program()
	context.attach_shader(mut program,vertex)
	context.attach_shader(mut program,fragment)
	context.link_program(mut program)
	assert context.get_program_parameter(program, link_status).boolean
	context.use_program(program)
	context.uniform1i(context.get_uniform_location(mut program,'inputTexture'),0)
}

fn test_compressed_2d_texture_data_and_subimage_blocks_reach_native_sampling() {
	mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
	context.set_size(1,1)
	context.get_extension('WEBGL_compressed_texture_s3tc',false) or {panic('S3TC native backend')}
	texture:=context.create_texture()
	context.bind_texture(texture_2d,texture)
	context.tex_parameteri(texture_2d,texture_min_filter,0x2600)
	context.tex_parameteri(texture_2d,texture_mag_filter,0x2600)
	context.compressed_tex_image2d(texture_2d,0,GLenum(0x83f0),4,4,0,[u8(0),248,224,7,0,0,0,0])
	compressed_texture_sampling_program(mut context,false)
	context.draw_arrays(GLenum(4),0,3)
	assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(255),0,0,255]
	assert context.get_error()==no_error
	context.compressed_tex_sub_image2d(texture_2d,0,0,0,4,4,GLenum(0x83f0),[u8(224),7,0,248,0,0,0,0])
	context.draw_arrays(GLenum(4),0,3)
	assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(0),255,0,255]
	context.compressed_tex_sub_image2d(texture_2d,0,0,0,4,4,GLenum(0x83f0),[u8(1)])
	assert context.get_error()==invalid_value
	context.compressed_tex_image2d(texture_2d,0,GLenum(0xbad),4,4,0,[])
	assert context.get_error()==invalid_enum
}

fn test_compressed_array_texture_uses_actual_layer_bytes_and_offset_span() {
	mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
	context.set_size(1,1)
	context.get_extension('WEBGL_compressed_texture_s3tc',false) or {panic('S3TC native backend')}
	texture:=context.create_texture()
	context.bind_texture(texture_2d_array,texture)
	context.tex_parameteri(texture_2d_array,texture_min_filter,0x2600)
	context.tex_parameteri(texture_2d_array,texture_mag_filter,0x2600)
	blocks:=[u8(99),99,0,248,224,7,0,0,0,0,224,7,0,248,0,0,0,0,99]
	context.compressed_tex_image3d(texture_2d_array,0,GLenum(0x83f0),4,4,2,0,blocks,2,16)
	compressed_texture_sampling_program(mut context,true)
	context.draw_arrays(GLenum(4),0,3)
	assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(0),255,0,255]
	assert context.get_error()==no_error
	context.compressed_tex_sub_image3d(texture_2d_array,0,0,0,1,4,4,1,GLenum(0x83f0),[u8(99),0,248,224,7,0,0,0,0],1,8)
	context.draw_arrays(GLenum(4),0,3)
	assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(255),0,0,255]
	assert context.get_error()==no_error
	context.compressed_tex_image3d(texture_2d_array,0,GLenum(0x83f0),4,4,2,0,blocks,20,0)
	assert context.get_error()==invalid_value
}
