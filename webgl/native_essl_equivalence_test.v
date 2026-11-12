module webgl

import webgl.shader as essl

// The same PR #63 ESSL inputs run against both GPU services.

fn test_essl_acceptance_preserves_macros_names_builtins_and_language_rejections() {
    cases:=essl.acceptance_cases()
    for case in cases {
        mut context:=WebGLRenderingContext.new(if case.version==100 {WebGLVersion.webgl1} else {WebGLVersion.webgl2},WebGLContextAttributes{},[])
        defer { context.native.set_lost() }
        mut shader:=context.create_shader(case.stage) or { panic(case.name) }
        context.shader_source(mut shader,case.source);context.compile_shader(mut shader)
        assert context.get_shader_parameter(shader,compile_status).boolean==case.accepted,case.name+': '+(context.get_shader_info_log(shader) or { '' })
        assert context.get_shader_source(shader)?==case.source
        assert context.get_error()==no_error
    }
}

struct ESSLTextureCase {
    name string
    sampler string
    expression string
    cube bool
}

fn test_essl_texture_builtin_overloads_and_renamed_samplers_render_exact_pixels() {
    cases:=[
        ESSLTextureCase{name:'texture2D-name',sampler:'texture',expression:'texture2D(texture,vec2(0.5))',cube:false}
        ESSLTextureCase{name:'texture2D-bias',sampler:'texture',expression:'texture2D(texture,vec2(0.5),0.0)',cube:false}
        ESSLTextureCase{name:'texture2DProj-vec3',sampler:'textureProj',expression:'texture2DProj(textureProj,vec3(0.5,0.5,1.0))',cube:false}
        ESSLTextureCase{name:'texture2DProj-vec4',sampler:'textureProj',expression:'texture2DProj(textureProj,vec4(0.5,0.5,0.0,1.0))',cube:false}
        ESSLTextureCase{name:'texture2DProj-bias-vec3',sampler:'textureProj',expression:'texture2DProj(textureProj,vec3(0.5,0.5,1.0),0.0)',cube:false}
        ESSLTextureCase{name:'texture2DProj-bias-vec4',sampler:'textureProj',expression:'texture2DProj(textureProj,vec4(0.5,0.5,0.0,1.0),0.0)',cube:false}
        ESSLTextureCase{name:'textureCube-name',sampler:'texture',expression:'textureCube(texture,vec3(1.0,0.0,0.0))',cube:true}
        ESSLTextureCase{name:'textureCube-bias',sampler:'texture',expression:'textureCube(texture,vec3(1.0,0.0,0.0),0.0)',cube:true}
    ]
    for case in cases {
        mut context:=WebGLRenderingContext.new(.webgl1,WebGLContextAttributes{},[])
        defer { context.native.set_lost() }
        context.set_size(8,8)
        mut vertex:=context.create_shader(vertex_shader) or { panic('vertex') }
        mut fragment:=context.create_shader(fragment_shader) or { panic('fragment') }
        context.shader_source(mut vertex,'attribute vec2 position;void main(){gl_Position=vec4(position,0,1);}')
        sampler_type:=if case.cube { 'samplerCube' } else { 'sampler2D' }
        context.shader_source(mut fragment,'precision mediump float;uniform ${sampler_type} ${case.sampler};void main(){gl_FragColor=${case.expression};}')
        context.compile_shader(mut vertex);context.compile_shader(mut fragment)
        mut program:=context.create_program();context.attach_shader(mut program,vertex);context.attach_shader(mut program,fragment);context.bind_attrib_location(program,0,'position');context.link_program(mut program)
        assert context.get_program_parameter(program,link_status).boolean,case.name+': '+(context.get_program_info_log(program) or { '' })
        context.use_program(program)
        target:=if case.cube { texture_cube_map } else { texture_2d }
        texture:=context.create_texture();context.bind_texture(target,texture);context.tex_parameteri(target,texture_min_filter,0x2600);context.tex_parameteri(target,texture_mag_filter,0x2600)
        color:=[u8(13),29,103,255]
        for face in 0..if case.cube { 6 } else { 1 } { context.tex_image2d(if case.cube { u32(0x8515+face) } else { target },0,int(rgba),1,1,0,rgba,unsigned_byte,color) }
        context.uniform1i(context.get_uniform_location(mut program,case.sampler),0)
        positions:=[f32(-1),-1,3,-1,-1,3]
        buffer:=context.create_buffer();context.bind_buffer(array_buffer,buffer);context.buffer_data(array_buffer,unsafe { (&u8(positions.data)).vbytes(24).clone() },0x88e4)
        context.vertex_attrib_pointer(0,2,gl_float,false,0,0);context.enable_vertex_attrib_array(0);context.draw_arrays(4,0,3)
        assert context.read_pixels(0,0,8,8,rgba,unsigned_byte)==color.repeat(64),case.name
        assert context.get_error()==no_error,case.name
    }
}
