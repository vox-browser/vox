/* Native backend/ANGLE shader acceptance and exact-pixel comparison. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "native_egl.h"
typedef struct { char const *name; int version; unsigned stage; char const *source; int expected; } ShaderCase;
static ShaderCase cases[] = {
    {"uniform-named-texture2D",2,0x8b30,"precision mediump float;uniform vec4 texture2D;void main(){gl_FragColor=texture2D;}",1},
    {"macro-uniform-named-texture2D",2,0x8b30,"precision mediump float;\n#define NAME texture2D\nuniform vec4 NAME;void main(){gl_FragColor=NAME;}",1},
    {"basic-fragment",2,0x8b30,"precision mediump float; void main(){gl_FragColor=vec4(1.0);}",1},
    {"basic-vertex",2,0x8b31,"attribute vec2 position; void main(){gl_Position=vec4(position,0.0,1.0);}",1},
    {"sampler-named-texture",2,0x8b30,"precision mediump float; uniform sampler2D texture; void main(){gl_FragColor=texture2D(texture,vec2(0.5));}",1},
    {"texture2d-user-function-overload",2,0x8b30,"precision mediump float; float texture2D(float x){return x;} void main(){gl_FragColor=vec4(texture2D(1.0));}",1},
    {"macro-frag-color",2,0x8b30,"precision mediump float;\n#define COLOR gl_FragColor\nvoid main(){COLOR=vec4(1.0);}",1},
    {"macro-unused-frag-color",2,0x8b30,"precision mediump float;\n#define COLOR gl_FragColor\nvoid main(){gl_FragColor=vec4(1.0);}",1},
    {"inactive-frag-color-webgl2",3,0x8b30,"#version 300 es\nprecision mediump float;\n#if __VERSION__ < 300\n#define COLOR gl_FragColor\n#else\nout vec4 color;\n#define COLOR color\n#endif\nvoid main(){COLOR=vec4(1.0);}",1},
    {"builtin-max-varying",2,0x8b31,"void main(){gl_Position=vec4(float(gl_MaxVaryingVectors));}",1},
    {"builtin-max-fragment-uniform",2,0x8b30,"precision mediump float; void main(){gl_FragColor=vec4(float(gl_MaxFragmentUniformVectors));}",1},
    {"es300-basic-fragment",3,0x8b30,"#version 300 es\nprecision mediump float; out vec4 color; void main(){color=vec4(1.0);}",1},
    {"es300-basic-vertex",3,0x8b31,"#version 300 es\nin vec2 position; void main(){gl_Position=vec4(position,0.0,1.0);}",1},
    {"es300-invariant-position",3,0x8b31,"#version 300 es\ninvariant gl_Position; in vec2 position; void main(){gl_Position=vec4(position,0.0,1.0);}",1},
    {"disabled-desktop-gl-inactive",2,0x8b30,"precision mediump float;\n#if 0\ndouble x;\n#endif\nvoid main(){gl_FragColor=vec4(1.0);}",1},
    {"macro-frag-color-only-inactive",2,0x8b30,"precision mediump float;\n#if 0\n#define UNUSED gl_FragData[0]\n#endif\nvoid main(){gl_FragColor=vec4(1.0);}",1},
    {"macro-token-paste",2,0x8b30,"precision mediump float;\n#define CAT(a,b) a ## b\nvoid main(){CAT(gl_,FragColor)=vec4(1.0);}",0},
    {"invalid-essl100-bitwise",2,0x8b31,"void main(){int x=1; gl_Position=vec4(float(x << 1));}",0},
    {"invalid-essl100-dynamic-loop",2,0x8b31,"uniform int n; void main(){float x=0.0;for(int i=0;i<n;i++){x+=1.0;}gl_Position=vec4(x);}",0},
    {"invalid-essl300-missing-float-precision",3,0x8b30,"#version 300 es\nout vec4 color;void main(){color=vec4(1.0);}",0},
    {"sampler-named-textureProj",2,0x8b30,"precision mediump float;uniform sampler2D textureProj;void main(){gl_FragColor=texture2DProj(textureProj,vec3(0.5,0.5,1.0));}",1},
    {"sampler-named-textureLod-vertex",2,0x8b31,"uniform sampler2D textureLod;void main(){gl_Position=texture2DLod(textureLod,vec2(0.5),0.0);}",1},
    {"sampler-named-textureProjLod-vertex",2,0x8b31,"uniform sampler2D textureProjLod;void main(){gl_Position=texture2DProjLod(textureProjLod,vec3(0.5,0.5,1.0),0.0);}",1},
    {"sampler-named-texture-cube",2,0x8b30,"precision mediump float;uniform samplerCube texture;void main(){gl_FragColor=textureCube(texture,vec3(1.0,0.0,0.0));}",1},
    {"sampler-named-textureLod-cube-vertex",2,0x8b31,"uniform samplerCube textureLod;void main(){gl_Position=textureCubeLod(textureLod,vec3(1.0,0.0,0.0),0.0);}",1},
    {"sampler-biased-lookup",2,0x8b30,"precision mediump float;uniform sampler2D texture;void main(){gl_FragColor=texture2D(texture,vec2(0.5),0.0);}",1},
    {"sampler-macro-lookup",2,0x8b30,"precision mediump float;uniform sampler2D texture;\n#define SAMPLE(s,p) texture2D(s,p)\nvoid main(){gl_FragColor=SAMPLE(texture,vec2(0.5));}",1},
    {"legacy-qualifier-macros",2,0x8b30,"#define FP mediump\nprecision FP float;uniform sampler2D texture;void main(){gl_FragColor=texture2D(texture,vec2(0.5));}",1},
    {"valid-constant-loop",2,0x8b31,"void main(){float x=0.0;for(int i=0;i<4;i++){x+=1.0;}gl_Position=vec4(x);}",1},
    {"valid-es300-dynamic-loop",3,0x8b31,"#version 300 es\nuniform int n;void main(){float x=0.0;for(int i=0;i<n;i++){x+=1.0;}gl_Position=vec4(x);}",1},
    {"valid-es300-bitwise",3,0x8b31,"#version 300 es\nvoid main(){int x=1;gl_Position=vec4(float(x << 1));}",1},
    {"invalid-es100-uint",2,0x8b31,"void main(){uint x=1u;gl_Position=vec4(float(x));}",0},
    {"invalid-es100-while",2,0x8b31,"uniform int n;void main(){int i=0;while(i<n){i++;}gl_Position=vec4(float(i));}",0},
    {"invalid-unknown-type",2,0x8b31,"void main(){made_up_type x;gl_Position=vec4(1.0);}",0},
    {"invalid-double-active",2,0x8b30,"precision mediump float;double x;void main(){gl_FragColor=vec4(1.0);}",0},
    {"invalid-missing-semicolon",2,0x8b30,"precision mediump float;void main(){gl_FragColor=vec4(1.0) }",0},
    {"valid-conditional-precision",3,0x8b30,"#version 300 es\n#if GL_ES\nprecision mediump float;\n#endif\nout vec4 color;void main(){color=vec4(1.0);}",1},
    {"valid-inactive-invalid-loop",2,0x8b31,"#if 0\nvoid bad(){while(true){}}\n#endif\nvoid main(){gl_Position=vec4(1.0);}",1},
    {"valid-commented-precision",2,0x8b30,"precision /* keep */ mediump /* keep */ float;void main(){gl_FragColor=vec4(1.0);}",1},
    {"valid-empty-then-source",2,0x8b30,"precision mediump float;void main(){gl_FragColor=vec4(1.0);}",1},
};

