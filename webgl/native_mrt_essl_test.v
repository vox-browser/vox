module webgl

fn test_webgl1_draw_buffers_extension_compiles_required_essl_and_writes_both_targets() {
    mut context:=WebGLRenderingContext.new(.webgl1,WebGLContextAttributes{},[])
    context.set_size(2,2)
    extension:=context.get_extension('WEBGL_draw_buffers',false) or { panic('draw buffers') }
    mut vertex:=context.create_shader(vertex_shader) or { panic('vertex') }
    mut fragment:=context.create_shader(fragment_shader) or { panic('fragment') }
    context.shader_source(mut vertex,'attribute vec2 position;void main(){gl_Position=vec4(position,0,1);}')
    context.shader_source(mut fragment,'#extension GL_EXT_draw_buffers : require\nprecision mediump float;void main(){gl_FragData[0]=vec4(1,0,0,1);gl_FragData[1]=vec4(0,1,0,1);}')
    context.compile_shader(mut vertex);context.compile_shader(mut fragment)
    mut program:=context.create_program();context.attach_shader(mut program,vertex);context.attach_shader(mut program,fragment);context.bind_attrib_location(program,0,'position');context.link_program(mut program)
    assert context.get_program_parameter(program,link_status).boolean,context.get_program_info_log(program) or { '' }
    context.use_program(program)
    a:=context.create_texture();b:=context.create_texture()
    for texture in [a,b] { context.bind_texture(texture_2d,texture);context.tex_image2d_null(texture_2d,0,int(rgba),2,2,0,rgba,unsigned_byte) }
    fbo:=context.create_framebuffer();context.bind_framebuffer(framebuffer,fbo)
    context.framebuffer_texture2d(framebuffer,color_attachment0,texture_2d,a,0);context.framebuffer_texture2d(framebuffer,color_attachment0+1,texture_2d,b,0)
    extension.draw_buffers_webgl(mut context,[color_attachment0,color_attachment0+1])
    positions:=[f32(-1),-1,3,-1,-1,3]
    buffer:=context.create_buffer();context.bind_buffer(array_buffer,buffer);context.buffer_data(array_buffer,unsafe { (&u8(positions.data)).vbytes(24).clone() },0x88e4)
    context.vertex_attrib_pointer(0,2,gl_float,false,0,0);context.enable_vertex_attrib_array(0);context.draw_arrays(4,0,3)
    assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(255),0,0,255]
    second:=context.create_framebuffer();context.bind_framebuffer(framebuffer,second);context.framebuffer_texture2d(framebuffer,color_attachment0,texture_2d,b,0)
    assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(0),255,0,255]
    assert context.get_error()==no_error
}
