module webgl

fn C.vox_metal_service_no_angle() i32

fn service_texture_program(mut context WebGLRenderingContext,fragment_source string) &WebGLProgram {
    mut vertex:=context.create_shader(vertex_shader) or { panic('vertex') }
    mut fragment:=context.create_shader(fragment_shader) or { panic('fragment') }
    context.shader_source(mut vertex,'#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0,1);}')
    context.shader_source(mut fragment,fragment_source)
    context.compile_shader(mut vertex);context.compile_shader(mut fragment)
    mut program:=context.create_program()
    context.attach_shader(mut program,vertex);context.attach_shader(mut program,fragment)
    context.link_program(mut program)
    assert context.get_program_parameter(program,link_status).boolean,context.get_program_info_log(program) or { '' }
    context.use_program(program)
    return program
}

fn test_direct_metal_texture_sampling_observes_uploads_subimages_and_framebuffer_writes() {
    mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
    defer { context.native.set_lost() }
    context.set_size(2,2)
    texture:=context.create_texture()
    context.bind_texture(texture_2d,texture)
    context.tex_parameteri(texture_2d,texture_min_filter,0x2600)
    context.tex_parameteri(texture_2d,texture_mag_filter,0x2600)
    context.tex_image2d(texture_2d,0,int(rgba),1,1,0,rgba,unsigned_byte,[u8(255),0,0,255])
    service_texture_program(mut context,'#version 300 es\nprecision highp float;uniform sampler2D image;out vec4 color;void main(){color=texture(image,vec2(0.5));}')
    context.draw_arrays(4,0,3)
    assert context.get_error()==no_error,metal_service_current().last_failure
    assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(255),0,0,255]
    context.tex_sub_image2d(texture_2d,0,0,0,1,1,rgba,unsigned_byte,[u8(0),255,0,255])
    context.draw_arrays(4,0,3)
    assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(0),255,0,255]
    fbo:=context.create_framebuffer()
    context.bind_framebuffer(framebuffer,fbo)
    context.framebuffer_texture2d(framebuffer,color_attachment0,texture_2d,texture,0)
    context.draw_arrays(4,0,3)
    assert context.get_error()==invalid_operation
    context.clear_color(0,0,1,1);context.clear(0x4000)
    context.bind_framebuffer(framebuffer,none)
    context.draw_arrays(4,0,3)
    assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(0),0,255,255]
    assert context.get_error()==no_error
    assert metal_service_current().unsupported.len==0
    assert C.vox_metal_service_no_angle()==1
}

fn test_direct_metal_array_and_integer_samplers_use_reflected_texture_types() {
    mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
    defer { context.native.set_lost() }
    context.set_size(1,1)
    texture:=context.create_texture()
    context.bind_texture(texture_2d_array,texture)
    context.tex_storage3d(texture_2d_array,1,0x8058,1,1,2)
    context.tex_parameteri(texture_2d_array,texture_min_filter,0x2600)
    context.tex_parameteri(texture_2d_array,texture_mag_filter,0x2600)
    context.tex_sub_image3d(texture_2d_array,0,0,0,1,1,1,1,rgba,unsigned_byte,[u8(255),0,255,255])
    service_texture_program(mut context,'#version 300 es\nprecision highp float;precision highp sampler2DArray;uniform sampler2DArray image;out vec4 color;void main(){color=texture(image,vec3(0.5,0.5,1));}')
    context.draw_arrays(4,0,3)
    assert context.get_error()==no_error,metal_service_current().last_failure
    assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(255),0,255,255]
    integer_texture:=context.create_texture()
    context.bind_texture(texture_2d,integer_texture)
    context.tex_parameteri(texture_2d,texture_min_filter,0x2600)
    context.tex_parameteri(texture_2d,texture_mag_filter,0x2600)
    integers:=[i32(-2_000_000_001),2_000_000_001,-7,9]
    context.tex_image2d(texture_2d,0,0x8d82,1,1,0,rgba_integer,gl_int,unsafe { (&u8(integers.data)).vbytes(16).clone() })
    service_texture_program(mut context,'#version 300 es\nprecision highp float;precision highp isampler2D;uniform isampler2D image;out vec4 color;void main(){color=all(equal(texture(image,vec2(0.5)),ivec4(-2000000001,2000000001,-7,9)))?vec4(0,1,0,1):vec4(1,0,0,1);}')
    context.draw_arrays(4,0,3)
    assert context.get_error()==no_error,metal_service_current().last_failure
    assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(0),255,0,255]
    assert metal_service_current().unsupported.len==0
    assert C.vox_metal_service_no_angle()==1
}

