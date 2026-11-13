// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module shader

struct FunctionParameter {
 name string
 typ string
 direction string = 'in'
 constant bool
 array_length int
}
struct ShaderFunction {
 name string
 typ string
 parameters []FunctionParameter
 start int
 header_end int
 body int
 end int
}

fn matching_token(tokens []string, start int) !int {
 if start<0 || start>=tokens.len || tokens[start] !in ['(', '[', '{'] {return error('Expected opening delimiter')}
 mut stack:=[]string{}
 for at in start..tokens.len {
  word:=tokens[at]
  if word in ['(', '[', '{'] {stack << word;if stack.len>128 {return error('Shader nesting limit exceeded')}}
  if word in [')', ']', '}'] {
   expected:=match word {')' {'('} ']' {'['} else {'{'}}
   if stack.len==0 || stack.last()!=expected {return error('Mismatched shader delimiter')}
   stack.delete_last()
   if stack.len==0 {return at}
  }
 }
 return error('Unterminated shader delimiter')
}

fn source_type(word string, structures map[string]bool) bool {
 if word in structures || word.contains('sampler') {return true}
 metal_type(word) or {return false}
 return true
}

fn shader_functions(tokens []string) ![]ShaderFunction {
 mut result:=[]ShaderFunction{}
 mut at:=0
 for at<tokens.len {
  if tokens[at]=='{' {at=matching_token(tokens,at)!+1;continue}
  if at+2<tokens.len && identifier(tokens[at]) && identifier(tokens[at+1]) && tokens[at+2]=='(' {
   end:=matching_token(tokens,at+2)!
   if end+1<tokens.len && tokens[end+1] in ['{',';'] {
    mut parameters:=[]FunctionParameter{}
    mut p:=at+3
    if p+1==end && tokens[p]=='void' {p++}
    for p<end {
     mut direction:='in'
     mut constant:=false
     if tokens[p]=='const' {constant=true;p++}
     if p<end && tokens[p] in ['in','out','inout'] {direction=tokens[p];p++}
     if p<end && tokens[p]=='const' {constant=true;p++}
     if constant && direction!='in' {return error('const function parameters must be inputs')}
     if p<end && tokens[p] in ['lowp','mediump','highp'] {p++}
     if p>=end {return error('Missing function parameter type')}
     typ:=tokens[p];p++
     name:=if p<end && identifier(tokens[p]) {tokens[p]} else {''}
     if name!='' {p++}
     mut count:=0
     if p<end && tokens[p]=='[' {
      close:=matching_token(tokens,p)!
      if close!=p+2 {return error('Function parameter array requires a constant size')}
      count=int(pp_integer(tokens[p+1])!)
      if count<1 || count>4096 {return error('Invalid function parameter array size')}
      p=close+1
     }
     parameters << FunctionParameter{name:name,typ:typ,direction:direction,array_length:count,constant:constant}
     if p<end {if tokens[p]!=',' {return error('Invalid function parameter')};p++}
    }
    body:=if tokens[end+1]=='{' {end+1} else {-1}
    finish:=if body>=0 {matching_token(tokens,body)!+1} else {end+2}
    if result.len>=1024 || parameters.len>256 {return error('Shader function capacity exceeded')}
    result << ShaderFunction{name:tokens[at+1],typ:tokens[at],parameters:parameters,start:at,header_end:end,body:body,end:finish}
    at=finish;continue
   }
  }
  at++
 }
 return result
}
