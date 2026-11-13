module webgl

fn test_float_filtering_extension_uses_actual_float32_texture_interpolation() {
    mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[]);context.set_size(1,1)
    context.get_extension('OES_texture_float_linear',false) or { return }
    mut vertex:=context.create_shader(vertex_shader) or { panic('vertex') }
    mut fragment:=context.create_shader(fragment_shader) or { panic('fragment') }
    context.shader_source(mut vertex,'#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0,1);}')
    context.shader_source(mut fragment,'#version 300 es\nprecision highp float;uniform sampler2D image;out vec4 color;void main(){color=texture(image,vec2(0.5));}')
    context.compile_shader(mut vertex);context.compile_shader(mut fragment)
    mut program:=context.create_program();context.attach_shader(mut program,vertex);context.attach_shader(mut program,fragment);context.link_program(mut program);assert context.get_program_parameter(program,link_status).boolean;context.use_program(program)
    texture:=context.create_texture();context.bind_texture(texture_2d,texture);context.tex_parameteri(texture_2d,texture_min_filter,0x2601);context.tex_parameteri(texture_2d,texture_mag_filter,0x2601)
    pixels:=[f32(0),0,0,1,1,1,1,1]
    context.tex_image2d(texture_2d,0,0x8814,2,1,0,rgba,gl_float,unsafe { (&u8(pixels.data)).vbytes(32).clone() })
    context.draw_arrays(4,0,3)
    assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(128),128,128,255]
    assert context.get_error()==no_error
}
