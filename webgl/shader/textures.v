// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module shader

// Combined ESSL samplers use independent Metal texture/sampler namespaces.
// Plain uniforms keep buffer slot zero; textures never consume buffer bytes.
pub struct TextureResource {
pub:
 name string
 typ string
 binding int
 sampler_binding int
 kind int = 7
 image_dimension int
 image_arrayed bool
 image_depth bool
 array_length int = 1
 is_array bool
 image_scalar_type u32 = 13
}

struct TextureDeclarations {
 fields []TextureResource
 end int
}

fn sampler_type(typ string) !string {
 if typ !in sampler_types() {return error('Unsupported sampler type: '+typ)}
 return '_vox_'+typ
}
fn sampler_types() []string {
 return ['sampler2D','samplerCube','sampler3D','sampler2DArray','isampler2D','usampler2D','isampler3D','usampler3D','isamplerCube','usamplerCube','isampler2DArray','usampler2DArray','sampler2DShadow','samplerCubeShadow','sampler2DArrayShadow']
}
fn texture_slot_count(fields []TextureResource) int {
 mut count:=0
 for field in fields {count+=field.array_length}
 return count
}

fn texture_declarations(tokens []string, type_at int, base int) !TextureDeclarations {
 typ := tokens[type_at]
 sampler_type(typ)!
 mut at := type_at+1
 mut fields := []TextureResource{}
 for at < tokens.len {
  name := tokens[at]
  if !identifier(name) || name.starts_with('gl_') || name.starts_with('_vox_') || name.starts_with('webgl_') || name.starts_with('_webgl_') { return error('Invalid sampler name') }
  at++
  mut count:=1
  is_array:=at<tokens.len && tokens[at]=='['
  if is_array {
   end:=matching_token(tokens,at)!
   if end!=at+2 {return error('Sampler array requires a constant size')}
   count=int(pp_integer(tokens[at+1])!);at=end+1
  }
  slot:=base+texture_slot_count(fields)
  if count<1 || count>16 || slot+count>16 {return error('Sampler binding limit exceeded')}
  if at>=tokens.len || tokens[at] !in [',',';'] {return error('Invalid sampler declaration')}
  fields << TextureResource{name:name,typ:typ,binding:slot,sampler_binding:slot,array_length:count,is_array:is_array,image_dimension:if typ.contains('Cube') {3} else if typ.contains('3D') {2} else {1},image_arrayed:typ.contains('Array'),image_depth:typ.ends_with('Shadow'),image_scalar_type:if typ.starts_with('i') {u32(7)} else if typ.starts_with('u') {u32(8)} else {u32(13)}}
  if tokens[at] == ';' { return TextureDeclarations{fields:fields,end:at+1} }
  at++
 }
 return error('Unterminated sampler declaration')
}

fn texture_types() []string {
 mut result:=[]string{}
 for typ in sampler_types() {result << 'struct _vox_${typ} { ${metal_texture_type(typ)} image; sampler sampling; };'}
 return result
}

