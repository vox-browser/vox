// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module shader

struct ShaderDeclarator {
 name string
 typ string
 name_at int
 after_name int
 delimiter int
 length int
 initialized bool
}
struct ShaderDeclaration {
 start int
 type_at int
 end int
 readonly bool
 fields []ShaderDeclarator
}

// Describe the complete comma-separated declaration, skipping expressions so
// constructor arguments and structure fields are never mistaken for variables.
fn shader_declaration(tokens []string, type_at int, limit int) ?ShaderDeclaration {
 if type_at+1>=limit || !identifier(tokens[type_at+1]) {return none}
 mut start:=type_at
 for start>0 && tokens[start-1] in ['const','lowp','mediump','highp'] {start--}
 mut fields:=[]ShaderDeclarator{}
 mut at:=type_at+1
 for at<limit {
  if !identifier(tokens[at]) {return none}
  name_at:=at
  at++
  mut length:=0
  if at<limit && tokens[at]=='[' {
   close:=matching_token(tokens,at) or {return none}
   if close>=limit || close!=at+2 {return none}
   value:=pp_integer(tokens[at+1]) or {return none}
   if value<1 || value>4096 {return none}
   length=int(value);at=close+1
  }
  after_name:=at
  if at>=limit || tokens[at] !in ['=',',',';',')'] {return none}
  initialized:=tokens[at]=='='
  if initialized {
   at++
   for at<limit && tokens[at] !in [',',';',')'] {
    if tokens[at] in ['(', '['] {at=matching_token(tokens,at) or {return none}}
    at++
   }
  }
  if at>=limit {return none}
  fields << ShaderDeclarator{name:tokens[name_at],typ:tokens[type_at],name_at:name_at,after_name:after_name,delimiter:at,length:length,initialized:initialized}
  if tokens[at]!=',' {return ShaderDeclaration{start:start,type_at:type_at,end:at+1,readonly:'const' in tokens[start..type_at],fields:fields}}
  at++
 }
 return none
}

fn shader_declared_types(tokens []string) map[string]bool {
 mut result:=map[string]bool{}
 for at,word in tokens {if word=='struct' && at+1<tokens.len {result[tokens[at+1]]=true}}
 return result
}

fn ordinary_global_declarations(tokens []string,functions []ShaderFunction) []ShaderDeclaration {
 types:=shader_declared_types(tokens)
 mut ends:=map[int]int{}
 for function in functions {ends[function.start]=function.end}
 mut result:=[]ShaderDeclaration{}
 mut at:=0
 mut statement:=0
 for at<tokens.len {
  if end:=ends[at] {at=end;statement=at;continue}
  if tokens[at]=='{' {at=(matching_token(tokens,at) or {return result})+1;statement=at;continue}
  if tokens[at]==';' {at++;statement=at;continue}
  if source_type(tokens[at],types) && !tokens[statement..at].any(it in ['uniform','attribute','varying','in','out']) {
   if declaration:=shader_declaration(tokens,at,tokens.len) {result << declaration;at=declaration.end;statement=at;continue}
  }
  at++
 }
 return result
}

fn local_declarations(tokens []string,function ShaderFunction) []ShaderDeclaration {
 types:=shader_declared_types(tokens)
 mut result:=[]ShaderDeclaration{}
 mut at:=function.body+1
 for at<function.end-1 {
  if source_type(tokens[at],types) && tokens[at-1]!='.' {
   if declaration:=shader_declaration(tokens,at,function.end-1) {result << declaration;at=declaration.end;continue}
  }
  at++
 }
 return result
}

