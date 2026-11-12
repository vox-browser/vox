module shader

import math

#flag darwin -framework Foundation -framework Metal
#flag darwin -fobjc-arc
#flag darwin @VMODROOT/webgl/shader/compiler_probe_darwin.m

#include "@DIR/compiler_probe.h"

fn C.vox_direct_metal_probe(&char, &char) int

fn test_v_generated_metal_renders_exact_pixels_without_shader_libraries() {
	vertex := translate('#version 300 es\nout vec4 value;void main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0.0,1.0);value=vec4(1.0,0.0,0.0,1.0);}', .vertex)!
	fragment := translate('#version 300 es\nprecision highp float;in vec4 value;out vec4 color;void main(){color=value;}', .fragment)!
	link(vertex, fragment)!
	assert C.vox_direct_metal_probe(vertex.source.str, fragment.source.str) == 1
}

fn test_preprocessed_v_shaders_render_exact_pixels_without_shader_libraries() {
 vertex := translate('#version 300 es\n#define POS gl_Position\n#define V4(x,y,z,w) vec4(x,y,z,w)\n#if __VERSION__ == 300\nout vec4 value;void main(){POS=V4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0.0,1.0);value=V4(1.0,0.0,0.0,1.0);}\n#else\ndouble invalid;\n#endif',.vertex)!
 fragment := translate('#version 300 es\n#if GL_ES && defined(GL_FRAGMENT_PRECISION_HIGH)\nprecision highp float;\n#endif\nin vec4 value;out vec4 color;\n#define SET(x) color=x\nvoid main(){SET(value);}',.fragment)!
 link(vertex,fragment)!
 assert C.vox_direct_metal_probe(vertex.source.str,fragment.source.str) == 1
}

fn C.vox_direct_metal_uniform_probe(&char, &char, voidptr, u64, voidptr, u64) int

fn test_std140_uniforms_render_exact_pixels_with_both_stages_bound() {
 vertex := translate('#version 300 es\nuniform mat4 transform;out vec4 value;void main(){gl_Position=transform*vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0.0,1.0);value=vec4(1.0);}',.vertex)!
 fragment := translate('#version 300 es\nprecision highp float;uniform vec3 tint;uniform float strength;uniform bool enabled;uniform vec4 colors[2];uniform mat2x3 basis;uniform ivec2 indices;uniform uvec2 tags;uniform bool switches[2];in vec4 value;out vec4 color;void main(){color=enabled && switches[1] && indices.x == -7 && tags.y == 4000000000u && basis[0].y == 2.0 && basis[1].z == 6.0 ? vec4(tint*strength,1.0)*colors[1]*value : vec4(0.0,1.0,0.0,1.0);}',.fragment)!
 link(vertex,fragment)!
 assert vertex.uniform_buffer_size == 64
 assert fragment.uniforms.map(it.offset) == [0,12,16,32,64,96,104,112]
 assert fragment.uniform_buffer_size == 144
 // Raw std140 bytes deliberately use independent, fixed offsets. Padding is
 // poisoned so decoding natural MSL float3/bool/array layouts cannot pass.
 transform := [f32(1),0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1]
 mut words := []u32{len:36,init:0xffffffff}
 for i, value in [f32(1),0,0,1] { words[i]=math.f32_bits(value) }
 words[4]=1
 for i, value in [f32(0),1,0,1, 1,1,1,1] { words[8+i]=math.f32_bits(value) }
 for i, value in [f32(1),2,3] { words[16+i]=math.f32_bits(value) }
 for i, value in [f32(4),5,6] { words[20+i]=math.f32_bits(value) }
 words[24]=u32(i32(-7)); words[25]=9
 words[26]=0; words[27]=4000000000
 words[28]=0; words[32]=1
 assert C.vox_direct_metal_uniform_probe(vertex.source.str,fragment.source.str,transform.data,64,words.data,144)==1
 // Change a consumed field: the endpoint requires red, so this must fail.
 words[4]=0
 assert C.vox_direct_metal_uniform_probe(vertex.source.str,fragment.source.str,transform.data,64,words.data,144)==0
}

fn C.vox_direct_metal_texture_probe(&char, &char, int, u32) int

