module shader

const shade_light = 'struct Shade{vec3 tint;float strength;bool enabled;};struct Light{Shade shade;mat2 basis;};'

fn test_nested_struct_uniforms_reflect_member_paths_and_std140_offsets() {
 result := translate('#version 300 es\n'+shade_light+'uniform Light lights[2];void main(){gl_Position=vec4(lights[0].shade.tint,1.0);}',.vertex)!
 assert result.uniform_buffer_size == 128
 assert result.uniform_roots.len == 1 && result.uniform_roots[0].array_stride == 64
 assert result.uniforms.map(it.name) == ['lights[0].shade.tint','lights[0].shade.strength','lights[0].shade.enabled','lights[0].basis','lights[1].shade.tint','lights[1].shade.strength','lights[1].shade.enabled','lights[1].basis']
 assert result.uniforms.map(it.offset) == [0,12,16,32,64,76,80,96]
 assert result.uniforms[2].scalar_type == 8 && result.uniforms[2].semantic_type == 2
 assert result.uniforms[3].matrix_stride == 16 && result.uniforms[3].columns == 2
}

fn test_struct_member_arrays_and_type_names_are_not_parsed_as_builtin_prefixes() {
 result := translate('struct matrix{float x;};struct Box{matrix entries[2];mat2 transforms[2];};uniform Box box;void main(){gl_Position=vec4(box.entries[0].x);}',.vertex)!
 assert result.uniform_buffer_size == 96
 assert result.uniforms.map(it.name) == ['box.entries[0].x','box.entries[1].x','box.transforms']
 assert result.uniforms.map(it.offset) == [0,16,32]
 assert result.uniforms[2].array_length == 2 && result.uniforms[2].array_stride == 32
}

fn test_struct_linking_compares_member_types_and_array_shapes() {
 vertex := translate(shade_light+'uniform Light lights[2];void main(){gl_Position=vec4(1.0);}',.vertex)!
 matching := translate('precision mediump float;'+shade_light+'uniform Light lights[2];void main(){gl_FragColor=vec4(1.0);}',.fragment)!
 link(vertex,matching)!
 for definition in [shade_light.replace('bool enabled','float enabled'),shade_light.replace('Shade shade','Shade shade[1]'),shade_light.replace('mat2 basis','mat3 basis'),shade_light.replace('float strength','float intensity')] {
  fragment := translate('precision mediump float;'+definition+'uniform Light lights[2];void main(){gl_FragColor=vec4(1.0);}',.fragment)!
  link(vertex,fragment) or { assert err.msg().contains('Uniform mismatch'); continue }
  assert false,definition
 }
}

fn test_malformed_or_unbounded_structure_declarations_fail() {
 for definition in ['struct Empty{};', 'struct Node{Node child;};','struct A{B child;};struct B{float x;};','struct A{float x;float x;};','struct A{sampler2D image;};','struct A{float x;}','struct A{float x;};struct A{float y;};','struct vec2{float x;};','struct A{float x;} instance;'] {
  translate(definition+'void main(){gl_Position=vec4(1.0);}',.vertex) or { continue }
  assert false,definition
 }
 mut deep := 'struct A0{float x;};'
 for i in 1..17 { deep += 'struct A${i}{A${i-1} child;};' }
 translate(deep+'void main(){gl_Position=vec4(1.0);}',.vertex) or { assert err.msg().contains('nesting limit'); return }
 assert false
}
