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
 image_scalar_type u32 = 13
}

struct TextureDeclarations {
 fields []TextureResource
 end int
}

fn sampler_type(typ string) !string {
 return match typ {
  'sampler2D' {'_vox_Sampler2D'}
  'samplerCube' {'_vox_SamplerCube'}
  'sampler3D' {'_vox_Sampler3D'}
  'sampler2DArray' {'_vox_Sampler2DArray'}
  'isampler2D' {'_vox_ISampler2D'}
  'usampler2D' {'_vox_USampler2D'}
  else {return error('Unsupported sampler type: ${typ}')}
 }
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
  if at >= tokens.len || tokens[at] !in [',',';'] { return error('Unsupported sampler declarator (arrays are pending)') }
  if base+fields.len >= 16 { return error('Sampler binding limit exceeded') }
  fields << TextureResource{name:name,typ:typ,binding:base+fields.len,sampler_binding:base+fields.len,image_dimension:if typ == 'samplerCube' {3} else if typ == 'sampler3D' {2} else {1},image_arrayed:typ=='sampler2DArray',image_scalar_type:if typ=='isampler2D' {u32(7)} else if typ=='usampler2D' {u32(8)} else {u32(13)}}
  if tokens[at] == ';' { return TextureDeclarations{fields:fields,end:at+1} }
  at++
 }
 return error('Unterminated sampler declaration')
}

fn texture_types() []string {
 return [
  'struct _vox_Sampler2D { texture2d<float> image; sampler sampling; };',
  'struct _vox_SamplerCube { texturecube<float> image; sampler sampling; };',
  'struct _vox_Sampler3D { texture3d<float> image; sampler sampling; };',
  'struct _vox_Sampler2DArray { texture2d_array<float> image; sampler sampling; };',
  'struct _vox_ISampler2D { texture2d<int> image; sampler sampling; };',
  'struct _vox_USampler2D { texture2d<uint> image; sampler sampling; };',
 ]
}

fn texture_methods(stage Stage, version int, used_types []string, legacy_lod bool) []string {
 mut methods := []string{}
 for typ in ['sampler2D','samplerCube'] {
  cube := typ == 'samplerCube'
  wrapper := if cube {'_vox_SamplerCube'} else {'_vox_Sampler2D'}
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
  methods << 'float4 _vox_${projected}(_vox_Sampler2D s, ${coordinate} p) { return _vox_${base}(s, p.xy/p.${divisor}); }'
  if stage == .fragment { methods << 'float4 _vox_${projected}(_vox_Sampler2D s, ${coordinate} p, float b) { return _vox_${base}(s, p.xy/p.${divisor}, b); }' }
  if stage == .vertex || version == 300 || legacy_lod { methods << 'float4 _vox_${projected_lod}(_vox_Sampler2D s, ${coordinate} p, float l) { return _vox_${lod}(s, p.xy/p.${divisor}, l); }' }
 }
 if version == 300 {
  methods << 'float4 _vox_texelFetch(_vox_Sampler2D s, int2 p, int l) { return s.image.read(uint2(p),uint(l)); }'
 }
 if version==300 {methods << extended_texture_methods(stage,used_types)}
 if version==100 && legacy_lod {methods << legacy_lod_methods()}
 return methods
}

fn texture_call(name string, version int) bool {
 return if version == 100 {
  name in ['texture2D','textureCube','texture2DProj','texture2DLod','textureCubeLod','texture2DProjLod','texture2DLodEXT','textureCubeLodEXT','texture2DProjLodEXT','texture2DGradEXT','textureCubeGradEXT','texture2DProjGradEXT']
 } else {
  name in ['texture','textureLod','textureProj','textureProjLod','textureGrad','textureSize','texelFetch']
 }
}

fn texture_constructor(fields []TextureResource) !string {
 mut parameters := []string{}
 mut initializers := []string{}
 for i,field in fields {
  parameters << '${sampler_type(field.typ)!} _vox_arg${i}'
  initializers << '${field.name}(_vox_arg${i})'
 }
 return 'VoxState(${parameters.join(', ')}) : ${initializers.join(', ')} {}'
}

fn texture_arguments(fields []TextureResource) []string {
 mut args := []string{}
 for field in fields {
  typ := metal_texture_type(field.typ)
  args << '${typ} _vox_image${field.binding} [[texture(${field.binding})]]'
  args << 'sampler _vox_sampling${field.binding} [[sampler(${field.sampler_binding})]]'
 }
 return args
}

fn texture_state(fields []TextureResource) !string {
 if fields.len == 0 { return 'VoxState state;' }
 mut args := []string{}
 for field in fields { args << '${sampler_type(field.typ)!}{_vox_image${field.binding},_vox_sampling${field.binding}}' }
 return 'VoxState state(${args.join(', ')});'
}

