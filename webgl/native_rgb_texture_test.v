module webgl

fn rgb_sampling_program(mut context WebGLRenderingContext) {
    mut vertex:=context.create_shader(vertex_shader) or { panic('vertex') };mut fragment:=context.create_shader(fragment_shader) or { panic('fragment') }
    context.shader_source(mut vertex,'#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0,1);}')
    context.shader_source(mut fragment,'#version 300 es\nprecision highp float;uniform sampler2D image;out vec4 color;void main(){color=texture(image,vec2(0.5));}')
    context.compile_shader(mut vertex);context.compile_shader(mut fragment)
    mut program:=context.create_program();context.attach_shader(mut program,vertex);context.attach_shader(mut program,fragment);context.link_program(mut program)
    assert context.get_program_parameter(program,link_status).boolean;context.use_program(program)
}

fn test_rgb_null_and_immutable_textures_sample_with_implicit_opaque_alpha() {
    for immutable in [false,true] {
        mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[]);context.set_size(1,1)
        texture:=context.create_texture();context.bind_texture(texture_2d,texture);context.tex_parameteri(texture_2d,texture_min_filter,0x2600)
        if immutable { context.tex_storage2d(texture_2d,1,0x8051,1,1) } else { context.tex_image2d_null(texture_2d,0,int(rgb),1,1,0,rgb,unsigned_byte) }
        rgb_sampling_program(mut context);context.draw_arrays(4,0,3)
        assert context.get_error()==no_error
        assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(0),0,0,255]
    }
}

fn test_rendering_to_rgb_texture_preserves_implicit_alpha_when_sampled_again() {
    mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[]);context.set_size(1,1)
    texture:=context.create_texture();context.bind_texture(texture_2d,texture);context.tex_parameteri(texture_2d,texture_min_filter,0x2600)
    context.tex_image2d(texture_2d,0,int(rgb),1,1,0,rgb,unsigned_byte,[u8(0),0,0])
    fbo:=context.create_framebuffer();context.bind_framebuffer(framebuffer,fbo);context.framebuffer_texture2d(framebuffer,color_attachment0,texture_2d,texture,0)
    context.clear_color(1,0,0,0.25);context.clear(0x4000);context.bind_framebuffer(framebuffer,none)
    rgb_sampling_program(mut context);context.draw_arrays(4,0,3)
    assert context.get_error()==no_error
    assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(255),0,0,255]
}