fn test_direct_metal_multiple_fragment_outputs_and_indexed_clears_preserve_attachments() {
    mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
    defer { context.native.set_lost() }
    context.set_size(2,2)
    fbo:=context.create_framebuffer()
    context.bind_framebuffer(framebuffer,fbo)
    for i in 0..2 {
        texture:=context.create_texture()
        context.bind_texture(texture_2d,texture)
        context.tex_storage2d(texture_2d,1,0x8058,2,2)
        context.framebuffer_texture2d(framebuffer,color_attachment0+u32(i),texture_2d,texture,0)
    }
    context.draw_buffers([color_attachment0,color_attachment0+1])
    service_texture_program(mut context,'#version 300 es\nprecision highp float;layout(location=0)out vec4 first;layout(location=1)out vec4 second;void main(){first=vec4(1,0,0,1);second=vec4(0,0,1,1);}')
    context.draw_arrays(4,0,3)
    assert context.get_error()==no_error,metal_service_current().last_failure
    context.read_buffer(color_attachment0)
    assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(255),0,0,255]
    context.read_buffer(color_attachment0+1)
    assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(0),0,255,255]
    context.clear_bufferfv(0x1800,1,[f32(0),1,0,1])
    assert context.get_error()==no_error,metal_service_current().last_failure
    assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(0),255,0,255]
    context.read_buffer(color_attachment0)
    assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(255),0,0,255]
    context.clear_color(1,0,1,1);context.clear(0x4000)
    assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(255),0,255,255]
    context.read_buffer(color_attachment0+1)
    assert context.read_pixels(0,0,1,1,rgba,unsigned_byte)==[u8(255),0,255,255]
    assert context.get_error()==no_error
    assert metal_service_current().unsupported.len==0
    assert C.vox_metal_service_no_angle()==1
}

fn test_direct_metal_typed_attachment_clears_and_readback_preserve_ints_uints_and_floats() {
    mut context:=WebGLRenderingContext.new(.webgl2,WebGLContextAttributes{},[])
    defer { context.native.set_lost() }
    fbo:=context.create_framebuffer();context.bind_framebuffer(framebuffer,fbo)
    for internal in [u32(0x8d82),0x8d70,0x8814] {
        texture:=context.create_texture();context.bind_texture(texture_2d,texture)
        context.tex_storage2d(texture_2d,1,internal,1,1)
        context.framebuffer_texture2d(framebuffer,color_attachment0,texture_2d,texture,0)
        assert context.check_framebuffer_status(framebuffer)==0x8cd5
        if internal==0x8d82 {
            context.clear_bufferiv(0x1800,0,[-2_000_000_001,2_000_000_001,-7,9])
            mut values:=[]i32{len:4}
            C.vox_gl_read_pixels(0,0,1,1,rgba_integer,gl_int,16,values.data)
            assert values==[i32(-2_000_000_001),2_000_000_001,-7,9]
        } else if internal==0x8d70 {
            context.clear_bufferuiv(0x1800,0,[u32(0xfedcba98),0xffffffff,0x80000000,1])
            mut values:=[]u32{len:4}
            C.vox_gl_read_pixels(0,0,1,1,rgba_integer,unsigned_int,16,values.data)
            assert values==[u32(0xfedcba98),0xffffffff,0x80000000,1]
        } else {
            context.clear_bufferfv(0x1800,0,[f32(-2),0.25,3,1])
            mut values:=[]f32{len:4}
            C.vox_gl_read_pixels(0,0,1,1,rgba,gl_float,16,values.data)
            assert values==[f32(-2),0.25,3,1]
        }
        assert context.get_error()==no_error,metal_service_current().last_failure
    }
    assert metal_service_current().unsupported.len==0
    assert C.vox_metal_service_no_angle()==1
}
