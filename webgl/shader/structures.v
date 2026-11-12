// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module shader

struct ShaderStruct {
 name string
 fields []Uniform
 size int
 depth int
 signature string
}
struct StructDeclaration {
 definition ShaderStruct
 end int
}

fn structure_declaration(tokens []string, start int, structures map[string]ShaderStruct, version int) !StructDeclaration {
 if start+3 >= tokens.len || !identifier(tokens[start+1]) || tokens[start+2] != '{' { return error('Expected a named structure definition') }
 name := tokens[start+1]
 if name in structures || name.starts_with('gl_') || name.starts_with('_vox_') || name.starts_with('webgl_') || name.starts_with('_webgl_') || name.contains('sampler') { return error('Invalid or duplicate structure name') }
 if _ := metal_type(name) { return error('Structure name conflicts with a builtin type') }
 mut at := start+3
 mut fields := []Uniform{}
 mut size := 0
 mut depth := 1
 mut signature := []string{}
 for at < tokens.len && tokens[at] != '}' {
  // Reuse the uniform declarator parser for std140 field layout. Structure
  // members have no storage qualifier, so prepend it only to this token view.
  mut member_tokens := ['uniform']
  member_tokens << tokens[at..]
  declaration := uniform_declarations(member_tokens,0,size,version,structures)!
  for field in declaration.fields {
   if fields.any(it.name == field.name) { return error('Duplicate structure member: ${field.name}') }
   if child := structures[field.typ] { if child.depth+1 > depth { depth=child.depth+1 } }
   if depth > 16 { return error('Structure nesting limit exceeded') }
   fields << field
   signature << '${field.name}:${field.signature}'
  }
  size = declaration.size
  at += declaration.end-1
 }
 if fields.len == 0 || at+1 >= tokens.len || tokens[at] != '}' || tokens[at+1] != ';' { return error('Expected nonempty structure followed by ;') }
 return StructDeclaration{definition:ShaderStruct{name:name,fields:fields,size:(size+15)/16*16,depth:depth,signature:name+'{'+signature.join(';')+'}'},end:at+2}
}

fn structure_source(definitions []ShaderStruct) ![]string {
 mut result := []string{}
 for definition in definitions {
  result << 'struct _vox_Struct_${definition.name} {'
  for field in definition.fields {
   typ := if field.scalar_type == 0 {'_vox_Struct_'+field.typ} else {metal_type(field.typ)!}
   if field.is_array { result << 'array<${typ}, ${field.array_length}> ${field.name} = {};' }
   else { result << '${typ} ${field.name} = {};' }
  }
  result << '};'
 }
 return result
}

// Reflect leaf names using WebGL's member paths. Expand arrays of structures,
// retaining scalar/vector/matrix arrays as one reflected field with a stride.
fn flatten_uniforms(roots []Uniform, structures map[string]ShaderStruct, nesting int) ![]Uniform {
 if nesting > 16 { return error('Uniform nesting limit exceeded') }
 mut leaves := []Uniform{}
 for root in roots {
  if root.scalar_type != 0 { leaves << root; continue }
  definition := structures[root.typ] or { return error('Unknown uniform structure') }
  for element in 0..root.array_length {
   prefix := root.name+if root.is_array {'[${element}]'} else {''}
   mut children := []Uniform{}
   for field in definition.fields {
    children << Uniform{...field,name:prefix+'.'+field.name,offset:root.offset+element*root.array_stride+field.offset}
   }
   leaves << flatten_uniforms(children,structures,nesting+1)!
   if leaves.len > 4096 { return error('Uniform reflection field limit exceeded') }
  }
 }
 if leaves.len > 4096 { return error('Uniform reflection field limit exceeded') }
 return leaves
}
