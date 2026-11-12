module webgl

// The same PR #63 ESSL inputs run against both GPU services.
struct ESSLAcceptanceCase {
    name string
    version WebGLVersion
    stage u32
    source string
    accepted bool
}

fn test_essl_acceptance_preserves_macros_names_builtins_and_language_rejections() {
    cases:=[
        ESSLAcceptanceCase{name:'uniform-named-texture2D',version:.webgl1,stage:0x8b30,source:'precision mediump float;uniform vec4 texture2D;void main(){gl_FragColor=texture2D;}',accepted:true}
        ESSLAcceptanceCase{name:'macro-uniform-named-texture2D',version:.webgl1,stage:0x8b30,source:'precision mediump float;\n#define NAME texture2D\nuniform vec4 NAME;void main(){gl_FragColor=NAME;}',accepted:true}
        ESSLAcceptanceCase{name:'basic-fragment',version:.webgl1,stage:0x8b30,source:'precision mediump float; void main(){gl_FragColor=vec4(1.0);}',accepted:true}
        ESSLAcceptanceCase{name:'basic-vertex',version:.webgl1,stage:0x8b31,source:'attribute vec2 position; void main(){gl_Position=vec4(position,0.0,1.0);}',accepted:true}
        ESSLAcceptanceCase{name:'sampler-named-texture',version:.webgl1,stage:0x8b30,source:'precision mediump float; uniform sampler2D texture; void main(){gl_FragColor=texture2D(texture,vec2(0.5));}',accepted:true}
        ESSLAcceptanceCase{name:'texture2d-user-function-overload',version:.webgl1,stage:0x8b30,source:'precision mediump float; float texture2D(float x){return x;} void main(){gl_FragColor=vec4(texture2D(1.0));}',accepted:true}
        ESSLAcceptanceCase{name:'macro-frag-color',version:.webgl1,stage:0x8b30,source:'precision mediump float;\n#define COLOR gl_FragColor\nvoid main(){COLOR=vec4(1.0);}',accepted:true}
        ESSLAcceptanceCase{name:'macro-unused-frag-color',version:.webgl1,stage:0x8b30,source:'precision mediump float;\n#define COLOR gl_FragColor\nvoid main(){gl_FragColor=vec4(1.0);}',accepted:true}
        ESSLAcceptanceCase{name:'inactive-frag-color-webgl2',version:.webgl2,stage:0x8b30,source:'#version 300 es\nprecision mediump float;\n#if __VERSION__ < 300\n#define COLOR gl_FragColor\n#else\nout vec4 color;\n#define COLOR color\n#endif\nvoid main(){COLOR=vec4(1.0);}',accepted:true}
        ESSLAcceptanceCase{name:'builtin-max-varying',version:.webgl1,stage:0x8b31,source:'void main(){gl_Position=vec4(float(gl_MaxVaryingVectors));}',accepted:true}
        ESSLAcceptanceCase{name:'builtin-max-fragment-uniform',version:.webgl1,stage:0x8b30,source:'precision mediump float; void main(){gl_FragColor=vec4(float(gl_MaxFragmentUniformVectors));}',accepted:true}
        ESSLAcceptanceCase{name:'es300-basic-fragment',version:.webgl2,stage:0x8b30,source:'#version 300 es\nprecision mediump float; out vec4 color; void main(){color=vec4(1.0);}',accepted:true}
        ESSLAcceptanceCase{name:'es300-basic-vertex',version:.webgl2,stage:0x8b31,source:'#version 300 es\nin vec2 position; void main(){gl_Position=vec4(position,0.0,1.0);}',accepted:true}
        ESSLAcceptanceCase{name:'es300-invariant-position',version:.webgl2,stage:0x8b31,source:'#version 300 es\ninvariant gl_Position; in vec2 position; void main(){gl_Position=vec4(position,0.0,1.0);}',accepted:true}
        ESSLAcceptanceCase{name:'disabled-desktop-gl-inactive',version:.webgl1,stage:0x8b30,source:'precision mediump float;\n#if 0\ndouble x;\n#endif\nvoid main(){gl_FragColor=vec4(1.0);}',accepted:true}
        ESSLAcceptanceCase{name:'macro-frag-color-only-inactive',version:.webgl1,stage:0x8b30,source:'precision mediump float;\n#if 0\n#define UNUSED gl_FragData[0]\n#endif\nvoid main(){gl_FragColor=vec4(1.0);}',accepted:true}
        ESSLAcceptanceCase{name:'macro-token-paste',version:.webgl1,stage:0x8b30,source:'precision mediump float;\n#define CAT(a,b) a ## b\nvoid main(){CAT(gl_,FragColor)=vec4(1.0);}',accepted:false}
        ESSLAcceptanceCase{name:'invalid-essl100-bitwise',version:.webgl1,stage:0x8b31,source:'void main(){int x=1; gl_Position=vec4(float(x << 1));}',accepted:false}
        ESSLAcceptanceCase{name:'invalid-essl100-dynamic-loop',version:.webgl1,stage:0x8b31,source:'uniform int n; void main(){float x=0.0;for(int i=0;i<n;i++){x+=1.0;}gl_Position=vec4(x);}',accepted:false}
        ESSLAcceptanceCase{name:'invalid-essl300-missing-float-precision',version:.webgl2,stage:0x8b30,source:'#version 300 es\nout vec4 color;void main(){color=vec4(1.0);}',accepted:false}
        ESSLAcceptanceCase{name:'sampler-named-textureProj',version:.webgl1,stage:0x8b30,source:'precision mediump float;uniform sampler2D textureProj;void main(){gl_FragColor=texture2DProj(textureProj,vec3(0.5,0.5,1.0));}',accepted:true}
        ESSLAcceptanceCase{name:'sampler-named-textureLod-vertex',version:.webgl1,stage:0x8b31,source:'uniform sampler2D textureLod;void main(){gl_Position=texture2DLod(textureLod,vec2(0.5),0.0);}',accepted:true}
        ESSLAcceptanceCase{name:'sampler-named-textureProjLod-vertex',version:.webgl1,stage:0x8b31,source:'uniform sampler2D textureProjLod;void main(){gl_Position=texture2DProjLod(textureProjLod,vec3(0.5,0.5,1.0),0.0);}',accepted:true}
        ESSLAcceptanceCase{name:'sampler-named-texture-cube',version:.webgl1,stage:0x8b30,source:'precision mediump float;uniform samplerCube texture;void main(){gl_FragColor=textureCube(texture,vec3(1.0,0.0,0.0));}',accepted:true}
        ESSLAcceptanceCase{name:'sampler-named-textureLod-cube-vertex',version:.webgl1,stage:0x8b31,source:'uniform samplerCube textureLod;void main(){gl_Position=textureCubeLod(textureLod,vec3(1.0,0.0,0.0),0.0);}',accepted:true}
        ESSLAcceptanceCase{name:'sampler-biased-lookup',version:.webgl1,stage:0x8b30,source:'precision mediump float;uniform sampler2D texture;void main(){gl_FragColor=texture2D(texture,vec2(0.5),0.0);}',accepted:true}
        ESSLAcceptanceCase{name:'sampler-macro-lookup',version:.webgl1,stage:0x8b30,source:'precision mediump float;uniform sampler2D texture;\n#define SAMPLE(s,p) texture2D(s,p)\nvoid main(){gl_FragColor=SAMPLE(texture,vec2(0.5));}',accepted:true}
        ESSLAcceptanceCase{name:'legacy-qualifier-macros',version:.webgl1,stage:0x8b30,source:'#define FP mediump\nprecision FP float;uniform sampler2D texture;void main(){gl_FragColor=texture2D(texture,vec2(0.5));}',accepted:true}
        ESSLAcceptanceCase{name:'valid-constant-loop',version:.webgl1,stage:0x8b31,source:'void main(){float x=0.0;for(int i=0;i<4;i++){x+=1.0;}gl_Position=vec4(x);}',accepted:true}
        ESSLAcceptanceCase{name:'valid-es300-dynamic-loop',version:.webgl2,stage:0x8b31,source:'#version 300 es\nuniform int n;void main(){float x=0.0;for(int i=0;i<n;i++){x+=1.0;}gl_Position=vec4(x);}',accepted:true}
        ESSLAcceptanceCase{name:'valid-es300-bitwise',version:.webgl2,stage:0x8b31,source:'#version 300 es\nvoid main(){int x=1;gl_Position=vec4(float(x << 1));}',accepted:true}
        ESSLAcceptanceCase{name:'invalid-es100-uint',version:.webgl1,stage:0x8b31,source:'void main(){uint x=1u;gl_Position=vec4(float(x));}',accepted:false}
        ESSLAcceptanceCase{name:'invalid-es100-while',version:.webgl1,stage:0x8b31,source:'uniform int n;void main(){int i=0;while(i<n){i++;}gl_Position=vec4(float(i));}',accepted:false}
        ESSLAcceptanceCase{name:'invalid-unknown-type',version:.webgl1,stage:0x8b31,source:'void main(){made_up_type x;gl_Position=vec4(1.0);}',accepted:false}
        ESSLAcceptanceCase{name:'invalid-double-active',version:.webgl1,stage:0x8b30,source:'precision mediump float;double x;void main(){gl_FragColor=vec4(1.0);}',accepted:false}
        ESSLAcceptanceCase{name:'invalid-missing-semicolon',version:.webgl1,stage:0x8b30,source:'precision mediump float;void main(){gl_FragColor=vec4(1.0) }',accepted:false}
        ESSLAcceptanceCase{name:'valid-conditional-precision',version:.webgl2,stage:0x8b30,source:'#version 300 es\n#if GL_ES\nprecision mediump float;\n#endif\nout vec4 color;void main(){color=vec4(1.0);}',accepted:true}
        ESSLAcceptanceCase{name:'valid-inactive-invalid-loop',version:.webgl1,stage:0x8b31,source:'#if 0\nvoid bad(){while(true){}}\n#endif\nvoid main(){gl_Position=vec4(1.0);}',accepted:true}
        ESSLAcceptanceCase{name:'valid-commented-precision',version:.webgl1,stage:0x8b30,source:'precision /* keep */ mediump /* keep */ float;void main(){gl_FragColor=vec4(1.0);}',accepted:true}
        ESSLAcceptanceCase{name:'valid-empty-then-source',version:.webgl1,stage:0x8b30,source:'precision mediump float;void main(){gl_FragColor=vec4(1.0);}',accepted:true}
    ]
    for case in cases {
        mut context:=WebGLRenderingContext.new(case.version,WebGLContextAttributes{},[])
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
