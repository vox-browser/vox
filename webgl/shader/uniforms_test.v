module shader

fn test_uniform_layout_reflection_keeps_std140_padding() {
 result := translate('#version 300 es\nuniform float scalar;uniform vec2 pair;uniform vec3 triple;uniform float packed;uniform mat3 matrix;uniform float weights[3];uniform bvec2 flags;void main(){gl_Position=vec4(scalar);}',.vertex)!
 assert result.uniforms.map(it.offset) == [0,8,16,28,32,80,128]
 assert result.uniform_buffer_size == 144
 assert result.uniforms[4].rows == 3 && result.uniforms[4].columns == 3
 assert result.uniforms[4].matrix_stride == 16 && result.uniforms[4].byte_size == 48
 assert result.uniforms[5].array_stride == 16 && result.uniforms[5].array_length == 3
 assert result.uniforms[6].scalar_type == 8 && result.uniforms[6].semantic_type == 2
 assert result.uniforms.all(it.binding == 0)
}

fn test_uniform_declarations_arrays_and_stage_linking() {
 vertex := translate('uniform highp float a,b[1];void main(){gl_Position=vec4(a+b[0]);}',.vertex)!
 assert vertex.uniforms.len == 2
 assert !vertex.uniforms[0].is_array && vertex.uniforms[1].is_array
 fragment := translate('precision highp float;uniform float a,b[1];void main(){gl_FragColor=vec4(a);}',.fragment)!
 link(vertex,fragment)!
 mismatch := translate('precision highp float;uniform vec2 a;void main(){gl_FragColor=vec4(a,0.0,1.0);}',.fragment)!
 link(vertex,mismatch) or { assert err.msg().contains('Uniform mismatch'); return }
 assert false
}

fn test_invalid_uniform_declarations_are_rejected() {
 for source in ['uniform void a;', 'uniform float a[0];','uniform float a[4097];','uniform float a[];', 'uniform float a[1+1];', 'uniform float a=1.0;', 'uniform float a,a;', 'uniform float a;attribute vec2 a;', 'attribute vec2 a;uniform float a;', 'uniform vec4 gl_value;', 'uniform mat4 huge[4096];', 'uniform uint x;', 'uniform mat2x3 x;'] {
  translate(source+'void main(){gl_Position=vec4(1.0);}',.vertex) or { continue }
  assert false,source
 }
}
