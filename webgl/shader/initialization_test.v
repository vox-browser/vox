module shader

fn compact_initialized(source string) string {return source.replace(' ','').replace('\n','')}

fn test_native_shader_initializes_scalars_globals_and_output_parameters() {
 source:='precision mediump float; float g; void helper(out vec4 x,inout vec4 y){vec4 local;y+=local;} void main(){vec4 a;vec4 b=vec4(1.0);helper(a,b);gl_FragColor=a+b+vec4(g);}'
 result:=compact_initialized(prepare_source(source,.fragment,2) or {panic(err)})
 assert result.starts_with('#version100')
 assert result.contains('floatg;')
 assert result.contains('g=float(0.0);')
 assert result.contains('helper(outvec4x,inoutvec4y){x=vec4(0.0);vec4local=vec4(0.0);')
 assert !result.contains('y=vec4(0.0)')
 assert result.contains('vec4a=vec4(0.0);vec4b=vec4(1.0);')
}

fn test_native_essl100_initializes_arrays_before_later_declarators() {
 source:='precision mediump float;float globals[2];struct S{float a[2];};void main(){float values[2],later=values[0];S object;gl_FragColor=vec4(later+object.a[1]+globals[0]);}'
 result:=compact_initialized(prepare_source(source,.fragment,2) or {panic(err)})
 assert !result.contains('float[2](')
 assert result.contains('for(int_webgl_zero_0=0;_webgl_zero_0<2;++_webgl_zero_0){globals[_webgl_zero_0]=float(0.0);}')
 assert result.contains('floatvalues[2];for(')
 assert result.index('values[_webgl_zero_1]=float(0.0);') or {0} < result.index('floatlater=values[0];') or {0}
 assert result.contains('object.a[_webgl_zero_2]=float(0.0);')
}

fn test_native_initializes_global_arrays_before_dependent_initializers() {
 source:='precision mediump float;uniform float input_value;float a[2];float first=a[0],second=first+input_value;void main(){gl_FragColor=vec4(second);}'
 result:=compact_initialized(prepare_source(source,.fragment,2) or {panic(err)})
 assert result.contains('floata[2];floatfirst,second;')
 assert result.contains('a[_webgl_zero_0]=float(0.0);')
 assert result.contains('first=a[0];second=first+input_value;')
 assert result.index('a[_webgl_zero_0]=float(0.0);') or {0} < result.index('first=a[0];') or {0}
}

fn test_global_initializer_rewrite_preserves_scope_and_restricted_expression_rules() {
 for declarations in [
  'float first=later;float later;',
  'float first=second,second=1.0;',
  'float self=self;',
  'attribute float input_value;float x=input_value;',
  'varying float input_value;float x=input_value;',
  'float x=gl_Position.x;',
  'float helper(){return 1.0;}float x=helper();',
  'uniform sampler2D image;vec4 x=texture2D(image,vec2(0.0));',
  'float x;float y=(x=1.0);',
  'float x;float y=x++;',
  'uniform vec4 input_value;const vec4 value=input_value;',
  'struct S{vec4 value;};uniform vec4 input_value;const S value=S(input_value);',
 ] {
  source:=declarations+'void main(){gl_Position=vec4(1.0);}'
  if _:=prepare_source(source,.vertex,2) {assert false,declarations}
  if _:=translate(source,.vertex) {assert false,declarations}
 }
 if _:=translate('uniform vec4 input_value;const vec4 value=input_value;void main(){gl_Position=value+input_value;}',.vertex) {assert false}
 source:='uniform float input_value;float first=input_value,second=sin(first);void main(){gl_Position=vec4(second);}'
 prepared:=compact_initialized(prepare_source(source,.vertex,2) or {panic(err)})
 assert prepared.contains('first=input_value;second=sin(first);')
 if _:=prepare_source('#version 300 es\n'+source,.vertex,3) {assert false}
 if _:=translate('#version 300 es\n'+source,.vertex) {assert false}
}

fn test_metal_rejects_initializer_shadow_binding_changes() {
 for source in [
  'float x=1.0;void main(){float x=x;gl_Position=vec4(x);}',
  '#version 300 es\nvec4 a[2];void main(){int index=gl_VertexID;vec4 a[4]=vec4[4](a[index],vec4(0.0),vec4(0.0),vec4(0.0));gl_Position=a[0];}',
 ] {
  if _:=translate(source,.vertex) {assert false}
 }
 // Native ESSL has the correct initializer scope and needs no restriction.
 assert prepare_source('float x=1.0;void main(){float x=x;gl_Position=vec4(x);}',.vertex,2) or {panic(err)} != ''
 source:='struct S{float value;};void main(){S object;float value=object.value;gl_Position=vec4(value);}'
 assert (translate(source,.vertex) or {panic(err)}).source!=''
}

