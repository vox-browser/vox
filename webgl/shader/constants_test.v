module shader

fn test_constant_array_bounds_include_operators_casts_builtins_and_scopes() {
 source:='#version 300 es\nconst int N=1+2, M=max(N,4);uniform vec4 values[(M<<1)-6];void main(){gl_Position=values[N-2];}'
 result:=translate(source,.vertex)!
 assert result.uniform_roots[0].array_length==2
 assert result.source.contains('values [ 1 ]')
 scoped:=normalize_constant_expressions(lex('const int N=3;float f(int N){return float(N);}void main(){const int N=2;float a[N];}{float b[N];}')!)!
 assert scoped.join(' ').contains('f ( int N ) { return float ( N ) ; }')
 assert scoped.join(' ').contains('a [ 2 ]')
 assert scoped.join(' ').contains('b [ 3 ]')
 for bound in ['0','-1','4097','unknown','1/0','true','2.0'] {
  translate('#version 300 es\nuniform vec4 values['+bound+'];void main(){gl_Position=values[0];}',.vertex) or {continue}
  assert false,bound
 }
}

fn test_integral_bounds_support_floating_constant_constructors_without_accepting_float_bounds() {
 result:=translate('#version 300 es\nconst float count=ceil(1.25)*2.0;uniform vec4 values[int(count)];void main(){gl_Position=values[0];}',.vertex)!
 assert result.uniform_roots[0].array_length==4
}
