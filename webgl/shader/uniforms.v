// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module shader

// One stage's plain uniforms share Metal buffer slot zero. Offsets and strides
// follow std140, allowing the existing WebGL uniform writer to pack values.
pub struct Uniform {
pub:
 name string
 typ string
 offset int
 rows int
 columns int
 array_length int
 is_array bool
 array_stride int
 matrix_stride int
 byte_size int
 scalar_type u32
 semantic_type u32
 binding u32
 signature string
}

struct UniformDeclarations {
 fields []Uniform
 end int
 size int
}

fn uniform_declarations(tokens []string, start int, base int, version int, structures map[string]ShaderStruct) !UniformDeclarations {
 mut at := start+1
 if at < tokens.len && tokens[at] in ['lowp','mediump','highp'] { at++ }
 if at >= tokens.len { return error('Missing uniform type') }
 typ := tokens[at]
 if typ !in structures { metal_type(typ)! }
 if typ == 'void' || (typ !in structures && version == 100 && (typ == 'uint' || typ.starts_with('uvec') || typ.contains('x'))) { return error('Invalid uniform type for ESSL version') }
 at++
 structure := structures[typ] or { ShaderStruct{} }
 mut rows := if typ in structures {0} else {1}
 mut columns := 1
 if typ !in structures && typ.starts_with('mat') {
  columns = int(typ[3]-`0`)
  rows = if typ.len == 6 {int(typ[5]-`0`)} else {columns}
 } else if typ !in structures && typ.contains('vec') { rows = int(typ[typ.len-1]-`0`) }
 boolean := typ == 'bool' || typ.starts_with('bvec')
 scalar_type := if typ in structures {u32(0)} else if boolean || typ == 'uint' || typ.starts_with('uvec') {u32(8)} else if typ == 'int' || typ.starts_with('ivec') {u32(7)} else {u32(13)}
 mut fields := []Uniform{}
 mut size := base
 for at < tokens.len {
  name := tokens[at]
  if !identifier(name) || name.starts_with('gl_') || name.starts_with('_vox_') || name.starts_with('webgl_') || name.starts_with('_webgl_') { return error('Invalid uniform name') }
  at++
  mut array_length := 1
  is_array := at < tokens.len && tokens[at] == '['
  if is_array {
   at++
   if at+1 >= tokens.len || tokens[at+1] != ']' { return error('Uniform array requires a literal length') }
   count := pp_integer(tokens[at])!
   if count < 1 || count > 4096 { return error('Uniform array length out of range') }
   array_length = int(count)
   at += 2
  }
  if at >= tokens.len || tokens[at] !in [',',';'] { return error('Invalid uniform declarator') }
  alignment := if typ in structures || columns > 1 || is_array || rows >= 3 {16} else {rows*4}
  matrix_stride := if columns > 1 {16} else {0}
  element_size := if typ in structures {structure.size} else if columns > 1 {columns*16} else {rows*4}
  array_stride := if is_array {(element_size+15)/16*16} else {0}
  byte_size := if is_array {array_stride*array_length} else {element_size}
  offset := (size+alignment-1)/alignment*alignment
  if offset+byte_size > 65536 { return error('Plain uniform buffer exceeds 64 KiB') }
  fields << Uniform{name:name,typ:typ,offset:offset,rows:rows,columns:columns,array_length:array_length,is_array:is_array,array_stride:array_stride,matrix_stride:matrix_stride,byte_size:byte_size,scalar_type:scalar_type,semantic_type:if boolean {u32(2)} else {u32(0)},signature:if typ in structures {structure.signature+'[${is_array}:${array_length}]'} else {'${typ}[${is_array}:${array_length}]'}}
  size = offset+byte_size
  if tokens[at] == ';' { return UniformDeclarations{fields:fields,end:at+1,size:size} }
  at++
 }
 return error('Unterminated uniform declaration')
}

fn uniform_members(fields []Uniform) ![]string {
 mut result := []string{}
 for field in fields {
  typ := if field.scalar_type == 0 {'_vox_Struct_'+field.typ} else {metal_type(field.typ)!}
  if field.is_array { result << 'array<${typ}, ${field.array_length}> ${field.name} = {};' }
  else if field.scalar_type == 0 { result << '${typ} ${field.name} = {};' }
  else { result << '${typ} ${field.name} = ${typ}(0);' }
 }
 return result
}

// Decode storage scalars explicitly. MSL's float3 size and bool size differ
// from std140; casting a raw buffer to a user struct would corrupt those fields.
fn uniform_loads(fields []Uniform) ![]string {
 mut result := []string{}
 for field in fields {
  if field.is_array { result << 'for (uint _vox_element=0; _vox_element<${field.array_length}; ++_vox_element) {' }
  element_offset := if field.is_array {' + _vox_element * ${field.array_stride}'} else {''}
  destination := 'state.${field.name}'+if field.is_array {'[_vox_element]'} else {''}
  storage := match field.scalar_type {7 {'int'} 8 {'uint'} else {'float'}}
  for column in 0..field.columns {
   mut scalars := []string{}
   for row in 0..field.rows {
    offset := field.offset+column*field.matrix_stride+row*4
    load := '(*reinterpret_cast<constant ${storage}*>(_vox_uniform_bytes + ${offset}${element_offset}))'
    scalars << if field.semantic_type == 2 {'(${load} != 0u)'} else {load}
   }
   value_type := if field.columns > 1 {'float${field.rows}'} else {metal_type(field.typ)!}
   target := destination+if field.columns > 1 {'[${column}]'} else {''}
   result << '${target} = ${value_type}(${scalars.join(', ')});'
  }
  if field.is_array { result << '}' }
 }
 return result
}
