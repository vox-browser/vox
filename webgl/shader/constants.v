// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module shader

// Fold integral constant expressions at their lexical declaration/use scope.
// Bounds remain explicit literals for the layout and Metal generators.
fn normalize_constant_expressions(tokens []string) ![]string {
 mut result:=[]string{}
 mut constants:=map[string]ConstantScalar{}
 mut scopes:=[]map[string]ConstantScalar{}
 mut at:=0
 mut const_until:=-1
 mut declared:=map[int]bool{}
 mut function_bodies:=map[int]bool{}
 mut prototypes:=map[int]bool{}
 for at<tokens.len {
  word:=tokens[at]
  if word=='{' && !(at in function_bodies) {scopes << constants.clone()}
  if at in prototypes {constants=scopes.pop()}
  if word=='}' && scopes.len>0 {constants=scopes.pop()}
  if word=='const' {
   mut type_at:=at+1
   if type_at<tokens.len && tokens[type_at] in ['lowp','mediump','highp'] {type_at++}
   if type_at+2<tokens.len && tokens[type_at] in ['int','uint','bool','float'] && tokens[type_at+2]=='=' {
    mut name_at:=type_at+1
    mut end:=name_at
    for end<tokens.len && tokens[end]!=';' {end++}
    const_until=end
    for name_at+1<end && identifier(tokens[name_at]) && tokens[name_at+1]=='=' {
     mut finish:=name_at+2
     mut nesting:=0
     for finish<end {
      if tokens[finish]==',' && nesting==0 {break}
      if tokens[finish]=='(' {nesting++};if tokens[finish]==')' {nesting--}
      finish++
     }
     name:=tokens[name_at]
     raw:=constant_value(tokens[name_at+2..finish],constants)!
     value:=constant_function(tokens[type_at],[raw],true)!
     constants[name]=value
     declared[name_at]=true
     name_at=finish+1
    }
   }
  }
  if at+2<tokens.len && identifier(word) && identifier(tokens[at+1]) && tokens[at+2]=='(' {
   close:=matching_token(tokens,at+2)!
   if close+1<tokens.len && tokens[close+1] in ['{',';'] {
    scopes << constants.clone()
    if tokens[close+1]=='{' {function_bodies[close+1]=true} else {prototypes[close+1]=true}
   }
  }
  if at+1<tokens.len && identifier(tokens[at+1]) && source_type(word,map[string]bool{}) {
   declared[at+1]=true
   if at>const_until {constants.delete(tokens[at+1])}
  }

  if word=='[' {
   end:=matching_token(tokens,at)!
   if end>at+1 {
    if value:=constant_integer(tokens[at+1..end],constants) {
     result << '[';result << value.str();result << ']';at=end+1;continue
    }
   }
  }
  // Resolve constants only in layout/output indices and integer declarations;
  // ordinary expression names stay intact for liveness and diagnostics.
  if at>0 && word in constants && !(at in declared) && tokens[at-1]!='.' {
   // All constant references can be replaced with their value, except a new
   // declaration shadowing that name (handled above).
   result << constants[word].source()
  } else {result << word}
  at++
 }
 return result
}

fn constant_integer(tokens []string, constants map[string]ConstantScalar) !i64 {
 value:=constant_value(tokens,constants)!
 if value.kind !in ['int','uint'] || value.value<f64(min_i64) || value.value>=f64(max_i64) {return error('Integral constant expression required')}
 return i64(value.value)
}