fn test_direct_metal_texture_calls_read_supplied_texels_and_mip_levels() {
 vertex_source := '#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0.0,1.0);}'
 vertex := translate(vertex_source,.vertex)!
 for expression in ['texture(texture,vec2(0.25))', 'texture(texture,vec2(0.25),0.0)', 'textureProj(texture,vec3(0.5,0.5,2.0))', 'textureProj(texture,vec4(0.5,0.5,0.0,2.0))', 'textureLod(texture,vec2(0.25),0.0)', 'textureGrad(texture,vec2(0.25),vec2(0.0),vec2(0.0))', 'texelFetch(texture,ivec2(0),0)'] {
  fragment := translate('#version 300 es\nprecision highp float;uniform sampler2D texture;out vec4 color;void main(){color='+expression+';}',.fragment)!
  link(vertex,fragment)!
  assert C.vox_direct_metal_texture_probe(vertex.source.str,fragment.source.str,1,0xff0000ff)==1,expression
  assert C.vox_direct_metal_texture_probe(vertex.source.str,fragment.source.str,1,0xff00ff00)==0,expression
 }
 mip := translate('#version 300 es\nprecision highp float;uniform sampler2D textureLod;out vec4 color;void main(){color=textureSize(textureLod,1).x==1 && textureLod(textureLod,vec2(0.25),1.0).g==1.0 ? vec4(1.0,0.0,0.0,1.0) : vec4(0.0,1.0,0.0,1.0);}',.fragment)!
 assert C.vox_direct_metal_texture_probe(vertex.source.str,mip.source.str,1,0xff0000ff)==1
 cube := translate('#version 300 es\nprecision highp float;uniform samplerCube sky;out vec4 color;void main(){color=texture(sky,vec3(1.0,0.0,0.0));}',.fragment)!
 assert C.vox_direct_metal_texture_probe(vertex.source.str,cube.source.str,2,0xff0000ff)==1
 assert C.vox_direct_metal_texture_probe(vertex.source.str,cube.source.str,2,0xff00ff00)==0
}

fn test_legacy_sampler_names_overloads_macros_and_vertex_sampling_on_metal() {
 modern := translate('#version 300 es\nuniform sampler2D image;out vec4 value;void main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0.0,1.0);value=textureLod(image,vec2(0.25),0.0);}',.vertex)!
 fragment := translate('#version 300 es\nprecision highp float;in vec4 value;out vec4 color;void main(){color=value;}',.fragment)!
 assert C.vox_direct_metal_texture_probe(modern.source.str,fragment.source.str,1,0xff0000ff)==1
 // ESSL100 lacks vertex IDs. Pair its generated fragment MSL with the
 // existing procedural ES300 vertex MSL for this native rendering check.
 position := translate('#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0.0,1.0);}',.vertex)!
 for name in ['texture','texture2D','textureProj','textureLod'] {
  named := translate('precision mediump float;uniform sampler2D '+name+';void main(){gl_FragColor=texture2D('+name+',vec2(0.25));}',.fragment)!
  assert C.vox_direct_metal_texture_probe(position.source.str,named.source.str,1,0xff0000ff)==1,name
 }
 for expression in ['texture2D(texture,vec2(0.25))', 'texture2DProj(texture,vec3(0.5,0.5,2.0))', 'texture2D(texture,vec2(0.25))*texture2D(1.0)'] {
  legacy_fragment := translate('precision mediump float;uniform sampler2D texture;float texture2D(float x){return x;}\n#define SAMPLE(s,p) '+expression+'\nvoid main(){gl_FragColor=SAMPLE(texture,vec2(0.25));}',.fragment)!
  assert C.vox_direct_metal_texture_probe(position.source.str,legacy_fragment.source.str,1,0xff0000ff)==1
 }
}

fn test_nested_struct_uniforms_use_reflected_bytes_on_the_gpu() {
 vertex := translate('#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0.0,1.0);}',.vertex)!
 fragment := translate('#version 300 es\nprecision highp float;struct Shade{vec3 tint;float strength;bool enabled;};struct Light{Shade shade;mat2 basis;};uniform Light lights[2];out vec4 color;void main(){color=lights[0].shade.enabled && !lights[1].shade.enabled && lights[0].basis[0].y==2.0 && lights[1].basis[1].y==8.0 ? vec4(lights[0].shade.tint*lights[0].shade.strength+lights[1].shade.tint,1.0) : vec4(0.0,1.0,0.0,1.0);}',.fragment)!
 link(vertex,fragment)!
 assert fragment.uniform_buffer_size == 128
 mut words := []u32{len:32,init:0xffffffff}
 for i,value in [f32(1),0,0,1] { words[i]=math.f32_bits(value) }
 words[4]=1
 words[8]=math.f32_bits(f32(1)); words[9]=math.f32_bits(f32(2))
 words[12]=math.f32_bits(f32(3)); words[13]=math.f32_bits(f32(4))
 for i in 16..20 { words[i]=0 }
 words[20]=0
 words[24]=math.f32_bits(f32(5)); words[25]=math.f32_bits(f32(6))
 words[28]=math.f32_bits(f32(7)); words[29]=math.f32_bits(f32(8))
 assert C.vox_direct_metal_uniform_probe(vertex.source.str,fragment.source.str,unsafe{nil},0,words.data,128)==1
 words[4]=0
 assert C.vox_direct_metal_uniform_probe(vertex.source.str,fragment.source.str,unsafe{nil},0,words.data,128)==0
}

