module shader

pub struct ESSLAcceptanceCase {
pub:
 name string
 version int
 stage u32
 source string
 accepted bool
}

// Shared with the native WebGL service acceptance test; no case overrides.
pub fn acceptance_cases() []ESSLAcceptanceCase {
 return [
        ESSLAcceptanceCase{name:'uniform-named-texture2D',version:100,stage:0x8b30,source:'precision mediump float;uniform vec4 texture2D;void main(){gl_FragColor=texture2D;}',accepted:true}
        ESSLAcceptanceCase{name:'macro-uniform-named-texture2D',version:100,stage:0x8b30,source:'precision mediump float;\n#define NAME texture2D\nuniform vec4 NAME;void main(){gl_FragColor=NAME;}',accepted:true}
        ESSLAcceptanceCase{name:'basic-fragment',version:100,stage:0x8b30,source:'precision mediump float; void main(){gl_FragColor=vec4(1.0);}',accepted:true}
        ESSLAcceptanceCase{name:'basic-vertex',version:100,stage:0x8b31,source:'attribute vec2 position; void main(){gl_Position=vec4(position,0.0,1.0);}',accepted:true}
        ESSLAcceptanceCase{name:'sampler-named-texture',version:100,stage:0x8b30,source:'precision mediump float; uniform sampler2D texture; void main(){gl_FragColor=texture2D(texture,vec2(0.5));}',accepted:true}
        ESSLAcceptanceCase{name:'texture2d-user-function-overload',version:100,stage:0x8b30,source:'precision mediump float; float texture2D(float x){return x;} void main(){gl_FragColor=vec4(texture2D(1.0));}',accepted:true}
        ESSLAcceptanceCase{name:'macro-frag-color',version:100,stage:0x8b30,source:'precision mediump float;\n#define COLOR gl_FragColor\nvoid main(){COLOR=vec4(1.0);}',accepted:true}
        ESSLAcceptanceCase{name:'macro-unused-frag-color',version:100,stage:0x8b30,source:'precision mediump float;\n#define COLOR gl_FragColor\nvoid main(){gl_FragColor=vec4(1.0);}',accepted:true}
        ESSLAcceptanceCase{name:'inactive-frag-color-webgl2',version:300,stage:0x8b30,source:'#version 300 es\nprecision mediump float;\n#if __VERSION__ < 300\n#define COLOR gl_FragColor\n#else\nout vec4 color;\n#define COLOR color\n#endif\nvoid main(){COLOR=vec4(1.0);}',accepted:true}
        ESSLAcceptanceCase{name:'builtin-max-varying',version:100,stage:0x8b31,source:'void main(){gl_Position=vec4(float(gl_MaxVaryingVectors));}',accepted:true}
        ESSLAcceptanceCase{name:'builtin-max-fragment-uniform',version:100,stage:0x8b30,source:'precision mediump float; void main(){gl_FragColor=vec4(float(gl_MaxFragmentUniformVectors));}',accepted:true}
        ESSLAcceptanceCase{name:'es300-basic-fragment',version:300,stage:0x8b30,source:'#version 300 es\nprecision mediump float; out vec4 color; void main(){color=vec4(1.0);}',accepted:true}
        ESSLAcceptanceCase{name:'es300-basic-vertex',version:300,stage:0x8b31,source:'#version 300 es\nin vec2 position; void main(){gl_Position=vec4(position,0.0,1.0);}',accepted:true}
        ESSLAcceptanceCase{name:'es300-invariant-position',version:300,stage:0x8b31,source:'#version 300 es\ninvariant gl_Position; in vec2 position; void main(){gl_Position=vec4(position,0.0,1.0);}',accepted:true}
        ESSLAcceptanceCase{name:'disabled-desktop-gl-inactive',version:100,stage:0x8b30,source:'precision mediump float;\n#if 0\ndouble x;\n#endif\nvoid main(){gl_FragColor=vec4(1.0);}',accepted:true}
        ESSLAcceptanceCase{name:'macro-frag-color-only-inactive',version:100,stage:0x8b30,source:'precision mediump float;\n#if 0\n#define UNUSED gl_FragData[0]\n#endif\nvoid main(){gl_FragColor=vec4(1.0);}',accepted:true}
        ESSLAcceptanceCase{name:'macro-token-paste',version:100,stage:0x8b30,source:'precision mediump float;\n#define CAT(a,b) a ## b\nvoid main(){CAT(gl_,FragColor)=vec4(1.0);}',accepted:false}
        ESSLAcceptanceCase{name:'invalid-essl100-bitwise',version:100,stage:0x8b31,source:'void main(){int x=1; gl_Position=vec4(float(x << 1));}',accepted:false}
        ESSLAcceptanceCase{name:'invalid-essl100-dynamic-loop',version:100,stage:0x8b31,source:'uniform int n; void main(){float x=0.0;for(int i=0;i<n;i++){x+=1.0;}gl_Position=vec4(x);}',accepted:false}
        ESSLAcceptanceCase{name:'invalid-essl300-missing-float-precision',version:300,stage:0x8b30,source:'#version 300 es\nout vec4 color;void main(){color=vec4(1.0);}',accepted:false}
        ESSLAcceptanceCase{name:'sampler-named-textureProj',version:100,stage:0x8b30,source:'precision mediump float;uniform sampler2D textureProj;void main(){gl_FragColor=texture2DProj(textureProj,vec3(0.5,0.5,1.0));}',accepted:true}
        ESSLAcceptanceCase{name:'sampler-named-textureLod-vertex',version:100,stage:0x8b31,source:'uniform sampler2D textureLod;void main(){gl_Position=texture2DLod(textureLod,vec2(0.5),0.0);}',accepted:true}
        ESSLAcceptanceCase{name:'sampler-named-textureProjLod-vertex',version:100,stage:0x8b31,source:'uniform sampler2D textureProjLod;void main(){gl_Position=texture2DProjLod(textureProjLod,vec3(0.5,0.5,1.0),0.0);}',accepted:true}
        ESSLAcceptanceCase{name:'sampler-named-texture-cube',version:100,stage:0x8b30,source:'precision mediump float;uniform samplerCube texture;void main(){gl_FragColor=textureCube(texture,vec3(1.0,0.0,0.0));}',accepted:true}
        ESSLAcceptanceCase{name:'sampler-named-textureLod-cube-vertex',version:100,stage:0x8b31,source:'uniform samplerCube textureLod;void main(){gl_Position=textureCubeLod(textureLod,vec3(1.0,0.0,0.0),0.0);}',accepted:true}
        ESSLAcceptanceCase{name:'sampler-biased-lookup',version:100,stage:0x8b30,source:'precision mediump float;uniform sampler2D texture;void main(){gl_FragColor=texture2D(texture,vec2(0.5),0.0);}',accepted:true}
        ESSLAcceptanceCase{name:'sampler-macro-lookup',version:100,stage:0x8b30,source:'precision mediump float;uniform sampler2D texture;\n#define SAMPLE(s,p) texture2D(s,p)\nvoid main(){gl_FragColor=SAMPLE(texture,vec2(0.5));}',accepted:true}
        ESSLAcceptanceCase{name:'legacy-qualifier-macros',version:100,stage:0x8b30,source:'#define FP mediump\nprecision FP float;uniform sampler2D texture;void main(){gl_FragColor=texture2D(texture,vec2(0.5));}',accepted:true}
        ESSLAcceptanceCase{name:'valid-constant-loop',version:100,stage:0x8b31,source:'void main(){float x=0.0;for(int i=0;i<4;i++){x+=1.0;}gl_Position=vec4(x);}',accepted:true}
        ESSLAcceptanceCase{name:'valid-es300-dynamic-loop',version:300,stage:0x8b31,source:'#version 300 es\nuniform int n;void main(){float x=0.0;for(int i=0;i<n;i++){x+=1.0;}gl_Position=vec4(x);}',accepted:true}
        ESSLAcceptanceCase{name:'valid-es300-bitwise',version:300,stage:0x8b31,source:'#version 300 es\nvoid main(){int x=1;gl_Position=vec4(float(x << 1));}',accepted:true}
        ESSLAcceptanceCase{name:'invalid-es100-uint',version:100,stage:0x8b31,source:'void main(){uint x=1u;gl_Position=vec4(float(x));}',accepted:false}
        ESSLAcceptanceCase{name:'invalid-es100-while',version:100,stage:0x8b31,source:'uniform int n;void main(){int i=0;while(i<n){i++;}gl_Position=vec4(float(i));}',accepted:false}
        ESSLAcceptanceCase{name:'invalid-unknown-type',version:100,stage:0x8b31,source:'void main(){made_up_type x;gl_Position=vec4(1.0);}',accepted:false}
        ESSLAcceptanceCase{name:'invalid-double-active',version:100,stage:0x8b30,source:'precision mediump float;double x;void main(){gl_FragColor=vec4(1.0);}',accepted:false}
        ESSLAcceptanceCase{name:'invalid-missing-semicolon',version:100,stage:0x8b30,source:'precision mediump float;void main(){gl_FragColor=vec4(1.0) }',accepted:false}
        ESSLAcceptanceCase{name:'valid-conditional-precision',version:300,stage:0x8b30,source:'#version 300 es\n#if GL_ES\nprecision mediump float;\n#endif\nout vec4 color;void main(){color=vec4(1.0);}',accepted:true}
        ESSLAcceptanceCase{name:'valid-inactive-invalid-loop',version:100,stage:0x8b31,source:'#if 0\nvoid bad(){while(true){}}\n#endif\nvoid main(){gl_Position=vec4(1.0);}',accepted:true}
        ESSLAcceptanceCase{name:'valid-commented-precision',version:100,stage:0x8b30,source:'precision /* keep */ mediump /* keep */ float;void main(){gl_FragColor=vec4(1.0);}',accepted:true}
        ESSLAcceptanceCase{name:'valid-empty-then-source',version:100,stage:0x8b30,source:'precision mediump float;void main(){gl_FragColor=vec4(1.0);}',accepted:true}
    ]
}
