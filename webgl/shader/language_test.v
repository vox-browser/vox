module shader

fn test_essl100_loop_bounds_are_checked_before_metal_lowering() {
 for source in ['uniform int n;void main(){for(int i=0;i<n;i++){}gl_Position=vec4(1.0);}', 'void main(){int x=1;gl_Position=vec4(float(x<<1));}', 'void main(){int x=1;gl_Position=vec4(float(x%2));}'] {
  translate(source,.vertex) or { continue }
  assert false,source
 }
 translate('const int limit=4;void main(){float value=0.0;for(int i=0;i<limit;i++){value+=1.0;}gl_Position=vec4(value);}',.vertex)!
 translate('void main(){float value=0.0;for(float i=0.0;i<4.0;i+=0.5){value+=1.0;}gl_Position=vec4(value);}',.vertex)!
}

fn test_builtin_limits_and_invariant_position_preserve_original_essl() {
 vertex:=translate('#version 300 es\ninvariant gl_Position;void main(){gl_Position=vec4(float(gl_MaxVaryingVectors));}',.vertex)!
 assert vertex.source.contains('float ( 16 )')
 assert acceptance_cases().len==40
}