fn texture_methods(stage Stage, version int, used_types []string, legacy_lod bool) []string {
 mut methods := []string{}
 for typ in ['sampler2D','samplerCube'] {
  cube := typ == 'samplerCube'
  wrapper := if cube {'_vox_samplerCube'} else {'_vox_sampler2D'}
  coordinate := if cube {'float3'} else {'float2'}
  legacy := if cube {'textureCube'} else {'texture2D'}
  sample := if version == 100 {legacy} else {'texture'}
  lod := if version == 100 {legacy+'Lod'} else {'textureLod'}
  implicit_level := if stage == .vertex {', level(0.0)'} else {''}
  methods << 'float4 _vox_${sample}(${wrapper} s, ${coordinate} p) { return s.image.sample(s.sampling, p${implicit_level}); }'
  if stage == .fragment {
   methods << 'float4 _vox_${sample}(${wrapper} s, ${coordinate} p, float b) { return s.image.sample(s.sampling, p, bias(b)); }'
  }
  if stage == .vertex || version == 300 || legacy_lod {
   methods << 'float4 _vox_${lod}(${wrapper} s, ${coordinate} p, float l) { return s.image.sample(s.sampling, p, level(l)); }'
  }
  if version == 300 {
   gradient := if cube {'gradientcube'} else {'gradient2d'}
   methods << 'float4 _vox_textureGrad(${wrapper} s, ${coordinate} p, ${coordinate} dx, ${coordinate} dy) { return s.image.sample(s.sampling, p, ${gradient}(dx,dy)); }'
   methods << 'int2 _vox_textureSize(${wrapper} s, int l) { return int2(s.image.get_width(uint(l)),s.image.get_height(uint(l))); }'
  }
 }
 projected := if version == 100 {'texture2DProj'} else {'textureProj'}
 base := if version == 100 {'texture2D'} else {'texture'}
 lod := if version == 100 {'texture2DLod'} else {'textureLod'}
 projected_lod := if version == 100 {'texture2DProjLod'} else {'textureProjLod'}
 for coordinate in ['float3','float4'] {
  divisor := if coordinate == 'float3' {'z'} else {'w'}
  methods << 'float4 _vox_${projected}(_vox_sampler2D s, ${coordinate} p) { return _vox_${base}(s, p.xy/p.${divisor}); }'
  if stage == .fragment { methods << 'float4 _vox_${projected}(_vox_sampler2D s, ${coordinate} p, float b) { return _vox_${base}(s, p.xy/p.${divisor}, b); }' }
  if stage == .vertex || version == 300 || legacy_lod { methods << 'float4 _vox_${projected_lod}(_vox_sampler2D s, ${coordinate} p, float l) { return _vox_${lod}(s, p.xy/p.${divisor}, l); }' }
 }
 if version == 300 {
  methods << 'float4 _vox_texelFetch(_vox_sampler2D s, int2 p, int l) { return s.image.read(uint2(p),uint(l)); }'
 }
 if version==300 {methods << extended_texture_methods(stage,used_types);methods << shadow_texture_methods(stage,used_types);methods << offset_texture_methods(stage,used_types)}
 if version==100 && legacy_lod {methods << legacy_lod_methods()}
 return methods
}

fn texture_call(name string, version int) bool {
 return if version == 100 {
  name in ['texture2D','textureCube','texture2DProj','texture2DLod','textureCubeLod','texture2DProjLod','texture2DLodEXT','textureCubeLodEXT','texture2DProjLodEXT','texture2DGradEXT','textureCubeGradEXT','texture2DProjGradEXT']
 } else {
  name in ['texture','textureLod','textureProj','textureProjLod','textureGrad','textureSize','texelFetch','textureProjGrad','textureOffset','textureLodOffset','textureGradOffset','texelFetchOffset','textureProjOffset','textureProjLodOffset','textureProjGradOffset']
 }
}

fn texture_constructor(fields []TextureResource) !string {
 mut parameters := []string{}
 mut initializers := []string{}
 mut index:=0
 for field in fields {
  mut elements:=[]string{}
  for _ in 0..field.array_length {
   parameters << '${sampler_type(field.typ)!} _vox_arg${index}'
   elements << '_vox_arg${index}';index++
  }
  initializers << if field.is_array {'${field.name}{{${elements.join(', ')}}}'} else {'${field.name}(${elements[0]})'}
 }
 return 'VoxState(${parameters.join(', ')}) : ${initializers.join(', ')} {}'
}

fn texture_arguments(fields []TextureResource) []string {
 mut args := []string{}
 for field in fields {
  typ := metal_texture_type(field.typ)
  for element in 0..field.array_length {
   slot:=field.binding+element
   args << '${typ} _vox_image${slot} [[texture(${slot})]]'
   args << 'sampler _vox_sampling${slot} [[sampler(${field.sampler_binding+element})]]'
  }
 }
 return args
}

