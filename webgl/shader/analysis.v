// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module shader

struct ShaderSymbol {
 name string
 typ string
 start int
 end int
 length int
 readonly bool
 uniform bool
 sampler bool
 block bool
}
struct ShaderAnalysis {
 functions []ShaderFunction
 live map[int]bool
 used map[string]bool
}

fn statement_end(tokens []string, start int, nesting int) !int {
 if nesting>128 || start>=tokens.len {return error('Invalid shader statement')}
 if tokens[start]=='{' {return matching_token(tokens,start)!+1}
 if tokens[start] in ['if','for','while','switch'] {
  if start+1>=tokens.len || tokens[start+1]!='(' {return error('Expected statement condition')}
  body:=matching_token(tokens,start+1)!+1
  mut end:=statement_end(tokens,body,nesting+1)!
  if tokens[start]=='if' && end<tokens.len && tokens[end]=='else' {end=statement_end(tokens,end+1,nesting+1)!}
  return end
 }
 if tokens[start]=='do' {
  end:=statement_end(tokens,start+1,nesting+1)!
  if end+1>=tokens.len || tokens[end]!='while' || tokens[end+1]!='(' {return error('Expected do-while condition')}
  close:=matching_token(tokens,end+1)!
  if close+1>=tokens.len || tokens[close+1]!=';' {return error('Expected ; after do-while')}
  return close+2
 }
 mut at:=start
 for at<tokens.len {
  if tokens[at]==';' {return at+1}
  if tokens[at] in ['(', '['] {at=matching_token(tokens,at)!}
  if tokens[at]=='}' {return error('Missing statement terminator')}
  at++
 }
 return error('Unterminated shader statement')
}

fn shader_global_symbols(tokens []string, functions []ShaderFunction, stage Stage) ![]ShaderSymbol {
 mut result:=[]ShaderSymbol{}
 mut function_ends:=map[int]int{}
 for function in functions {function_ends[function.start]=function.end}
 mut at:=0
 for at<tokens.len {
  if end:=function_ends[at] {at=end;continue}
  if tokens[at]=='uniform' && at+2<tokens.len && tokens[at+2]=='{' {
   end:=matching_token(tokens,at+2)!
   if end+1<tokens.len && identifier(tokens[end+1]) {
    result << ShaderSymbol{name:tokens[end+1],typ:tokens[at+1],start:end+1,end:tokens.len,length:if end+4<tokens.len && tokens[end+2]=='[' && tokens[end+4]==']' {int(pp_integer(tokens[end+3]) or {0})} else {0},readonly:true,uniform:true,block:true}
   } else {
    for p in at+3..end-1 {
     if identifier(tokens[p]) && identifier(tokens[p+1]) && tokens[p] !in ['lowp','mediump','highp','layout'] {
      result << ShaderSymbol{name:tokens[p+1],typ:tokens[p],start:p+1,end:tokens.len,length:if p+4<end && tokens[p+2]=='[' && tokens[p+4]==']' {int(pp_integer(tokens[p+3]) or {0})} else {0},readonly:true,uniform:true}
     }
    }
   }
   at=end+1;continue
  }
  if tokens[at]=='{' {at=matching_token(tokens,at)!+1;continue}
  if tokens[at] in ['uniform','attribute','varying','in','out'] {
   qualifier:=tokens[at]
   mut type_at:=at+1
   if type_at<tokens.len && tokens[type_at] in ['lowp','mediump','highp'] {type_at++}
   if type_at>=tokens.len {return error('Missing interface type')}
   mut name_at:=type_at+1
   for name_at<tokens.len && identifier(tokens[name_at]) {
    mut end:=name_at+1
    mut length:=0
    if end<tokens.len && tokens[end]=='[' {
     close:=matching_token(tokens,end)!
     if close==end+2 {length=int(pp_integer(tokens[end+1]) or {0})}
     end=close+1
    }
    result << ShaderSymbol{name:tokens[name_at],typ:tokens[type_at],start:name_at,end:tokens.len,length:length,readonly:qualifier in ['uniform','attribute','in'] || (qualifier=='varying' && stage==.fragment),uniform:qualifier=='uniform',sampler:tokens[type_at].contains('sampler')}
    if end>=tokens.len || tokens[end]!=',' {break}
    name_at=end+1
   }
  }
  at++
 }
 for name in ['gl_VertexID','gl_InstanceID','gl_FragCoord','gl_FrontFacing','gl_PointCoord','gl_MaxVertexAttribs','gl_MaxVaryingVectors'] {result << ShaderSymbol{name:name,typ:if name in ['gl_VertexID','gl_InstanceID'] || name.starts_with('gl_Max') {'int'} else if name=='gl_FrontFacing' {'bool'} else if name=='gl_PointCoord' {'vec2'} else {'vec4'},readonly:true,start:-1,end:tokens.len}}
 for name,typ in {'gl_Position':'vec4','gl_FragColor':'vec4','gl_FragData':'vec4','gl_PointSize':'float'} {result << ShaderSymbol{name:name,typ:typ,start:-1,end:tokens.len,length:if name=='gl_FragData' {8} else {0}}}
 return result
}

