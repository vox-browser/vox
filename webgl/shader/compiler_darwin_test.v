module shader

import math

#flag darwin -framework Foundation -framework Metal
#flag darwin -fobjc-arc
#flag darwin @VMODROOT/webgl/shader/compiler_probe_darwin.m

#include "@DIR/compiler_probe.h"

fn C.vox_direct_metal_probe(&char, &char) int

fn test_v_generated_metal_renders_exact_pixels_without_shader_libraries() {
	vertex := translate('#version 300 es\nout vec4 value;void main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0.0,1.0);value=vec4(1.0,0.0,0.0,1.0);}', .vertex)!
	fragment := translate('#version 300 es\nprecision highp float;in vec4 value;out vec4 color;void main(){color=value;}', .fragment)!
	link(vertex, fragment)!
	assert C.vox_direct_metal_probe(vertex.source.str, fragment.source.str) == 1
}

fn test_preprocessed_v_shaders_render_exact_pixels_without_shader_libraries() {
 vertex := translate('#version 300 es\n#define POS gl_Position\n#define V4(x,y,z,w) vec4(x,y,z,w)\n#if __VERSION__ == 300\nout vec4 value;void main(){POS=V4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0.0,1.0);value=V4(1.0,0.0,0.0,1.0);}\n#else\ndouble invalid;\n#endif',.vertex)!
 fragment := translate('#version 300 es\n#if GL_ES && defined(GL_FRAGMENT_PRECISION_HIGH)\nprecision highp float;\n#endif\nin vec4 value;out vec4 color;\n#define SET(x) color=x\nvoid main(){SET(value);}',.fragment)!
 link(vertex,fragment)!
 assert C.vox_direct_metal_probe(vertex.source.str,fragment.source.str) == 1
}

fn C.vox_direct_metal_uniform_probe(&char, &char, voidptr, u64, voidptr, u64) int

fn test_std140_uniforms_render_exact_pixels_with_both_stages_bound() {
 vertex := translate('#version 300 es\nuniform mat4 transform;out vec4 value;void main(){gl_Position=transform*vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0.0,1.0);value=vec4(1.0);}',.vertex)!
 fragment := translate('#version 300 es\nprecision highp float;uniform vec3 tint;uniform float strength;uniform bool enabled;uniform vec4 colors[2];uniform mat2x3 basis;uniform ivec2 indices;uniform uvec2 tags;uniform bool switches[2];in vec4 value;out vec4 color;void main(){color=enabled && switches[1] && indices.x == -7 && tags.y == 4000000000u && basis[0].y == 2.0 && basis[1].z == 6.0 ? vec4(tint*strength,1.0)*colors[1]*value : vec4(0.0,1.0,0.0,1.0);}',.fragment)!
 link(vertex,fragment)!
 assert vertex.uniform_buffer_size == 64
 assert fragment.uniforms.map(it.offset) == [0,12,16,32,64,96,104,112]
 assert fragment.uniform_buffer_size == 144
 // Raw std140 bytes deliberately use independent, fixed offsets. Padding is
 // poisoned so decoding natural MSL float3/bool/array layouts cannot pass.
 transform := [f32(1),0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1]
 mut words := []u32{len:36,init:0xffffffff}
 for i, value in [f32(1),0,0,1] { words[i]=math.f32_bits(value) }
 words[4]=1
 for i, value in [f32(0),1,0,1, 1,1,1,1] { words[8+i]=math.f32_bits(value) }
 for i, value in [f32(1),2,3] { words[16+i]=math.f32_bits(value) }
 for i, value in [f32(4),5,6] { words[20+i]=math.f32_bits(value) }
 words[24]=u32(i32(-7)); words[25]=9
 words[26]=0; words[27]=4000000000
 words[28]=0; words[32]=1
 assert C.vox_direct_metal_uniform_probe(vertex.source.str,fragment.source.str,transform.data,64,words.data,144)==1
 // Change a consumed field: the endpoint requires red, so this must fail.
 words[4]=0
 assert C.vox_direct_metal_uniform_probe(vertex.source.str,fragment.source.str,transform.data,64,words.data,144)==0
}