fn test_nested_structure_and_matrix_arrays_decode_on_the_gpu() {
 vertex := translate('#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0.0,1.0);}',.vertex)!
 fragment := translate('#version 300 es\nprecision highp float;struct matrix{vec2 values[2];};struct Box{matrix layers[2];mat2 transforms[2];};uniform Box cluster;out vec4 color;void main(){color=cluster.layers[1].values[1].y==6.0 && cluster.transforms[1][1].x==7.0 ? vec4(1.0,0.0,0.0,1.0) : vec4(0.0,1.0,0.0,1.0);}',.fragment)!
 link(vertex,fragment)!
 assert fragment.uniform_buffer_size == 128
 assert fragment.uniforms.map(it.offset)==[0,32,64]
 mut words := []u32{len:32,init:0xffffffff}
 words[13]=math.f32_bits(f32(6))
 words[28]=math.f32_bits(f32(7))
 assert C.vox_direct_metal_uniform_probe(vertex.source.str,fragment.source.str,unsafe{nil},0,words.data,128)==1
 words[28]=math.f32_bits(f32(8))
 assert C.vox_direct_metal_uniform_probe(vertex.source.str,fragment.source.str,unsafe{nil},0,words.data,128)==0
}

fn C.vox_direct_metal_attribute_probe(&char, &char, u32, u32, u32, voidptr, u64) int

fn test_api_bound_and_explicit_matrix_attributes_read_each_column_on_the_gpu() {
 fragment := translate('#version 300 es\nprecision highp float;in vec4 value;layout(location=0) out vec4 color;void main(){color=value;}',.fragment)!
 for qualifier in ['', 'layout(location=3) '] {
  vertex := translate_with_bindings('#version 300 es\n'+qualifier+'in mat4 transform;out vec4 value;void main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0.0,1.0);value=transform[0].y==2.0 && transform[1].x==5.0 && transform[2].w==12.0 && transform[3].z==15.0 ? vec4(1.0,0.0,0.0,1.0) : vec4(0.0,1.0,0.0,1.0);}',.vertex,{'transform':4})!
  link(vertex,fragment)!
  location := if qualifier.len > 0 {u32(3)} else {u32(4)}
  assert vertex.inputs[0].location == int(location)
  mut values := [f32(1),2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]
  assert C.vox_direct_metal_attribute_probe(vertex.source.str,fragment.source.str,location,4,4,values.data,64)==1
  values[14]=0
  assert C.vox_direct_metal_attribute_probe(vertex.source.str,fragment.source.str,location,4,4,values.data,64)==0
 }
 squareless := translate_with_bindings('#version 300 es\nin mat2x3 basis;out vec4 value;void main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0.0,1.0);value=basis[0].z==3.0 && basis[1].y==5.0 ? vec4(1.0,0.0,0.0,1.0) : vec4(0.0,1.0,0.0,1.0);}',.vertex,{'basis':7})!
 link(squareless,fragment)!
 values := [f32(1),2,3,-100,4,5,6,-100]
 assert C.vox_direct_metal_attribute_probe(squareless.source.str,fragment.source.str,7,3,2,values.data,32)==1
}

fn C.vox_direct_metal_feedback_probe(&char,u32,u32,u32,u32,u32,&u32,u64) int

