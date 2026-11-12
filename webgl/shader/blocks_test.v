module shader

fn test_std140_block_offsets_bindings_and_plain_uniform_space_are_independent() {
 result:=translate('#version 300 es\nlayout(std140) uniform Shade{vec3 tint;float strength;mat2 basis;};uniform float plain;void main(){gl_Position=vec4(tint,plain);}',.vertex)!
 assert result.uniform_blocks.len==1 && result.uniform_blocks[0].name=='Shade'
 assert result.uniform_blocks[0].binding==1 && result.uniform_blocks[0].byte_size==48
 assert result.uniform_buffer_size==16
 assert result.uniforms.map(it.offset)==[0,12,16,0]
 assert result.uniforms.map(it.binding)==[u32(1),1,1,0]
 assert result.source.contains('[[buffer(1)]]')
}

fn test_uniform_block_linkage_checks_member_shapes() {
 vertex:=translate('#version 300 es\nlayout(std140) uniform Shade{vec4 tint;};void main(){gl_Position=tint;}',.vertex)!
 fragment:=translate('#version 300 es\nprecision highp float;layout(std140) uniform Shade{vec3 tint;};out vec4 color;void main(){color=vec4(tint,1.0);}',.fragment)!
 link(vertex,fragment) or {assert err.msg().contains('Uniform block mismatch');return}
 assert false
}

fn test_nested_uniform_block_leaves_keep_the_block_binding() {
 result:=translate('#version 300 es\nstruct Light{vec3 color;float gain;};layout(std140) uniform State{Light lights[2];};void main(){gl_Position=vec4(lights[1].color,1.0);}',.vertex)!
 assert result.uniform_buffer_size==0
 assert result.uniform_blocks[0].byte_size==32
 assert result.uniforms.map(it.name)==['lights[0].color','lights[0].gain','lights[1].color','lights[1].gain']
 assert result.uniforms.map(it.offset)==[0,12,16,28]
 assert result.uniforms.all(it.binding==1)
}
