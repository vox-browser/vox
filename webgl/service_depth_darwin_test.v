module webgl

fn C.vox_metal_service_no_angle() i32

fn test_direct_metal_user_depth_stencil_renderbuffer_controls_real_fragment_visibility() {
    mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{depth:false,stencil:false},[])
    defer { context.native.set_lost() }
    context.set_size(2,2)
    fbo:=context.create_framebuffer();context.bind_framebuffer(framebuffer,fbo)
    color:=context.create_texture();context.bind_texture(texture_2d,color)
    context.tex_storage2d(texture_2d,1,0x8058,2,2)
    context.framebuffer_texture2d(framebuffer,color_attachment0,texture_2d,color,0)
    depth_buffer:=context.create_renderbuffer();context.bind_renderbuffer(renderbuffer,depth_buffer)
    context.renderbuffer_storage(renderbuffer,0x88f0,2,2)
    context.framebuffer_renderbuffer(framebuffer,depth_stencil_attachment,renderbuffer,depth_buffer)
    assert context.check_framebuffer_status(framebuffer)==0x8cd5
    mut vertex:=context.create_shader(vertex_shader) or { panic('vertex') }
    mut fragment:=context.create_shader(fragment_shader) or { panic('fragment') }
    context.shader_source(mut vertex,'#version 300 es\nuniform float z;void main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,z,1);}')
    context.shader_source(mut fragment,'#version 300 es\nprecision highp float;uniform vec4 value;out vec4 color;void main(){color=value;}')
    context.compile_shader(mut vertex);context.compile_shader(mut fragment)
    mut program:=context.create_program();context.attach_shader(mut program,vertex);context.attach_shader(mut program,fragment);context.link_program(mut program)
    assert context.get_program_parameter(program,link_status).boolean
    context.use_program(program)
    z:=context.get_uniform_location(mut program,'z') or { panic('z') }
    value:=context.get_uniform_location(mut program,'value') or { panic('value') }
    context.clear_depth(1);context.clear_stencil(0);context.clear(0x4500)
    context.enable(depth_test)
    context.uniform1f(z,0.5);context.uniform4f(value,1,0,0,1);context.draw_arrays(4,0,3)
    assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(255),0,0,255]
    context.uniform1f(z,0.9);context.uniform4f(value,0,0,1,1);context.draw_arrays(4,0,3)
    assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(255),0,0,255]
    context.enable(stencil_test);context.stencil_func(0x200,0,255)
    context.uniform1f(z,-0.5);context.draw_arrays(4,0,3)
    assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(255),0,0,255]
    context.stencil_func(0x207,7,255);context.stencil_op(0x1e00,0x1e00,0x1e01)
    context.uniform4f(value,0,1,0,1);context.draw_arrays(4,0,3)
    assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(0),255,0,255]
    assert context.get_error()==no_error,metal_service_current().last_failure
    context.delete_renderbuffer(depth_buffer)
    assert context.check_framebuffer_status(framebuffer)==0x8cd5
    context.uniform1f(z,0.9);context.uniform4f(value,1,0,1,1);context.draw_arrays(4,0,3)
    assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(255),0,255,255]
    assert context.get_error()==no_error
    assert C.vox_metal_service_no_angle()==1
}