fn metal_texture_type(typ string) string {
 return match typ {
  'sampler2D' {'texture2d<float>'}
  'samplerCube' {'texturecube<float>'}
  'sampler3D' {'texture3d<float>'}
  'sampler2DArray' {'texture2d_array<float>'}
  'isampler2D' {'texture2d<int>'}
  else {'texture2d<uint>'}
 }
}

fn extended_texture_methods(stage Stage, used_types []string) []string {
 mut methods := ['uint _vox_array_layer(float layer, uint count) { return uint(clamp(int(floor(layer+0.5)),0,int(count)-1)); }']
 implicit := if stage==.vertex {', level(0.0)'} else {''}
 for typ in ['sampler3D','sampler2DArray','isampler2D','usampler2D'] {
  if typ !in used_types {continue}
  wrapper:=sampler_type(typ) or {continue}
  arrayed:=wrapper=='_vox_Sampler2DArray'
  volume:=wrapper=='_vox_Sampler3D'
  coordinate:=if volume || arrayed {'float3'} else {'float2'}
  dimension:=if volume || arrayed {'int3'} else {'int2'}
  result:=if wrapper=='_vox_ISampler2D' {'int4'} else if wrapper=='_vox_USampler2D' {'uint4'} else {'float4'}
  sample_coordinates:=if arrayed {'p.xy, _vox_array_layer(p.z,s.image.get_array_size())'} else {'p'}
  methods << '${result} _vox_texture(${wrapper} s, ${coordinate} p) { return s.image.sample(s.sampling,${sample_coordinates}${implicit}); }'
  methods << '${result} _vox_textureLod(${wrapper} s, ${coordinate} p, float l) { return s.image.sample(s.sampling,${sample_coordinates},level(l)); }'
  if stage==.fragment {methods << '${result} _vox_texture(${wrapper} s, ${coordinate} p, float b) { return s.image.sample(s.sampling,${sample_coordinates},bias(b)); }'}
  gradient_coordinate:=if volume {'float3'} else {'float2'}
  gradient:=if volume {'gradient3d'} else {'gradient2d'}
  methods << '${result} _vox_textureGrad(${wrapper} s, ${coordinate} p, ${gradient_coordinate} dx, ${gradient_coordinate} dy) {return s.image.sample(s.sampling,${sample_coordinates},${gradient}(dx,dy));}'
  size_tail:=if volume {',s.image.get_depth(uint(l))'} else if arrayed {',s.image.get_array_size()'} else {''}
  methods << '${dimension} _vox_textureSize(${wrapper} s, int l) {return ${dimension}(s.image.get_width(uint(l)),s.image.get_height(uint(l))${size_tail});}'
  fetch_coordinates:=if volume {'uint3(p)'} else if arrayed {'uint2(p.xy),uint(p.z)'} else {'uint2(p)'}
  methods << '${result} _vox_texelFetch(${wrapper} s, ${dimension} p, int l) {return s.image.read(${fetch_coordinates},uint(l));}'
 }
 return methods
}

fn legacy_lod_methods() []string {
 mut methods:=[
  'float4 _vox_texture2DLodEXT(_vox_Sampler2D s,float2 p,float l) {return _vox_texture2DLod(s,p,l);}',
  'float4 _vox_textureCubeLodEXT(_vox_SamplerCube s,float3 p,float l) {return _vox_textureCubeLod(s,p,l);}',
  'float4 _vox_texture2DGradEXT(_vox_Sampler2D s,float2 p,float2 dx,float2 dy) {return s.image.sample(s.sampling,p,gradient2d(dx,dy));}',
  'float4 _vox_textureCubeGradEXT(_vox_SamplerCube s,float3 p,float3 dx,float3 dy) {return s.image.sample(s.sampling,p,gradientcube(dx,dy));}',
 ]
 for typ in ['float3','float4'] {
  divisor:=if typ=='float3' {'z'} else {'w'}
  methods << 'float4 _vox_texture2DProjLodEXT(_vox_Sampler2D s,${typ} p,float l) {return _vox_texture2DProjLod(s,p,l);}'
  // GLSL ES 3.2 textureProjGrad: derivatives are already projected.
  // https://registry.khronos.org/OpenGL/specs/es/3.2/GLSL_ES_Specification_3.20.html
  methods << 'float4 _vox_texture2DProjGradEXT(_vox_Sampler2D s,${typ} p,float2 dx,float2 dy) {return _vox_texture2DGradEXT(s,p.xy/p.${divisor},dx,dy);}'
 }
 return methods
}
