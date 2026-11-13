// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module shader

// ESSL restrictions that would be erased by lowering to MSL. Metal still checks
// emitted expression/function types; this does not establish full conformance.
fn validate_essl_language(tokens []string, version int) ! {
 if version != 100 { return }
 mut constants := map[string]bool{}
 for i,word in tokens {
  if word == 'const' && i+4 < tokens.len && tokens[i+3] == '=' {
   mut end:=i+4
   for end < tokens.len && tokens[end] != ';' { end++ }
   if constant_expression(tokens[i+4..end],constants) { constants[tokens[i+2]]=true }
  }
 }
 for i,word in tokens {
  if word in ['<<','>>','&','|','^','~','%','while','do','switch'] { return error('Operator or control flow is unavailable in ESSL 100: ${word}') }
  if word.len>1 && word[0].is_digit() && (word.ends_with('u') || word.ends_with('U')) { return error('Unsigned literals require ESSL 300') }
  if word != 'for' { continue }
  if i+1>=tokens.len || tokens[i+1]!='(' { return error('Invalid for loop') }
  mut clauses := [][]string{}
  mut begin:=i+2
  mut end:=begin
  mut depth:=0
  for end < tokens.len {
   if tokens[end]==')' && depth==0 { clauses << tokens[begin..end].clone();break }
   if tokens[end]==';' && depth==0 { clauses << tokens[begin..end].clone();begin=end+1 }
   if tokens[end]=='(' {depth++};if tokens[end]==')' {depth--}
   end++
  }
  if clauses.len!=3 {return error('Invalid for loop clauses')}
  init:=clauses[0];condition:=clauses[1];update:=clauses[2]
  if init.len<4 || init[0] !in ['int','float'] || !identifier(init[1]) || init[2]!='=' || !constant_expression(init[3..],constants) {return error('ESSL 100 requires a constant loop initializer')}
  index:=init[1]
  if condition.len<3 || condition[0]!=index || condition[1] !in ['<','<=','>','>=','==','!='] || !constant_expression(condition[2..],constants) {return error('ESSL 100 requires a constant loop bound')}
  if !(update.len==2 && ((update[0]==index && update[1] in ['++','--']) || (update[1]==index && update[0] in ['++','--']))) {
   if update.len<3 || update[0]!=index || update[1] !in ['+=','-='] || !constant_expression(update[2..],constants) {return error('ESSL 100 requires a constant loop step')}
  }
 }
}
fn constant_expression(tokens []string, constants map[string]bool) bool {
 if tokens.len==0 {return false}
 for word in tokens {
  if word in ['+','-','*','/','(',')','int','float','true','false'] || word in constants {continue}
  if word.len==0 || !(word[0].is_digit() || word[0]==`.`) {return false}
 }
 return true
}

fn essl_builtin_constant(name string) ?string {
 return {
  'gl_MaxVertexAttribs':'16'
  'gl_MaxVertexUniformVectors':'1024'
  'gl_MaxFragmentUniformVectors':'1024'
  'gl_MaxVaryingVectors':'16'
  'gl_MaxVertexTextureImageUnits':'16'
  'gl_MaxTextureImageUnits':'16'
  'gl_MaxCombinedTextureImageUnits':'32'
  'gl_MaxDrawBuffers':'8'
 }[name] or {return none}
}
