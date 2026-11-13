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
 blocks []UniformBlock
 fields []Uniform
 definition ShaderStruct
 named bool
 row_major bool
 default_only bool
 end int
}

fn block_uniform_at(tokens []string, start int) ?int {
 mut at:=start
 if tokens[at]=='layout' {
  if at+1>=tokens.len || tokens[at+1]!='(' {return none}
  at=matching_token(tokens,at+1) or {return none}
  at++
 }
 if at>=tokens.len || tokens[at]!='uniform' {return none}
 if at+1<tokens.len && tokens[at+1]==';' {return at}
 if at+2<tokens.len && tokens[at+2]=='{' {return at}
 return none
}

fn uniform_block_declaration(tokens []string, start int, structures map[string]ShaderStruct, binding u32, default_row_major bool) !BlockDeclaration {
 uniform_at:=block_uniform_at(tokens,start) or {return error('Expected a uniform block')}
 mut row_major:=default_row_major
 if tokens[start]=='layout' {
  mut layout_seen:=''
  for word in tokens[start+2..uniform_at-1] {
   if word==',' {continue}
   if word in ['row_major','column_major'] {row_major=word=='row_major'}
   else if word in ['std140','shared','packed'] {
    if layout_seen!='' && layout_seen!=word {return error('Conflicting block layouts')}
    layout_seen=word
   } else {return error('Invalid ESSL uniform block layout: '+word)}
  }
 }
 if tokens[uniform_at+1]==';' {return BlockDeclaration{default_only:true,row_major:row_major,end:uniform_at+2}}
 name:=tokens[uniform_at+1]
 close:=matching_token(tokens,uniform_at+2)!
 mut at:=close+1
 instance:=if at<tokens.len && identifier(tokens[at]) {tokens[at]} else {''}
 if instance!='' {at++}
 mut count:=1
 mut is_array:=false
 if at<tokens.len && tokens[at]=='[' {
  end:=matching_token(tokens,at)!
  if instance=='' || end!=at+2 {return error('Uniform block array needs an instance and a constant size')}
  count=int(pp_integer(tokens[at+1])!);is_array=true;at=end+1
 }
 if count<1 || count>12 || binding+u32(count)>13 {return error('Uniform block binding limit exceeded')}
 if at>=tokens.len || tokens[at]!=';' {return error('Expected ; after uniform block')}
 mut structure_tokens:= ['struct',name,'{']
 structure_tokens << tokens[uniform_at+3..close]
 structure_tokens << ['}',';']
 definition:=structure_declaration(structure_tokens,0,structures,300)!.definition
 fields,size:=layout_block_fields(definition.fields,structures,row_major)!
 shaped:=ShaderStruct{...definition,fields:fields,size:size}
 mut blocks:=[]UniformBlock{}
 for element in 0..count {
  blocks << UniformBlock{name:name+if is_array {'[${element}]'} else {''},binding:binding+u32(element),byte_size:size,signature:definition.signature+':${row_major}:${is_array}:${count}'}
 }
 mut roots:=[]Uniform{}
 if instance!='' {
  roots << Uniform{name:name,access:instance,typ:name,offset:0,array_length:count,is_array:is_array,array_stride:if is_array {size} else {0},byte_size:size,scalar_type:0,binding:binding,signature:definition.signature,row_major:row_major,block_array:is_array}
 } else {for field in fields {roots << Uniform{...field,binding:binding}}}
 return BlockDeclaration{blocks:blocks,fields:roots,definition:shaped,named:instance!='',row_major:row_major,end:at+1}
}

fn layout_block_fields(fields []Uniform, structures map[string]ShaderStruct, row_major bool) !([]Uniform,int) {
 mut result:=[]Uniform{}
 mut size:=0
 for field in fields {
  major:=if field.matrix_order==0 {row_major} else {field.matrix_order==1}
  matrix:=field.columns>1
  mut element_size:=if matrix {16*if major {field.rows} else {field.columns}} else {field.rows*4}
  if field.scalar_type==0 {
   definition:=structures[field.typ] or {return error('Unknown block member type')}
   _,child_size:=layout_block_fields(definition.fields,structures,major)!
   element_size=child_size
  }
  alignment:=if field.scalar_type==0 || matrix || field.is_array || field.rows>=3 {16} else {field.rows*4}
  offset:=(size+alignment-1)/alignment*alignment
  stride:=if field.is_array {(element_size+15)/16*16} else {0}
  bytes:=if field.is_array {stride*field.array_length} else {element_size}
  result << Uniform{...field,offset:offset,byte_size:bytes,array_stride:stride,matrix_stride:if matrix {16} else {0},row_major:(matrix || field.scalar_type==0) && major}
  size=offset+bytes
  if size>65536 {return error('Uniform block exceeds 64 KiB')}
 }
 return result,(size+15)/16*16
}