static unsigned compile(unsigned stage, char const* source)
{
    unsigned shader = vox_gl_create_shader(stage);
    vox_gl_shader_source(shader, source, (int)strlen(source));
    vox_gl_compile_shader(shader);
    return shader;
}

static int check_shader(ShaderCase const* test)
{
    void* context = vox_egl_create(test->version);
    if (!context) return 1;
    unsigned shader = compile(test->stage, test->source);
    int success = vox_gl_shader_parameter(shader, 0x8b81) != 0;
    char original[4096] = {0}, log[4096] = {0};
    vox_gl_get_shader_source(shader, sizeof(original), original);
    vox_gl_shader_log(shader, sizeof(log), log);
    int retained = strcmp(original, test->source) == 0
        && vox_gl_shader_parameter(shader, 0x8b88) == (int)strlen(test->source) + 1;
    unsigned error = vox_gl_get_error();
    int passed = success == test->expected && retained && !error && (success || *log);
    printf("{\"kind\":\"compile\",\"name\":\"%s\",\"compiled\":%d,\"retained\":%d,\"error\":%u,\"passed\":%d}\n",
        test->name, success, retained, error, passed);
    if (!passed) fprintf(stderr, "%s: %s\n", test->name, log);
    vox_gl_delete_shader(shader);
    vox_egl_destroy(context);
    return !passed;
}

