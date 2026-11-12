module shader

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
