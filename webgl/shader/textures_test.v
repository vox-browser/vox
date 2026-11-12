module shader

fn test_sampler_reflection_separates_texture_slots_from_uniform_storage() {
 result := translate('#version 300 es\nuniform sampler2D image,second;uniform samplerCube sky;uniform vec4 tint;void main(){gl_Position=tint;}',.vertex)!
 assert result.textures.map(it.name) == ['image','second','sky']
 assert result.textures.map(it.binding) == [0,1,2]
 assert result.textures.map(it.sampler_binding) == [0,1,2]
 assert result.textures.all(it.kind == 7 && it.image_scalar_type == 13)
 assert result.textures.map(it.image_dimension) == [1,1,3]
 assert result.uniforms.len == 1 && result.uniforms[0].offset == 0
 assert result.uniform_buffer_size == 16
}

fn test_invalid_sampler_declarations_and_cross_stage_types() {
 for declaration in ['uniform sampler2D x[2];','uniform sampler2D x,x;', 'uniform sampler2D gl_bad;', 'uniform sampler3D x;', 'uniform sampler2DShadow x;', 'uniform isampler2D x;', 'uniform sampler2D x;uniform float x;', 'uniform float x;uniform sampler2D x;', 'attribute vec2 x;uniform sampler2D x;'] {
  translate(declaration+'void main(){gl_Position=vec4(1.0);}',.vertex) or { continue }
  assert false,declaration
 }
 vertex := translate('uniform sampler2D image;void main(){gl_Position=vec4(1.0);}',.vertex)!
 for declaration in ['uniform samplerCube image;','uniform float image;'] {
  fragment := translate('precision mediump float;'+declaration+'void main(){gl_FragColor=vec4(1.0);}',.fragment)!
  link(vertex,fragment) or { continue }
  assert false,declaration
 }
}

fn test_sampler_binding_limit_rejects_seventeenth_resource() {
 mut source := ''
 for i in 0..17 { source += 'uniform sampler2D image${i};' }
 translate(source+'void main(){gl_Position=vec4(1.0);}',.vertex) or {
  assert err.msg().contains('binding limit')
  return
 }
 assert false
}
