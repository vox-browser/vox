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
