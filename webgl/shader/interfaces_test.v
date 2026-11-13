module shader

fn test_explicit_locations_override_api_bindings_and_automatic_spans_avoid_both() {
 result := translate_with_bindings('#version 300 es\n#define BASE 2\nlayout(location=(BASE+1)) in mat3 transform;in vec4 shade;in vec4 extra;void main(){gl_Position=shade+extra+vec4(transform[0],0.0);}',.vertex,{'transform':9,'extra':0})!
 assert result.inputs.map(it.location) == [3,1,0]
 assert result.inputs[0].columns == 3 && result.inputs[0].rows == 3
 assert result.inputs[0].explicit_location
 assert !result.inputs[1].explicit_location
 assert result.source.contains('[[attribute(5)]]')
}

fn test_automatic_matrices_require_contiguous_free_locations() {
 result := translate_with_bindings('#version 300 es\nin mat4 transform;in vec4 shade;void main(){gl_Position=transform*shade;}',.vertex,{'shade':2})!
 assert result.inputs.map(it.location) == [3,2]
 bound := translate_with_bindings('attribute mat2 basis;void main(){gl_Position=vec4(basis[0],0.0,1.0);}',.vertex,{'basis':14})!
 assert bound.inputs[0].location == 14 && bound.inputs[0].columns == 2
}

fn test_invalid_and_overlapping_locations_fail() {
 for source in [
  'layout(location=3) in mat4 a;layout(location=5) in vec4 b;',
  'layout(location=13) in mat4 a;',
  'layout(location=-1) in vec4 a;',
  'layout(location=16) in vec4 a;',
  'layout(location=UNKNOWN) in vec4 a;',
  'layout(location=1/0) in vec4 a;',
  'layout(location=0) out vec4 a;',
  'layout(binding=0) in vec4 a;',
  'layout(location=0,index=0) in vec4 a;',
  'layout(location=0) uniform vec4 a;',
 ] {
  translate('#version 300 es\n'+source+'void main(){gl_Position=vec4(a[0])+vec4(b);}',.vertex) or { continue }
  assert false,source
 }
 for bindings in [{'a':15},{'a':2,'b':3},{'a':-1},{'a':16},{'gl_bad':1}] {
  translate_with_bindings('#version 300 es\nin mat2 a;in vec4 b;void main(){gl_Position=vec4(a[0],0.0,1.0)+b;}',.vertex,bindings) or { continue }
  assert false,'Invalid binding accepted'
 }
 translate('layout(location=0) attribute vec4 a;void main(){gl_Position=a;}',.vertex) or { return }
 assert false
}

fn test_fragment_output_locations_are_reserved_before_automatic_outputs() {
 fragment := translate('#version 300 es\nprecision mediump float;out vec4 automatic;layout(location=0) out vec4 explicit_value;void main(){automatic=vec4(0.0);explicit_value=vec4(1.0);}',.fragment)!
 assert fragment.outputs.map(it.location) == [1,0]
 for declaration in ['layout(location=8) out vec4 color;','layout(location=1) in vec4 color;', 'out mat2 color;', 'out bool color;'] {
  translate('#version 300 es\nprecision mediump float;'+declaration+'void main(){}',.fragment) or { continue }
  assert false,declaration
 }
}

fn test_api_binding_cannot_overlap_an_explicit_matrix_span() {
 source := '#version 300 es\nlayout(location=3) in mat3 transform;in vec4 shade;void main(){gl_Position=shade+vec4(transform[0],0.0);}'
 translate_with_bindings(source,.vertex,{'shade':4}) or {
  assert err.msg().contains('overlap')
  return
 }
 assert false
}
