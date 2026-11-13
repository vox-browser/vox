module shader

fn test_matrix_and_flat_varying_linkage() {
 vertex := translate('#version 300 es\nout mat2x3 basis;flat out ivec2 value;void main(){gl_Position=vec4(1.0);}',.vertex)!
 fragment := translate('#version 300 es\nprecision highp float;in mat2x3 basis;flat in ivec2 value;out vec4 color;void main(){color=vec4(basis[0],1.0)+vec4(vec2(value),0.0,0.0);}',.fragment)!
 link(vertex,fragment)!
 assert vertex.source.contains('[[user(v_basis_1)]]')
 assert fragment.source.contains('[[user(v_value), flat]]')
 mismatch := translate('#version 300 es\nprecision highp float;flat in mat2x3 basis;out vec4 color;void main(){color=vec4(basis[0],1.0);}',.fragment)!
 link(vertex,mismatch) or { assert err.msg().contains('Varying mismatch'); return }
 assert false
}

fn test_invalid_interpolation_and_boolean_interfaces_are_rejected() {
 for declaration in ['out int number;', 'out uvec2 number;', 'out bool value;', 'flat in vec4 position;', 'flat uniform vec4 value;', 'smooth flat out vec4 value;'] {
  translate('#version 300 es\n'+declaration+'void main(){gl_Position=vec4(1.0);}',.vertex) or { continue }
  assert false,declaration
 }
 translate('flat varying vec4 value;void main(){gl_Position=vec4(1.0);}',.vertex) or { return }
 assert false
}
