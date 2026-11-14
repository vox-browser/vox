module shader

fn bounded_shader_source(source string) !string {
 translated:=translate('#version 300 es\n'+source,.vertex)!
 return translated.source.replace(' ','').replace('\n','').replace('\t','')
}

fn test_dynamic_uniform_block_and_plain_global_arrays_are_confined() {
 block:=bounded_shader_source('uniform Data{vec4 values[4];};uniform int index;void main(){gl_Position=values[index];}')!
 assert block.contains('values[_webgl_safe_index(index,4)]')
 global:=bounded_shader_source('float values[3];void main(){int index=gl_VertexID;values[index]=1.0;gl_Position=vec4(values[index]);}')!
 assert global.count('values[_webgl_safe_index(index,3)]')==2
 assert !global.contains('values[index]')
}

fn test_nested_structure_array_vector_and_matrix_extents_are_preserved() {
 source:=bounded_shader_source('struct Inner{vec4 lanes[2];};struct Outer{Inner nested[3];mat2x3 basis;};uniform Outer state[4];uniform int a,b,c;void main(){gl_Position=state[a].nested[b].lanes[c];gl_Position[0]+=state[a].basis[b][c];}')!
 assert source.contains('state[_webgl_safe_index(a,4)].nested[_webgl_safe_index(b,3)].lanes[_webgl_safe_index(c,2)]')
 assert source.contains('state[_webgl_safe_index(a,4)].basis[_webgl_safe_index(b,2)][_webgl_safe_index(c,3)]')
 parameter:=bounded_shader_source('float sample(float values[3],int index){return values[index];}void main(){float values[3];gl_Position=vec4(sample(values,gl_VertexID));}')!
 assert parameter.contains('returnvalues[_webgl_safe_index(index,3)]')
}

fn test_unbraced_control_declarations_cannot_change_later_array_bounds() {
 source:=bounded_shader_source('uniform float values[2];void main(){int index=gl_VertexID;if(true)float values[4];else gl_Position=vec4(values[index]);while(false)float values[5];do float values[6];while(false);for(int i=0;i<0;i++)float values[7];gl_Position=vec4(values[index]);}')!
 assert source.count('values[_webgl_safe_index(index,2)]')==2
 for count in [4,5,6,7] {assert !source.contains('values[_webgl_safe_index(index,'+count.str()+')]')}
 nested:=bounded_shader_source('uniform float values[2];void main(){int index=gl_VertexID;{float values[4];gl_Position=vec4(values[index]);}gl_Position+=vec4(values[index]);}')!
 assert nested.contains('values[_webgl_safe_index(index,4)]')
 assert nested.contains('values[_webgl_safe_index(index,2)]')
}

fn test_index_clamps_preserve_signedness_and_evaluate_side_effects_once() {
 source:=bounded_shader_source('void main(){vec4 value=vec4(1.0);int negative=-5;uint huge=4294967295u;value[negative++]=value[huge];gl_Position=value;}')!
 assert source.contains('value[_webgl_safe_index((negative++),4)]')
 assert source.contains('value[_webgl_safe_index(huge,4)]')
 assert source.count('negative++')==1
 // The unsigned overload clamps before narrowing, so UINT_MAX selects the
 // final element instead of becoming a negative signed index.
 assert source.contains('int_webgl_safe_index(uinti,intn){returnint(metal::min(i,uint(n-1)));}')
 assert source.contains('int_webgl_safe_index(inti,intn){returnmetal::clamp(i,0,n-1);}')
}

fn test_user_overloads_cannot_replace_the_bounds_helpers_builtins() {
 source:=bounded_shader_source('int clamp(int value,int low,int high){return value;}uint min(uint value,uint high){return value;}void main(){vec4 value=vec4(1.0);int i=gl_VertexID;uint u=uint(i);gl_Position=vec4(value[i]+value[u]);}')!
 assert source.contains('returnmetal::clamp(i,0,n-1)')
 assert source.contains('returnint(metal::min(i,uint(n-1)))')
 assert source.contains('value[_webgl_safe_index(i,4)]')
 assert source.contains('value[_webgl_safe_index(u,4)]')
}

fn test_array_comma_and_loop_initializers_cannot_bypass_bounds_lowering() {
 source:=bounded_shader_source('void main(){vec4 value=vec4(1.0);int index=gl_VertexID;float values[2]=float[2](value[index],value[index++]);float first=value[index],second=value[index];for(int i=int(value[index]),j=int(value[index]);i<2;i++,j++){values[i]=first+second;}gl_Position=vec4(values[(index++,index)]);}')!
 assert source.contains('value[_webgl_safe_index(index,4)]')
 assert source.contains('value[_webgl_safe_index((index++),4)]')
 assert source.count('value[_webgl_safe_index(index,4)]')==5
 assert source.contains('values[_webgl_safe_index(i,2)]')
 assert source.count('index++')==2
 assert !source.contains('value[index]')
 assert !source.contains('values[index]')
}

fn test_constant_out_of_range_and_unknown_shape_indices_fail_closed() {
 for body in [
  'vec4 value=vec4(1.0);gl_Position=vec4(value[-1]);',
  'vec4 value=vec4(1.0);gl_Position=vec4(value[4]);',
  'vec4 value=vec4(1.0);gl_Position=vec4(value[4294967295u]);',
  'float value=1.0;gl_Position=vec4(value[0]);',
  'gl_Position=vec4(unknown[0]);',
  'gl_Position=vec4(unknown()[gl_VertexID]);',
  'vec4 value=vec4(1.0);float data[1]=float[1](value[4]);gl_Position=vec4(data[0]);',
 ] {
  bounded_shader_source('void main(){'+body+'}') or {continue}
  assert false,body
 }
}

fn test_unhandled_subscript_syntax_and_forged_helper_names_are_rejected() {
 for source in [
  'void main(){int values[2];switch(gl_VertexID){case values[0]:break;}gl_Position=vec4(1.0);}',
  'int _webgl_safe_index(int i,int n){return i;}void main(){vec4 value=vec4(1.0);gl_Position=vec4(value[gl_VertexID]);}',
 ] {
  bounded_shader_source(source) or {continue}
  assert false,source
 }
}

fn test_essl100_constant_loop_indices_remain_valid_after_bounds_lowering() {
 result:=translate('precision highp float;uniform vec4 values[2];void main(){gl_FragColor=vec4(0.0);for(int i=0;i<2;i++){gl_FragColor+=values[i];}}',.fragment)!
 assert result.source.contains('_webgl_safe_index ( i , 2 )')
 translate('precision highp float;uniform vec4 values[2];void main(){int i=1;gl_FragColor=values[i];}',.fragment) or {return}
 assert false
}