fn function_symbols(tokens []string, function ShaderFunction, types map[string]bool, version int) ![]ShaderSymbol {
 mut result:=[]ShaderSymbol{}
 for parameter in function.parameters {result << ShaderSymbol{name:parameter.name,typ:parameter.typ,start:function.body-1,end:function.end,length:parameter.array_length,readonly:parameter.constant}}
 mut ends:=[]int{len:function.end-function.body,init:function.end}
 for p in function.body..function.end {
  if tokens[p]=='{' || tokens[p]=='for' {
   end:=if tokens[p]=='{' {matching_token(tokens,p)!+1} else {statement_end(tokens,p,0)!}
   for position in p..end {if ends[position-function.body]>end {ends[position-function.body]=end}}
  }
 }
 for p in function.body..function.end-1 {
  if !source_type(tokens[p],types) || !identifier(tokens[p+1]) || (p>0 && tokens[p-1]=='.') {continue}
  if p+2<tokens.len && tokens[p+2]=='(' {continue}
  mut name_at:=p+1
  for name_at<function.end && identifier(tokens[name_at]) {
   mut at:=name_at+1
   mut length:=0
   if at<tokens.len && tokens[at]=='[' {
    end:=matching_token(tokens,at)!
    if end==at+2 {length=int(pp_integer(tokens[at+1]) or {0})}
    at=end+1
   }
   constant:=(p>0 && tokens[p-1]=='const') || (p>1 && tokens[p-2]=='const')
   result << ShaderSymbol{name:tokens[name_at],typ:tokens[p],start:name_at,end:ends[name_at-function.body],length:length,readonly:constant}
   mut nesting:=0
   for at<function.end {
    if nesting==0 && tokens[at] in [',',';'] {break}
    if tokens[at] in ['(', '['] {nesting++};if tokens[at] in [')',']'] {if nesting==0 {break};nesting--}
    at++
   }
   if at>=function.end || tokens[at]!=',' {break}
   name_at=at+1
  }
 }
 if version==100 {
  mut protected:=[]ShaderSymbol{}
  for p in function.body..function.end-4 {
   if tokens[p]!='for' {continue}
   header:=matching_token(tokens,p+1)!
   end:=statement_end(tokens,p,0)!
   for symbol in result {if symbol.start==p+3 {protected << ShaderSymbol{...symbol,start:header+1,end:end,readonly:true}}}
  }
  result << protected
 }
 return result
}

fn resolve_symbol(name string, at int, locals []ShaderSymbol, globals []ShaderSymbol) ?ShaderSymbol {
 mut selected:=ShaderSymbol{start:-2}
 for symbol in locals {if symbol.name==name && symbol.start<=at && at<symbol.end && symbol.start>selected.start {selected=symbol}}
 if selected.start>=-1 {return selected}
 for symbol in globals {if symbol.name==name {return symbol}}
 return none
}

fn write_after_access(tokens []string, start int) !bool {
 mut at:=start+1
 for at<tokens.len {
  if tokens[at]=='[' {at=matching_token(tokens,at)!+1;continue}
  if tokens[at]=='.' && at+1<tokens.len {at+=2;continue}
  break
 }
 return (start>0 && tokens[start-1] in ['++','--']) || (at<tokens.len && tokens[at] in ['=','+=','-=','*=','/=','%=','&=','|=','^=','<<=','>>=','++','--'])
}