// Moving a global initializer to main must preserve its original lexical
// scope and WebGL's restricted global-initializer expression grammar.
fn validate_global_initializers(tokens []string,functions []ShaderFunction,stage Stage,version int) ! {
 declarations:=ordinary_global_declarations(tokens,functions)
 globals:=shader_global_symbols(tokens,functions,stage)!
 types:=shader_declared_types(tokens)
 mut ordinary_names:=map[string]bool{}
 mut type_positions:=map[string]int{}
 for declaration in declarations {for field in declaration.fields {ordinary_names[field.name]=true}}
 for at,word in tokens {if word=='struct' && at+1<tokens.len {type_positions[tokens[at+1]]=at}}
 for declaration in declarations {
  for field in declaration.fields {
   if !field.initialized {continue}
   for at in field.after_name+1..field.delimiter {
    word:=tokens[at]
    if word in ['=','+=','-=','*=','/=','%=','&=','|=','^=','<<=','>>=','++','--'] {return error('Global initializer cannot modify a variable')}
    if !identifier(word) || tokens[at-1]=='.' || word in ['true','false'] {continue}
    if at+1<field.delimiter && (tokens[at+1]=='(' || (tokens[at+1]=='[' && source_type(word,types))) {
     if functions.any(it.name==word) {return error('Global initializer cannot call a user function')}
     if source_type(word,types) {
      if position:=type_positions[word] {if position>=field.name_at {return error('Global initializer uses an undeclared type')}}
      continue
     }
     if word !in ['radians','degrees','sin','cos','tan','asin','acos','atan','sinh','cosh','tanh','asinh','acosh','atanh','pow','exp','log','exp2','log2','sqrt','inversesqrt','abs','sign','floor','trunc','round','roundEven','ceil','fract','mod','min','max','clamp','mix','step','smoothstep','length','distance','dot','cross','normalize','faceforward','reflect','refract','matrixCompMult','outerProduct','transpose','determinant','inverse','lessThan','lessThanEqual','greaterThan','greaterThanEqual','equal','notEqual','any','all','not','isnan','isinf','floatBitsToInt','floatBitsToUint','intBitsToFloat','uintBitsToFloat','packUnorm2x16','packSnorm2x16','packHalf2x16','unpackUnorm2x16','unpackSnorm2x16','unpackHalf2x16','dFdx','dFdy','fwidth'] {return error('Unsupported function in global initializer: '+word)}
     continue
    }
    if _:=essl_builtin_constant(word) {continue}
    symbol:=resolve_symbol(word,at,[]ShaderSymbol{},globals) or {return error('Unknown name in global initializer: '+word)}
    if symbol.start>=field.name_at {return error('Global initializer uses a variable before its declaration: '+word)}
    if symbol.name.starts_with('gl_') || (!symbol.uniform && !(word in ordinary_names)) {return error('Invalid variable in global initializer: '+word)}
    if (version==300 || declaration.readonly) && (!symbol.readonly || symbol.uniform) {return error('Global initializer must be constant')}
   }
  }
 }
}

fn validate_metal_initializer_bindings(tokens []string,functions []ShaderFunction) ! {
 mut declarations:=ordinary_global_declarations(tokens,functions)
 for function in functions {if function.body>=0 {declarations << local_declarations(tokens,function)}}
 for declaration in declarations {
  for field in declaration.fields {
   if !field.initialized {continue}
   for at in field.after_name+1..field.delimiter {
    // ESSL exposes the new name after its initializer, whereas MSL exposes it
    // before. Reject this unsupported shadowing form instead of reading an
    // uninitialized inner object with a different inferred array extent.
    if tokens[at]==field.name && tokens[at-1]!='.' {return error('Unsupported shadowed name in Metal initializer: '+field.name)}
   }
  }
 }
}

// MSL accepts native types and declarators that are not ESSL. Every global
// declaration must be recognized before token lowering can erase qualifiers.
fn validate_metal_global_declarations(tokens []string,functions []ShaderFunction,version int) ! {
 mut ends:=map[int]int{}
 for function in functions {ends[function.start]=function.end}
 for declaration in ordinary_global_declarations(tokens,functions) {ends[declaration.start]=declaration.end}
 mut structures:=map[string]ShaderStruct{}
 mut at:=0
 for at<tokens.len {
  if end:=ends[at] {at=end;continue}
  if tokens[at]==';' {at++;continue}
  if tokens[at] in ['lowp','mediump','highp'] && at+1 in ends {at++;continue}
  if tokens[at]=='struct' {
   declaration:=structure_declaration(tokens,at,structures,version)!
   structures[declaration.definition.name]=declaration.definition
   at=declaration.end;continue
  }
  if _:=block_uniform_at(tokens,at) {
   declaration:=uniform_block_declaration(tokens,at,structures,1,false)!
   if declaration.named {structures[declaration.definition.name]=declaration.definition}
   at=declaration.end;continue
  }
  if tokens[at]=='precision' && at+3<tokens.len && tokens[at+1] in ['lowp','mediump','highp'] && tokens[at+3]==';' {at+=4;continue}
  if tokens[at]=='invariant' && at+2<tokens.len && tokens[at+1]=='gl_Position' && tokens[at+2]==';' {at+=3;continue}
  if tokens[at]=='layout' {at=location_qualifier(tokens,at)!.end;continue}
  if tokens[at] in ['flat','smooth'] {at++;continue}
  if tokens[at] in ['uniform','attribute','varying','in','out'] {
   mut type_at:=at+1
   if type_at<tokens.len && tokens[type_at] in ['lowp','mediump','highp'] {type_at++}
   declaration:=shader_declaration(tokens,type_at,tokens.len) or {return error('Invalid shader interface declaration')}
   at=declaration.end;continue
  }
  return error('Unsupported shader global declaration near '+tokens[at])
 }
}