fn texture_state(fields []TextureResource) !string {
 if fields.len == 0 { return 'VoxState state;' }
 mut args := []string{}
 for field in fields {for element in 0..field.array_length {slot:=field.binding+element;args << '${sampler_type(field.typ)!}{_vox_image${slot},_vox_sampling${slot}}'}}
 return 'VoxState state(${args.join(', ')});'
}

fn metal_texture_type(typ string) string {
 shape:=if typ.contains('Cube') {'cube'} else if typ.contains('3D') {'3d'} else if typ.contains('Array') {'2d_array'} else {'2d'}
 scalar:=if typ.starts_with('i') {'int'} else if typ.starts_with('u') {'uint'} else {'float'}
 return (if typ.ends_with('Shadow') {'depth'} else {'texture'})+shape+'<'+scalar+'>'
}

fn extended_texture_methods(stage Stage, used_types []string) []string {
 mut methods := ['uint _vox_array_layer(float layer, uint count) { return uint(clamp(int(floor(layer+0.5)),0,int(count)-1)); }']
 implicit := if stage==.vertex {', level(0.0)'} else {''}
 for typ in sampler_types() {
  if typ in ['sampler2D','samplerCube'] || typ.ends_with('Shadow') {continue}
  if typ !in used_types {continue}
  wrapper:=sampler_type(typ) or {continue}
  arrayed:=typ.contains('Array')
  volume:=typ.contains('3D')
  cube:=typ.contains('Cube')
  coordinate:=if volume || arrayed || cube {'float3'} else {'float2'}
  dimension:=if volume || arrayed {'int3'} else {'int2'}
  result:=if typ.starts_with('i') {'int4'} else if typ.starts_with('u') {'uint4'} else {'float4'}
  sample_coordinates:=if arrayed {'p.xy, _vox_array_layer(p.z,s.image.get_array_size())'} else {'p'}
  methods << '${result} _vox_texture(${wrapper} s, ${coordinate} p) { return s.image.sample(s.sampling,${sample_coordinates}${implicit}); }'
  methods << '${result} _vox_textureLod(${wrapper} s, ${coordinate} p, float l) { return s.image.sample(s.sampling,${sample_coordinates},level(l)); }'
  if stage==.fragment {methods << '${result} _vox_texture(${wrapper} s, ${coordinate} p, float b) { return s.image.sample(s.sampling,${sample_coordinates},bias(b)); }'}
  gradient_coordinate:=if volume || cube {'float3'} else {'float2'}
  gradient:=if volume {'gradient3d'} else if cube {'gradientcube'} else {'gradient2d'}
  methods << '${result} _vox_textureGrad(${wrapper} s, ${coordinate} p, ${gradient_coordinate} dx, ${gradient_coordinate} dy) {return s.image.sample(s.sampling,${sample_coordinates},${gradient}(dx,dy));}'
  size_tail:=if volume {',s.image.get_depth(uint(l))'} else if arrayed {',s.image.get_array_size()'} else {''}
  methods << '${dimension} _vox_textureSize(${wrapper} s, int l) {return ${dimension}(s.image.get_width(uint(l)),s.image.get_height(uint(l))${size_tail});}'
  fetch_coordinates:=if volume {'uint3(p)'} else if arrayed {'uint2(p.xy),uint(p.z)'} else {'uint2(p)'}
  if !cube {methods << '${result} _vox_texelFetch(${wrapper} s, ${dimension} p, int l) {return s.image.read(${fetch_coordinates},uint(l));}'}
 }
 return methods
}

