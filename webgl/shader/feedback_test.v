module shader

fn test_capture_reflection_is_tightly_packed_and_position_is_included() {
 vertex := translate('#version 300 es\nout vec3 value;out mat2 matrix;out int index;void main(){gl_Position=vec4(1.0);}',.vertex)!
 assert vertex.feedback_fields.map(it.name)==['value','matrix','index','gl_Position']
 assert vertex.feedback_fields.map(it.offset)==[0,12,28,32]
 assert vertex.feedback_stride==48
 assert vertex.feedback_fields[1].matrix_stride==8
 assert vertex.feedback_fields[2].scalar_type==7
 assert vertex.feedback_source.contains('vertex void vox_capture(')
 assert !vertex.feedback_source.contains('result.position.y =')
 assert vertex.feedback_source.contains('[[buffer(13)]]') && vertex.feedback_source.contains('[[buffer(14)]]')
 assert translate('void main(){gl_Position=vec4(1.0);}',.vertex)!.feedback_source.len==0
 assert translate('#version 300 es\nprecision highp float;out vec4 color;void main(){color=vec4(1.0);}',.fragment)!.feedback_source.len==0
}
