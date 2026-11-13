module shader

fn test_essl_expression_types_reject_metal_implicit_conversions() {
 for body in ['float x=1;', 'float x=1.0;int y=2;x=y;', 'if(1){gl_Position=vec4(1.0);}', 'bool b=true;int x=b+1;', 'vec2 x=vec2(1.0);float y=x;'] {
  translate('#version 300 es\nvoid main(){'+body+'gl_Position=vec4(1.0);}',.vertex) or {continue}
  assert false,body
 }
 translate('#version 300 es\nvoid main(){float x=float(1);bool b=vec2(x)==vec2(1.0);gl_Position=vec4(b?1.0:0.0);}',.vertex)!
}

fn test_structure_members_keep_their_types_during_expression_validation() {
 translate('#version 300 es\nstruct State{vec4 color;float gain;};uniform State state;vec4 shade(vec4 x){return x;}void main(){gl_Position=shade(state.color)*state.gain;}',.vertex)!
 for expression in ['state.gain','state.unknown'] {
  translate('#version 300 es\nstruct State{vec4 color;float gain;};uniform State state;void main(){gl_Position='+expression+';}',.vertex) or {continue}
  assert false,expression
 }
}

fn test_vector_swizzles_validate_component_sets_bounds_and_write_uniqueness() {
 for member in ['s0','xr','z','xyzwx'] {
  translate('#version 300 es\nvoid main(){vec2 v=vec2(1.0);gl_Position=vec4(v.'+member+');}',.vertex) or {assert err.msg().contains('swizzle');continue}
  assert false,member
 }
 for body in ['v.xx=vec2(0.0);','paint(v.xx);','v.rr++;'] {
  translate('#version 300 es\nvoid paint(out vec2 x){x=vec2(0.0);}void main(){vec4 v=vec4(1.0);'+body+'gl_Position=v;}',.vertex) or {continue}
  assert false,body
 }
 translated:=translate('#version 300 es\nvoid main(){vec4 v=vec4(1.0);vec2 a=v.ss;v.st=a;gl_Position=v;}',.vertex)!
 assert !translated.source.contains('. st') && !translated.source.contains('. ss')
 translate('#version 300 es\nstruct myvec{vec4 st;};uniform myvec data;void main(){gl_Position=data.st;}',.vertex)!
}