fn legacy_lod_methods() []string {
 mut methods:=[
  'float4 _vox_texture2DLodEXT(_vox_sampler2D s,float2 p,float l) {return _vox_texture2DLod(s,p,l);}',
  'float4 _vox_textureCubeLodEXT(_vox_samplerCube s,float3 p,float l) {return _vox_textureCubeLod(s,p,l);}',
  'float4 _vox_texture2DGradEXT(_vox_sampler2D s,float2 p,float2 dx,float2 dy) {return s.image.sample(s.sampling,p,gradient2d(dx,dy));}',
  'float4 _vox_textureCubeGradEXT(_vox_samplerCube s,float3 p,float3 dx,float3 dy) {return s.image.sample(s.sampling,p,gradientcube(dx,dy));}',
 ]
 for typ in ['float3','float4'] {
  divisor:=if typ=='float3' {'z'} else {'w'}
  methods << 'float4 _vox_texture2DProjLodEXT(_vox_sampler2D s,${typ} p,float l) {return _vox_texture2DProjLod(s,p,l);}'
  // GLSL ES 3.2 textureProjGrad: derivatives are already projected.
  // https://registry.khronos.org/OpenGL/specs/es/3.2/GLSL_ES_Specification_3.20.html
  methods << 'float4 _vox_texture2DProjGradEXT(_vox_sampler2D s,${typ} p,float2 dx,float2 dy) {return _vox_texture2DGradEXT(s,p.xy/p.${divisor},dx,dy);}'
 }
 return methods
}

fn shadow_texture_methods(stage Stage, used []string) []string {
 mut result:=[]string{}
 for typ in ['sampler2DShadow','samplerCubeShadow','sampler2DArrayShadow'] {
  if typ !in used {continue}
  wrapper:=sampler_type(typ) or {continue}
  cube:=typ.contains('Cube');arrayed:=typ.contains('Array')
  coordinate:=if cube || arrayed {'float4'} else {'float3'}
  arguments:=if cube {'p.xyz,p.w'} else if arrayed {'p.xy,_vox_array_layer(p.z,s.image.get_array_size()),p.w'} else {'p.xy,p.z'}
  implicit:=if stage==.vertex {',level(0.0)'} else {''}
  result << 'float _vox_texture(${wrapper} s,${coordinate} p){return s.image.sample_compare(s.sampling,${arguments}${implicit});}'

  if !cube && !arrayed {

   result << 'float _vox_textureProj(${wrapper} s,float4 p){return _vox_texture(s,p.xyz/p.w);}'

  }
  if stage==.fragment && !arrayed {result << 'float _vox_texture(${wrapper} s,${coordinate} p,float b){return s.image.sample_compare(s.sampling,${arguments},bias(b));}'}
  derivative:=if cube {'float3'} else {'float2'}
  gradient:=if cube {'gradientcube'} else {'gradient2d'}
  result << 'float _vox_textureGrad(${wrapper} s,${coordinate} p,${derivative} dx,${derivative} dy){return s.image.sample_compare(s.sampling,${arguments},${gradient}(dx,dy));}'
  if !cube && !arrayed {
   result << 'float _vox_textureLod(${wrapper} s,float3 p,float l){return s.image.sample_compare(s.sampling,p.xy,p.z,level(l));}'
   result << 'float _vox_textureProjLod(${wrapper} s,float4 p,float l){return _vox_textureLod(s,p.xyz/p.w,l);}'
   result << 'float _vox_textureProjGrad(${wrapper} s,float4 p,float2 dx,float2 dy){return _vox_textureGrad(s,p.xyz/p.w,dx,dy);}'
   if stage==.fragment {result << 'float _vox_textureProj(${wrapper} s,float4 p,float b){return _vox_texture(s,p.xyz/p.w,b);}'}
  }
  size_type:=if arrayed {'int3'} else {'int2'}
  size_tail:=if arrayed {',s.image.get_array_size()'} else {''}
  result << '${size_type} _vox_textureSize(${wrapper} s,int l){return ${size_type}(s.image.get_width(uint(l)),s.image.get_height(uint(l))${size_tail});}'
 }
 return result
}

