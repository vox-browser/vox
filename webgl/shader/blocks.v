// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module shader

pub struct UniformBlock {
pub:
 name string
 binding u32
 byte_size int
 signature string
}
struct BlockDeclaration {
 block UniformBlock
 fields []Uniform
 end int
}

fn uniform_block_declaration(tokens []string, start int, structures map[string]ShaderStruct, binding u32) !BlockDeclaration {
 if start+7 >= tokens.len || tokens[start+1]!='(' || tokens[start+2]!='std140' || tokens[start+3]!=')' || tokens[start+4]!='uniform' || tokens[start+6]!='{' { return error('Expected layout(std140) uniform block') }
 mut declaration_tokens := ['struct']
 declaration_tokens << tokens[start+5..]
 declaration := structure_declaration(declaration_tokens,0,structures,300)!
 mut fields := []Uniform{}
 for field in declaration.definition.fields { fields << Uniform{...field,binding:binding} }
 return BlockDeclaration{block:UniformBlock{name:declaration.definition.name,binding:binding,byte_size:declaration.definition.size,signature:declaration.definition.signature},fields:fields,end:start+4+declaration.end}
}