fn test_metal_rejects_unparsed_native_declarations_and_initializes_globals_after_uniform_loads() {
 for declaration in ['float highp leaked;','float lowp leaked;','typedef float number;number leaked;','float4 leaked;'] {
  if _:=translate(declaration+'void main(){gl_Position=vec4(leaked);}',.vertex) {assert false,declaration}
 }
 translated:=translate('uniform float input_value;float first=input_value,second=first;void main(){gl_Position=vec4(second);}',.vertex) or {panic(err)}
 result:=compact_initialized(translated.source)
 assert result.contains('floatfirst={},second={};')
 assert result.contains('voidrun(){first=input_value;second=first;')
 assert !result.contains('floatfirst=input_value')
 assert translated.uniforms.any(it.name=='input_value')
 assert result.index('state.input_value=') or {0} < result.index('state.run();') or {0}
}

fn test_native_initializes_outputs_without_introducing_unused_fragment_builtins() {
 vertex:=compact_initialized(prepare_source('void main(){}',.vertex,2) or {panic(err)})
 assert vertex.contains('voidmain(){gl_Position=vec4(0.0);}')
 fragment:=compact_initialized(prepare_source('precision mediump float;void main(){gl_FragColor+=vec4(1.0);}',.fragment,2) or {panic(err)})
 assert fragment.contains('voidmain(){gl_FragColor=vec4(0.0);gl_FragColor+=vec4(1.0);}')
 empty:=prepare_source('precision mediump float;void main(){}',.fragment,2) or {panic(err)}
 assert !empty.contains('gl_FragColor')
 assert !empty.contains('gl_FragData')
 output:=compact_initialized(prepare_source('#version 300 es\nprecision mediump float;out vec4 color;void main(){color+=vec4(1.0);}',.fragment,3) or {panic(err)})
 assert output.contains('voidmain(){color=vec4(0.0);color+=vec4(1.0);}')
}

fn test_native_essl300_initializes_arrays_structures_and_unsigned_values() {
 source:='#version 300 es\nprecision highp float;struct S{uvec2 v;mat2 m;};out vec4 color;void main(){S items[2];uint index;float values[2];color=vec4(items[index].v,values[1],1.0);}'
 result:=compact_initialized(prepare_source(source,.fragment,3) or {panic(err)})
 assert result.starts_with('#version300es')
 assert result.contains('Sitems[2]=S[2](S(uvec2(0u),mat2(0.0)),S(uvec2(0u),mat2(0.0)));')
 assert result.contains('uintindex=uint(0u);')
 assert result.contains('floatvalues[2]=float[2](float(0.0),float(0.0));')
}

fn test_metal_initializes_local_and_global_aggregates_without_changing_explicit_values() {
 source:='#version 300 es\nprecision highp float;float global;float globals[2];struct S{vec4 v;};out vec4 color;void main(){vec4 local;S object;float values[2];float explicit_value=2.0;color=local+object.v+vec4(global+globals[0]+values[1]+explicit_value);}'
 translated:=translate(source,.fragment) or {panic(err)}
 result:=compact_initialized(translated.source)
 assert result.contains('floatglobal={};')
 assert result.contains('array<float,2>globals={};')
 assert result.contains('float4local={};')
 assert result.contains('_vox_Struct_Sobject={};')
 assert result.contains('array<float,2>values={};')
 assert result.contains('floatexplicit_value=2.0;')
}

fn test_native_preparation_copy_boundary_and_reserved_names() {
 source:='void main(){float x;gl_Position=vec4(x);}'
 required:=prepare_native(source.str,i32(source.len),0,2,unsafe {nil},0)
 assert required>0
 mut output:=[]u8{len:int(required)+1,init:255}
 assert prepare_native(source.str,i32(source.len),0,2,unsafe {&char(output.data)},required)==0
 assert output[0]==255
 assert prepare_native(source.str,i32(source.len),0,2,unsafe {&char(output.data)},required+1)==required
 assert output[int(required)]==0
 assert output[..int(required)].bytestr()==prepare_source(source,.vertex,2) or {panic(err)}
 for invalid in ['void main(){int _webgl_zero_0;gl_Position=vec4(1.0);}','void main(){int webgl_value;gl_Position=vec4(1.0);}'] {
  if _:=prepare_source(invalid,.vertex,2) {assert false}
  if _:=translate(invalid,.vertex) {assert false}
 }
}

fn test_link_rejects_mixed_original_essl_versions() {
 vertex:=translate('void main(){gl_Position=vec4(1.0);}',.vertex) or {panic(err)}
 fragment:=translate('#version 300 es\nprecision mediump float;out vec4 color;void main(){color=vec4(1.0);}',.fragment) or {panic(err)}
 if _:=link(vertex,fragment) {assert false}
}