fn defer_metal_global_initializers(tokens []string,functions []ShaderFunction) ![]string {
 mut replacements:=map[int]ExpressionReplacement{}
 mut setup:=[]string{}
 for declaration in ordinary_global_declarations(tokens,functions) {
  if declaration.readonly {continue}
  for field in declaration.fields {
   if !field.initialized {continue}
   setup << field.name+'='+tokens[field.after_name+1..field.delimiter].join(' ')+';'
   replacements[field.after_name]=ExpressionReplacement{end:field.delimiter}
  }
 }
 if setup.len==0 {return tokens}
 setup_tokens:=lex(setup.join(' '))!
 mut entries:=map[int]bool{}
 for function in functions {if function.name=='main' && function.body>=0 {entries[function.body+1]=true}}
 mut result:=[]string{}
 mut at:=0
 for at<tokens.len {
  if at in entries {result << setup_tokens}
  if replacement:=replacements[at] {at=replacement.end}
  else {result << tokens[at];at++}
 }
 return result
}

fn metal_zero_initializers(tokens []string,functions []ShaderFunction) map[int]bool {
 mut declarations:=ordinary_global_declarations(tokens,functions)
 for function in functions {if function.body>=0 {declarations << local_declarations(tokens,function)}}
 mut result:=map[int]bool{}
 for declaration in declarations {
  if declaration.readonly {continue}
  for field in declaration.fields {if !field.initialized {result[field.after_name]=true}}
 }
 return result
}

fn essl_zero_expression(typ string,length int,structures map[string]ShaderStruct,version int,depth int) ?string {
 if depth>16 {return none}
 if length>0 {
  if version!=300 {return none}
  value:=essl_zero_expression(typ,0,structures,version,depth+1) or {return none}
  if length>4096 || value.len*length>1024*1024 {return none}
  return '${typ}[${length}]('+[]string{len:length,init:value}.join(',')+')'
 }
 if definition:=structures[typ] {
  mut values:=[]string{}
  mut size:=0
  for field in definition.fields {
   value:=essl_zero_expression(field.typ,if field.is_array {field.array_length} else {0},structures,version,depth+1) or {return none}
   size+=value.len
   if size>1024*1024 {return none}
   values << value
  }
  return typ+'('+values.join(',')+')'
 }
 if typ=='bool' || typ.starts_with('bvec') {return typ+'(false)'}
 if typ=='uint' || typ.starts_with('uvec') {return typ+'(0u)'}
 if typ=='int' || typ.starts_with('ivec') {return typ+'(0)'}
 if typ=='float' || typ.starts_with('vec') || typ.starts_with('mat') {return typ+'(0.0)'}
 return none
}

struct ZeroInitializer {
mut:
 serial int
}

fn (mut z ZeroInitializer) statements(name string,typ string,length int,structures map[string]ShaderStruct,depth int) !string {
 if depth>16 {return error('Shader initialization nesting limit exceeded')}
 if length>0 {
  if length>4096 {return error('Shader initialization array limit exceeded')}
  index:='_webgl_zero_'+z.serial.str();z.serial++
  child:=z.statements(name+'['+index+']',typ,0,structures,depth+1)!
  return 'for(int '+index+'=0;'+index+'<'+length.str()+';++'+index+'){'+child+'}'
 }
 if definition:=structures[typ] {
  mut result:=''
  for field in definition.fields {result+=z.statements(name+'.'+field.name,field.typ,if field.is_array {field.array_length} else {0},structures,depth+1)!}
  if result.len>1024*1024 {return error('Shader initialization size limit exceeded')}
  return result
 }
 value:=essl_zero_expression(typ,0,structures,100,depth) or {return error('Cannot initialize shader type: '+typ)}
 return name+'='+value+';'
}