fn offset_texture_methods(stage Stage,used []string) []string {
 mut result:=[]string{}
 for typ in sampler_types() {
  if typ !in used || typ.contains('Cube') {continue}
  wrapper:=sampler_type(typ) or {continue}
  shadow:=typ.ends_with('Shadow');volume:=typ.contains('3D');arrayed:=typ.contains('Array')
  spatial:=if volume {'3'} else {'2'}
  coordinate:=if shadow {if arrayed {'float4'} else {'float3'}} else if volume || arrayed {'float3'} else {'float2'}
  pixel:=if volume || arrayed {'int3'} else {'int2'}
  value:=if shadow {'float'} else if typ.starts_with('i') {'int4'} else if typ.starts_with('u') {'uint4'} else {'float4'}
  sample_args:=if shadow {if arrayed {'p.xy,_vox_array_layer(p.z,s.image.get_array_size()),p.w'} else {'p.xy,p.z'}} else if arrayed {'p.xy,_vox_array_layer(p.z,s.image.get_array_size())'} else {'p'}
  call:=if shadow {'sample_compare'} else {'sample'}
  implicit:=if stage==.vertex {',level(0.0)'} else {''}
  result << '${value} _vox_textureOffset(${wrapper} s,${coordinate} p,int${spatial} o){return s.image.${call}(s.sampling,${sample_args}${implicit},o);}'
  if stage==.fragment && (!shadow || !arrayed) {result << '${value} _vox_textureOffset(${wrapper} s,${coordinate} p,int${spatial} o,float b){return s.image.${call}(s.sampling,${sample_args},bias(b),o);}'}
  if !shadow || !arrayed {result << '${value} _vox_textureLodOffset(${wrapper} s,${coordinate} p,float l,int${spatial} o){return s.image.${call}(s.sampling,${sample_args},level(l),o);}'}
  result << '${value} _vox_textureGradOffset(${wrapper} s,${coordinate} p,float${spatial} dx,float${spatial} dy,int${spatial} o){return s.image.${call}(s.sampling,${sample_args},gradient${spatial}d(dx,dy),o);}'
  if !shadow {
   fetch:=if arrayed {'uint2(p.xy+o),uint(p.z)'} else {'uint${spatial}(p+o)'}
   result << '${value} _vox_texelFetchOffset(${wrapper} s,${pixel} p,int l,int${spatial} o){return s.image.read(${fetch},uint(l));}'
  }
  if !arrayed {
   projected_types:=if volume || shadow {['float4']} else {['float3','float4']}
   for projected in projected_types {
    divisor:=if projected=='float3' {'z'} else {'w'}
    projection:=if volume {'p.xyz/p.w'} else if shadow {'p.xyz/p.w'} else {'p.xy/p.'+divisor}
    if typ!='sampler2D' && !shadow {
     result << '${value} _vox_textureProj(${wrapper} s,${projected} p){return _vox_texture(s,${projection});}'
     result << '${value} _vox_textureProjLod(${wrapper} s,${projected} p,float l){return _vox_textureLod(s,${projection},l);}'
     if stage==.fragment {result << '${value} _vox_textureProj(${wrapper} s,${projected} p,float b){return _vox_texture(s,${projection},b);}'}
    }
    if !shadow {result << '${value} _vox_textureProjGrad(${wrapper} s,${projected} p,float${spatial} dx,float${spatial} dy){return _vox_textureGrad(s,${projection},dx,dy);}'}
    result << '${value} _vox_textureProjOffset(${wrapper} s,${projected} p,int${spatial} o){return _vox_textureOffset(s,${projection},o);}'
    result << '${value} _vox_textureProjLodOffset(${wrapper} s,${projected} p,float l,int${spatial} o){return _vox_textureLodOffset(s,${projection},l,o);}'
    result << '${value} _vox_textureProjGradOffset(${wrapper} s,${projected} p,float${spatial} dx,float${spatial} dy,int${spatial} o){return _vox_textureGradOffset(s,${projection},dx,dy,o);}'
   }
  }
 }
 return result
}
