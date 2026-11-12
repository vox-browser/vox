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
  fields << TextureResource{name:name,typ:typ,binding:base+fields.len,sampler_binding:base+fields.len,image_dimension:if typ == 'sampler2D' {1} else {3}}
  if tokens[at] == ';' { return TextureDeclarations{fields:fields,end:at+1} }
  at++
 }
 return error('Unterminated sampler declaration')
}

fn texture_types() []string {
 return [
  'struct _vox_Sampler2D { texture2d<float> image; sampler sampling; };',
  'struct _vox_SamplerCube { texturecube<float> image; sampler sampling; };',
 ]
}

fn texture_methods(stage Stage, version int) []string {
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
  if stage == .vertex || version == 300 {
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
  if stage == .vertex || version == 300 { methods << 'float4 _vox_${projected_lod}(_vox_Sampler2D s, ${coordinate} p, float l) { return _vox_${lod}(s, p.xy/p.${divisor}, l); }' }
 }
 if version == 300 {
  methods << 'float4 _vox_texelFetch(_vox_Sampler2D s, int2 p, int l) { return s.image.read(uint2(p),uint(l)); }'
 }
 return methods
}

fn texture_call(name string, version int) bool {
 return if version == 100 {
  name in ['texture2D','textureCube','texture2DProj','texture2DLod','textureCubeLod','texture2DProjLod']
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
  typ := if field.typ == 'sampler2D' {'texture2d<float>'} else {'texturecube<float>'}
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