// Native GLES retains ESSL and its original version. Only the private driver
// submission gains the zero initialization WebGL promises for user variables.
pub fn prepare_source(source string,stage Stage,context_version int) !string {
 validate_source(source,stage,context_version)!
 processed:=preprocess(source)!
 tokens:=normalize_constant_expressions(processed.tokens)!
 functions:=shader_functions(tokens)!
 structures:=shader_structure_types(tokens,processed.version,functions)!
 mut insertions:=map[int]string{}
 mut replacements:=map[int]ExpressionReplacement{}
 mut zero:=ZeroInitializer{}
 mut global_setup:=''
 global_declarations:=ordinary_global_declarations(tokens,functions)
 mut ordinary_names:=map[string]bool{}
 for declaration in global_declarations {for field in declaration.fields {ordinary_names[field.name]=true}}
 for symbol in shader_global_symbols(tokens,functions,stage)! {
  if symbol.readonly || symbol.name.starts_with('gl_') || symbol.name in ordinary_names {continue}
  global_setup+=zero.statements(symbol.name,symbol.typ,symbol.length,structures,0)!
 }
 // Do not introduce an unused fragment output. In particular a shader with
 // neither color builtin must continue to leave the color buffer untouched.
 for name,typ in {'gl_Position':'vec4','gl_PointSize':'float','gl_FragColor':'vec4','gl_FragDepth':'float','gl_FragDepthEXT':'float'} {
  if (stage==.vertex && name=='gl_Position') || name in tokens {global_setup+=zero.statements(name,typ,0,structures,0)!}
 }
 if stage==.fragment && 'gl_FragData' in tokens {
  info:=fragment_builtins(tokens,processed.version,processed.extensions)!
  for target in info.targets {global_setup+='gl_FragData[${target}]=vec4(0.0);'}
 }
 // ESSL100 permits nonconstant global initializers. Perform all ordinary
 // mutable initialization in declaration order after aggregate zeroing, so a
 // later initializer can safely read an earlier array or structure member.
 for declaration in global_declarations {
  if declaration.readonly {continue}
  for field in declaration.fields {
   if field.initialized {
    global_setup+=field.name+'='+tokens[field.after_name+1..field.delimiter].join(' ')+';'
    replacements[field.after_name]=ExpressionReplacement{end:field.delimiter}
   } else {global_setup+=zero.statements(field.name,field.typ,field.length,structures,0)!}
  }
 }
 for function in functions {
  if function.body<0 {continue}
  mut setup:=if function.name=='main' {global_setup} else {''}
  for parameter in function.parameters {if parameter.direction=='out' {setup+=zero.statements(parameter.name,parameter.typ,parameter.array_length,structures,0)!}}
  if setup!='' {insertions[function.body+1]=setup}
  for declaration in local_declarations(tokens,function) {
   if declaration.readonly {continue}
   mut split:=false
   for field in declaration.fields {
    if field.initialized {continue}
    if value:=essl_zero_expression(field.typ,field.length,structures,processed.version,0) {insertions[field.after_name]='='+value}
    else {split=true}
   }
   if !split {continue}
   if tokens[declaration.end-1]!=';' {return error('Unsupported array initialization in a condition')}
   prefix:=tokens[declaration.start..declaration.type_at+1].join(' ')+' '
   mut replacement:=''
   for field in declaration.fields {
    insertions.delete(field.after_name)
    replacement+=prefix+tokens[field.name_at..field.delimiter].join(' ')+';'
    if !field.initialized {replacement+=zero.statements(field.name,field.typ,field.length,structures,0)!}
   }
   // A declaration used as an unbraced controlled statement needs the setup
   // inside the same control flow; preserve the scope of ordinary declarations.
   if declaration.start>0 && tokens[declaration.start-1] in [')','else','do'] {replacement='{'+replacement+'}'}
   replacements[declaration.start]=ExpressionReplacement{end:declaration.end,source:replacement}
  }
 }
 mut result:=if processed.version==300 {'#version 300 es\n'} else {'#version 100\n'}
 for name,enabled in processed.extensions {if enabled {result+='#extension '+name+' : enable\n'}}
 if processed.invariant_all {result+='#pragma STDGL invariant(all)\n'}
 mut at:=0
 for at<tokens.len {
  result+=insertions[at]
  if replacement:=replacements[at] {result+=replacement.source;at=replacement.end}
  else {result+=tokens[at]+' ';at++}
  if result.len>4*1024*1024 {return error('Initialized shader exceeds the source limit')}
 }
 return result
}
