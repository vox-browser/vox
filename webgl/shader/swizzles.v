// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module shader

fn is_vector_type(typ string) bool {
 for prefix in ['vec','ivec','uvec','bvec'] {
  if typ.len==prefix.len+1 && typ.starts_with(prefix) && typ[typ.len-1]>=`2` && typ[typ.len-1]<=`4` {return true}
 }
 return false
}

fn is_matrix_type(typ string) bool {
 if !typ.starts_with('mat') {return false}
 metal_type(typ) or {return false}
 return true
}

struct VectorSwizzle {
 selector string
 unique bool
}

fn vector_swizzle(typ string, member string) !VectorSwizzle {
 if !is_vector_type(typ) || member.len<1 || member.len>4 {return error('Invalid vector swizzle')}
 width:=int(typ[typ.len-1]-`0`)
 mut alphabet:=''
 for letters in ['xyzw','rgba','stpq'] {if letters.contains(member[..1]) {alphabet=letters;break}}
 if alphabet=='' {return error('Invalid vector swizzle selector: '+member)}
 mut canonical:=[]u8{}
 mut seen:=u32(0)
 mut unique:=true
 for c in member {
  index:=alphabet.index_u8(c)
  if index<0 || index>=width {return error('Mixed or out-of-range vector swizzle: '+member)}
  bit:=u32(1)<<u32(index)
  if seen&bit!=0 {unique=false}
  seen|=bit
  canonical << 'xyzw'[index]
 }
 return VectorSwizzle{selector:canonical.bytestr(),unique:unique}
}