typedef struct { char const* name; char const* sampler; char const* expression; int cube; } PixelCase;
static PixelCase pixel_cases[] = {
    {"texture2D-name", "texture", "texture2D(texture,vec2(0.5))", 0},
    {"texture2D-bias", "texture", "texture2D(texture,vec2(0.5),0.0)", 0},
    {"texture2DProj-vec3", "textureProj", "texture2DProj(textureProj,vec3(0.5,0.5,1.0))", 0},
    {"texture2DProj-vec4", "textureProj", "texture2DProj(textureProj,vec4(0.5,0.5,0.0,1.0))", 0},
    {"texture2DProj-bias-vec3", "textureProj", "texture2DProj(textureProj,vec3(0.5,0.5,1.0),0.0)", 0},
    {"texture2DProj-bias-vec4", "textureProj", "texture2DProj(textureProj,vec4(0.5,0.5,0.0,1.0),0.0)", 0},
    {"textureCube-name", "texture", "textureCube(texture,vec3(1.0,0.0,0.0))", 1},
    {"textureCube-bias", "texture", "textureCube(texture,vec3(1.0,0.0,0.0),0.0)", 1},
};

static int check_pixels(PixelCase const* test)
{
    void* context = vox_egl_create(2);
    if (!context || !vox_egl_allocate_surface(context, 8, 8, 1, 0)) return 1;
    vox_gl_bind_framebuffer(0x8d40, vox_egl_default_framebuffer(context));
    char source[2048];
    snprintf(source, sizeof(source), "precision mediump float;uniform %s %s;void main(){gl_FragColor=%s;}",
        test->cube ? "samplerCube" : "sampler2D", test->sampler, test->expression);
    unsigned vertex = compile(0x8b31, "attribute vec2 position;void main(){gl_Position=vec4(position,0.0,1.0);}");
    unsigned fragment = compile(0x8b30, source);
    unsigned program = vox_gl_create_program();
    vox_gl_attach_shader(program, vertex); vox_gl_attach_shader(program, fragment);
    vox_gl_bind_attrib_location(program, 0, "position"); vox_gl_link_program(program);
    int linked = vox_gl_program_parameter(program, 0x8b82) != 0;
    vox_gl_use_program(program);
    unsigned target = test->cube ? 0x8513 : 0x0de1;
    unsigned texture = vox_gl_gen_object(3);
    vox_gl_active_texture(0x84c0); vox_gl_bind_texture(target, texture);
    vox_gl_tex_parameteri(target, 0x2801, 0x2600); vox_gl_tex_parameteri(target, 0x2800, 0x2600);
    unsigned char color[] = {13, 29, 103, 255};
    for (int face = 0; face < (test->cube ? 6 : 1); ++face)
        vox_gl_tex_image2d(test->cube ? 0x8515 + face : target, 0, 0x1908, 1, 1, 0, 0x1908, 0x1401, 4, color);
    vox_gl_uniform1i(vox_gl_uniform_location(program, test->sampler), 0);
    float vertices[] = {-1, -1, 3, -1, -1, 3};
    unsigned buffer = vox_gl_gen_object(0);
    vox_gl_bind_buffer(0x8892, buffer); vox_gl_buffer_data(0x8892, sizeof(vertices), vertices, 0x88e4);
    vox_gl_vertex_attrib_pointer(0, 2, 0x1406, 0, 0, 0); vox_gl_vertex_attrib_enable(0, 1);
    vox_gl_draw_arrays(4, 0, 3);
    unsigned char pixels[256] = {0};
    int exact = vox_egl_copy_drawing_buffer(context, 8, 8, pixels);
    for (int i = 0; i < 256; i += 4) if (memcmp(pixels + i, color, 4)) exact = 0;
    unsigned error = vox_gl_get_error();
    int passed = linked && exact && !error;
    printf("{\"kind\":\"pixels\",\"name\":\"%s\",\"linked\":%d,\"exact\":%d,\"error\":%u,\"passed\":%d,\"rgba\":\"",
        test->name, linked, exact, error, passed);
    for (int i = 0; i < 256; ++i) printf("%02x", pixels[i]);
    puts("\"}");
    vox_egl_destroy(context);
    return !passed;
}

int main(void)
{
    int failed = 0;
    for (size_t i = 0; i < sizeof(cases) / sizeof(*cases); ++i) failed += check_shader(&cases[i]);
    for (size_t i = 0; i < sizeof(pixel_cases) / sizeof(*pixel_cases); ++i) failed += check_pixels(&pixel_cases[i]);
    printf("{\"kind\":\"summary\",\"failed\":%d,\"compile_cases\":%zu,\"pixel_cases\":%zu}\n", failed,
        sizeof(cases) / sizeof(*cases), sizeof(pixel_cases) / sizeof(*pixel_cases));
    return failed != 0;
}
