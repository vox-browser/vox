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

fn test_appendix_a_indices_and_loop_mutation_validate_lexical_bindings() {
 for body in ['for(int i=0;i<2;i++){i=1;}', 'for(int i=0;i<2;i++){++i;}', 'for(int i=0;i<2;i++){change(i);}', 'int n=1;vec4 x=values[n];'] {
  translate('precision highp float;uniform vec4 values[2];void change(inout int n){n++;}void main(){'+body+'gl_FragColor=vec4(1.0);}',.fragment) or {continue}
  assert false,body
 }
 translate('uniform vec4 values[2];void main(){for(int i=0;i<2;i++){gl_Position=values[i];}}',.vertex)!
 translate('void main(){for(int i=0;i<2;i++){{int i=0;i++;}gl_Position=vec4(1.0);}}',.vertex)!
 for source in ['uniform vec4 tint;void main(){tint.x=1.0;gl_Position=tint;}', 'attribute vec4 p;void main(){p++;gl_Position=p;}', 'uniform vec4 tint;void set(out vec4 v){v=vec4(1.0);}void main(){set(tint);gl_Position=tint;}'] {
  translate(source,.vertex) or {continue}
  assert false,source
 }
}

fn test_fragment_constant_loop_index_is_accepted() {
 translate('precision highp float;uniform vec4 values[2];void main(){gl_FragColor=vec4(0.0);for(int i=0;i<2;i++){gl_FragColor+=values[i];}}',.fragment)!
}

fn test_recursive_calls_and_const_input_mutation_are_rejected() {
 for source in ['float f(float x){return f(x);}void main(){gl_Position=vec4(f(1.0));}', 'float f(const in float x){x=2.0;return x;}void main(){gl_Position=vec4(f(1.0));}'] {
  translate(source,.vertex) or {continue}
  assert false,source
 }
}