fn analyze_shader(tokens []string, version int, stage Stage) !ShaderAnalysis {
 functions:=shader_functions(tokens)!
 globals:=shader_global_symbols(tokens,functions,stage)!
 structures:=shader_structure_types(tokens,version,functions)!
 mut types:=map[string]bool{}
 for p,word in tokens {if word=='struct' && p+1<tokens.len {types[tokens[p+1]]=true}}
 mut uses:=map[int][]string{}
 mut calls:=map[int][]int{}
 mut cycle_calls:=map[int][]int{}
 for function in functions {
  if function.body<0 {continue}
  locals:=function_symbols(tokens,function,types,version)!
  mut used:=[]string{}
  mut called:=[]int{}
  mut cycle_called:=[]int{}
  mut loop_indices:=map[int]ShaderSymbol{}
  mut loop_headers:=map[int]int{}
  for p in function.body..function.end {
   if tokens[p]=='for' && p+4<tokens.len && identifier(tokens[p+3]) {
    if symbol:=resolve_symbol(tokens[p+3],p+3,locals,globals) {loop_indices[symbol.start]=symbol;loop_headers[symbol.start]=matching_token(tokens,p+1)!}
   }
  }
  for p in function.body+1..function.end-1 {
   word:=tokens[p]
   if !identifier(word) || tokens[p-1]=='.' {continue}
   if p+1<tokens.len && tokens[p+1]=='(' {continue}
   symbol:=resolve_symbol(word,p,locals,globals) or {continue}
   if p==symbol.start {continue}
   local:=locals.any(it.start==symbol.start && it.name==symbol.name)
   if !local && word !in used {used << word}
   write:=write_after_access(tokens,p)!
   if write && symbol.readonly {return error('Assignment to read-only shader variable: '+word)}
   if version==100 && symbol.start in loop_indices && write {
    if p>loop_headers[symbol.start] {return error('ESSL100 loop index is modified inside its body: '+word)}
   }
   mut access:=p+1
   for access<function.end {
    if tokens[access]=='.' && access+1<tokens.len {access+=2;continue}
    if tokens[access]!='[' {break}
    end:=matching_token(tokens,access)!
    index:=tokens[access+1..end]
    if value:=constant_integer(index,map[string]ConstantScalar{}) {
     if value<0 || (access==p+1 && symbol.length>0 && value>=symbol.length) {return error('Constant shader index out of range')}
    } else if (version==300 && (symbol.sampler || (symbol.block && symbol.length>0 && access==p+1))) || (version==100 && !(stage==.vertex && symbol.uniform && !symbol.sampler)) {
     mut permitted:=map[string]bool{}
     for _,loop in loop_indices {if loop.start<p && p<loop.end {if selected:=resolve_symbol(loop.name,p,locals,globals) {if selected.start==loop.start || (selected.start==loop_headers[loop.start]+1 && selected.readonly) {permitted[loop.name]=true}}}}
     if version!=100 || !constant_expression(index,permitted) {return error('Shader index requires a constant expression')}
    }
    access=end+1
   }
  }
  // Passing a protected lvalue to out/inout is also a write.
  for p in function.body+1..function.end-1 {
   if tokens[p+1]!='(' || !functions.any(it.name==tokens[p]) {continue}
   end:=matching_token(tokens,p+1)!
   mut arguments:=[][]string{}
   mut argument_offsets:=[]int{}
   mut begin:=p+2
   mut at:=begin
   for at<end {
    if tokens[at] in ['(', '['] {at=matching_token(tokens,at)!}
    if tokens[at]==',' {arguments << tokens[begin..at].clone();argument_offsets << begin;begin=at+1}
    at++
   }
   if begin<end {arguments << tokens[begin..end].clone();argument_offsets << begin}
   mut argument_types:=[]ShaderExpression{}
   for i,arg in arguments {argument_types << expression_type(arg,argument_offsets[i],locals,globals,functions,structures)!}
   mut possible:=[]int{}
   for target in functions {
    if target.name!=tokens[p] || target.parameters.len!=arguments.len {continue}
    mut matches:=true
    for i,param in target.parameters {if argument_types[i].typ!='' && (argument_types[i].typ!=param.typ || argument_types[i].length!=param.array_length) {matches=false}}
    if !matches {continue}
    if target.body>=0 && target.start !in possible {possible << target.start}
    for i,parameter in target.parameters {
     if parameter.direction !in ['out','inout'] || arguments[i].len==0 {continue}
     name:=arguments[i][0]
     symbol:=resolve_symbol(name,p,locals,globals) or {continue}
     if symbol.readonly || (version==100 && symbol.start in loop_indices) {return error('Protected variable passed to output parameter: '+name)}
    }
   }
   for candidate in possible {if candidate !in called {called << candidate}}
   if possible.len==1 && possible[0] !in cycle_called {cycle_called << possible[0]}
  }
  uses[function.start]=used
  calls[function.start]=called
  cycle_calls[function.start]=cycle_called
 }
 mut validated:=map[int]bool{}
 for function in functions {
  if function.body<0 {continue}
  mut path:=map[int]bool{}
  validate_call_cycles(function.start,cycle_calls,functions,mut path,mut validated,0)!
 }
 mut live:=map[int]bool{}
 mut pending:=functions.filter(it.name=='main' && it.body>=0).map(it.start)
 for pending.len>0 {
  start:=pending.pop()
  if live[start] {continue}
  live[start]=true
  for target in calls[start] {if !live[target] {pending << target}}
 }
 mut used:=map[string]bool{}
 for start,_ in live {for name in uses[start] {used[name]=true}}
 return ShaderAnalysis{functions:functions,live:live,used:used}
}

fn validate_call_cycles(start int,calls map[int][]int,functions []ShaderFunction,mut path map[int]bool,mut validated map[int]bool,depth int) ! {
 if depth>128 {return error('Shader call depth limit exceeded')}
 if path[start] {return error('Recursive shader functions are forbidden')}
 if validated[start] {return}
 path[start]=true
 for target in calls[start] {validate_call_cycles(target,calls,functions,mut path,mut validated,depth+1)!}
 path.delete(start)
 validated[start]=true
}