fn test_v_generated_feedback_preserves_ids_matrix_bits_and_original_clip_position() {
 vertex := translate('#version 300 es\nout vec3 value;out mat2 matrix;flat out int signed_value;flat out uint unsigned_value;void main(){value=vec3(float(gl_VertexID),float(gl_InstanceID),7.0);matrix[0]=vec2(1.0,2.0);matrix[1]=vec2(3.0,4.0);signed_value=-7;unsigned_value=4000000000u;gl_Position=vec4(1.0,2.0,3.0,4.0);}',.vertex)!
 assert vertex.feedback_stride==52
 assert vertex.feedback_fields.map(it.offset)==[0,12,28,32,36]
 // Four records, with canaries beyond the output range. A nonzero Metal base
 // instance must not leak into WebGL's zero-based gl_InstanceID.
 mut words := []u32{len:56,init:0xdeadbeef}
 assert C.vox_direct_metal_feedback_probe(vertex.feedback_source.str,2,2,3,2,52,words.data,56)==1
 for record in 0..4 {
  base := record*13
  assert words[base]==math.f32_bits(f32(2+record%2))
  assert words[base+1]==math.f32_bits(f32(record/2))
  assert words[base+2]==math.f32_bits(f32(7))
  for i in 0..4 { assert words[base+3+i]==math.f32_bits(f32(i+1)) }
  assert words[base+7]==u32(i32(-7))
  assert words[base+8]==u32(4000000000)
  for i in 0..4 { assert words[base+9+i]==math.f32_bits(f32(i+1)) }
 }
 for i in 52..56 { assert words[i]==u32(0xdeadbeef) }
 // An undersized capacity must suppress the whole capture without touching
 // the allocation. This also checks multiplication guards before indexing.
 for i in 0..words.len { words[i]=0xdeadbeef }
 assert C.vox_direct_metal_feedback_probe(vertex.feedback_source.str,2,2,3,2,51,words.data,56)==1
 assert words.all(it==u32(0xdeadbeef))
}

fn test_regular_rendering_reconstructs_matrix_and_flat_integer_varyings() {
 vertex := translate('#version 300 es\nout mat2x3 basis;flat out ivec2 signed_value;flat out uint unsigned_value;void main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0.0,1.0);basis[0]=vec3(1.0,2.0,3.0);basis[1]=vec3(4.0,5.0,6.0);signed_value=ivec2(-7,9);unsigned_value=4000000000u;}',.vertex)!
 fragment := translate('#version 300 es\nprecision highp float;in mat2x3 basis;flat in ivec2 signed_value;flat in uint unsigned_value;out vec4 color;void main(){color=basis[0].z==3.0 && basis[1].y==5.0 && signed_value.x==-7 && unsigned_value==4000000000u ? vec4(1.0,0.0,0.0,1.0) : vec4(0.0,1.0,0.0,1.0);}',.fragment)!
 link(vertex,fragment)!
 assert C.vox_direct_metal_probe(vertex.source.str,fragment.source.str)==1
}

fn C.vox_direct_metal_compile_probe(&char) int

fn test_shared_essl_acceptance_corpus_through_v_translation_and_metal_compilation() {
 for case in acceptance_cases() {
  translated:=translate(case.source,if case.stage==0x8b31 {Stage.vertex} else {Stage.fragment}) or {
   assert !case.accepted,case.name+': '+err.msg()
   continue
  }
  accepted:=C.vox_direct_metal_compile_probe(translated.source.str)==1
  assert accepted==case.accepted,case.name
 }
}

fn test_legacy_derivative_extension_is_enforced_by_the_generated_overloads() {
 source:='precision highp float;void main(){gl_FragColor=vec4(dFdx(1.0));}'
 disabled:=translate(source,.fragment)!
 assert C.vox_direct_metal_compile_probe(disabled.source.str)==0
 enabled:=translate('#extension GL_OES_standard_derivatives : enable\n'+source,.fragment)!
 assert C.vox_direct_metal_compile_probe(enabled.source.str)==1
}

fn test_legacy_texture_lod_extension_enables_fragment_lod_and_gradient_sampling() {
 vertex:=translate('#version 300 es\nvoid main(){gl_Position=vec4(gl_VertexID==1?3.0:-1.0,gl_VertexID==2?3.0:-1.0,0.0,1.0);}',.vertex)!
 for expression in ['texture2DLodEXT(image,vec2(0.25),0.0)','texture2DProjLodEXT(image,vec3(0.5,0.5,2.0),0.0)','texture2DGradEXT(image,vec2(0.25),vec2(0.0),vec2(0.0))','texture2DProjGradEXT(image,vec4(0.5,0.5,0.0,2.0),vec2(0.0),vec2(0.0))'] {
  source:='precision highp float;uniform sampler2D image;void main(){gl_FragColor='+expression+';}'
  disabled:=translate(source,.fragment)!
  assert C.vox_direct_metal_compile_probe(disabled.source.str)==0,expression
  enabled:=translate('#extension GL_EXT_shader_texture_lod : require\n'+source,.fragment)!
  assert C.vox_direct_metal_texture_probe(vertex.source.str,enabled.source.str,1,0xff0000ff)==1,expression
 }
}
