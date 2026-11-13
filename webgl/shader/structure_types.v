// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module shader

// Keep source member types available to expression checking independently of
// whether a structure is used as a uniform or an ordinary function value.
fn shader_structure_types(tokens []string,version int,functions []ShaderFunction) !map[string]ShaderStruct {
 mut result:=map[string]ShaderStruct{}
 mut at:=0
 mut ends:=map[int]int{}
 for function in functions {ends[function.start]=function.end}
 for at<tokens.len {
  if end:=ends[at] {at=end;continue}
  if tokens[at]=='struct' {
   declaration:=structure_declaration(tokens,at,result,version)!
   result[declaration.definition.name]=declaration.definition
   at=declaration.end;continue
  }
  if _:=block_uniform_at(tokens,at) {
   block:=uniform_block_declaration(tokens,at,result,1,false)!
   if !block.default_only {result[block.definition.name]=block.definition}
   at=block.end;continue
  }
  if tokens[at]=='{' {at=matching_token(tokens,at)!+1;continue}
  at++
 }
 return result
}
