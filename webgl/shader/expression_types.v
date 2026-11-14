// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module shader

struct ShaderExpression {
 typ string
 length int
 source string
 writable bool
}
struct ExpressionParser {
 tokens []string
 locals []ShaderSymbol
 globals []ShaderSymbol
 functions []ShaderFunction
 structures map[string]ShaderStruct
 offset int
mut:
 at int
 depth int
}
fn expression_priority(op string) int {
 return match op {'=','+=','-=','*=','/=','%=','&=','|=','^=','<<=','>>=' {0} '||' {2} '^^' {3} '&&' {4} '|' {5} '^' {6} '&' {7} '==','!=' {8} '<','>','<=','>=' {9} '<<','>>' {10} '+','-' {11} '*','/','%' {12} else {-1}}
}
fn scalar_of(typ string) string {
 if is_vector_type(typ) {
  if typ.starts_with('bvec') {return 'bool'}
  if typ.starts_with('ivec') {return 'int'}
  if typ.starts_with('uvec') {return 'uint'}
  return 'float'
 }
 if is_matrix_type(typ) {return 'float'}
 return typ
}
fn vector_type(scalar string, width int) string {
 if width==1 {return scalar}
 return (match scalar {'int' {'ivec'} 'uint' {'uvec'} 'bool' {'bvec'} else {'vec'}})+width.str()
}
fn expression_type(tokens []string,offset int,locals []ShaderSymbol,globals []ShaderSymbol,functions []ShaderFunction,structures map[string]ShaderStruct) !ShaderExpression {
 if tokens.len==0 {return ShaderExpression{}}
 mut parser:=ExpressionParser{tokens:tokens,offset:offset,locals:locals,globals:globals,functions:functions,structures:structures}
 result:=parser.expression_list()!
 if parser.at!=tokens.len {return error('Invalid shader expression near '+tokens[parser.at])}
 return result
}
fn (mut p ExpressionParser) expression_list() !ShaderExpression {
 mut result:=p.expression(0)!
 for p.at<p.tokens.len && p.tokens[p.at]==',' {
  p.at++
  next:=p.expression(0)!
  result=ShaderExpression{...next,source:'('+result.source+','+next.source+')',writable:false}
 }
 return result
}
fn (mut p ExpressionParser) expression(minimum int) !ShaderExpression {
 if p.depth>=128 {return error('Shader expression nesting limit exceeded')}
 p.depth++
 defer {p.depth--}
 if p.at>=p.tokens.len {return error('Missing shader expression')}
 start:=p.at
 word:=p.tokens[p.at];p.at++
 mut left:=ShaderExpression{}
 if word in ['+','-','!','~','++','--'] {
  operand:=p.expression(13)!
  if word=='!' && operand.typ!='' && operand.typ!='bool' {return error('Logical negation requires bool')}
  if word in ['++','--'] && !operand.writable {return error('Increment requires a writable value')}
  if word in ['+','-','++','--'] && scalar_of(operand.typ)=='bool' {return error('Arithmetic requires numeric operands')}
  left=ShaderExpression{...operand,source:word+'('+operand.source+')',writable:false}
 } else if word=='(' {
  left=p.expression_list()!
  if p.at>=p.tokens.len || p.tokens[p.at]!=')' {return error('Expected ) in shader expression')};p.at++
  left=ShaderExpression{...left,source:'('+left.source+')'}
 } else if word in ['true','false'] {left=ShaderExpression{typ:'bool',source:word}}
 else if identifier(word) {
  mut constructor_length:=0
  if p.at<p.tokens.len && p.tokens[p.at]=='[' && (word in p.structures || source_type(word,map[string]bool{})) {
   end:=matching_token(p.tokens,p.at)!
   if end+1<p.tokens.len && p.tokens[end+1]=='(' {
    count:=constant_integer(p.tokens[p.at+1..end],map[string]ConstantScalar{})!
    if count<1 || count>4096 {return error('Array constructor length out of range')}
    constructor_length=int(count);p.at=end+1
   }
  }
  if p.at<p.tokens.len && p.tokens[p.at]=='(' {
   p.at++
   mut args:=[]ShaderExpression{}
   for p.at<p.tokens.len && p.tokens[p.at]!=')' {
    args << p.expression(0)!
    if p.at<p.tokens.len && p.tokens[p.at]==',' {p.at++;continue};break
   }
   if p.at>=p.tokens.len || p.tokens[p.at]!=')' {return error('Expected function argument terminator')};p.at++
   typ:=if constructor_length>0 {word} else {function_result_type(word,args,p.functions,p.structures,p.offset+start)!}
   left=ShaderExpression{typ:typ,length:constructor_length,source:word+if constructor_length>0 {'[${constructor_length}]'} else {''}+'('+args.map(it.source).join(',')+')'}
  } else if symbol:=resolve_symbol(word,p.offset+start,p.locals,p.globals) {
   left=ShaderExpression{typ:symbol.typ,length:symbol.length,source:word,writable:!symbol.readonly}
  } else if _:=essl_builtin_constant(word) {left=ShaderExpression{typ:'int',source:word}}
  else {left=ShaderExpression{source:word,writable:true}}
 } else {
  is_float:=(word.contains('.') || word.contains('e') || word.contains('E')) && !word.starts_with('0x') && !word.starts_with('0X')
  left=ShaderExpression{typ:if is_float {'float'} else if word.ends_with('u') || word.ends_with('U') {'uint'} else {'int'},source:word}
 }
 for p.at<p.tokens.len {
  op:=p.tokens[p.at]
  if op=='[' {
   p.at++
   index:=p.expression_list()!
   if index.typ !in ['int','uint'] || index.length>0 {return error('Shader array index must be integral')}
   if p.at>=p.tokens.len || p.tokens[p.at]!=']' {return error('Expected ]')};p.at++
   count:=if left.length>0 {left.length} else if is_matrix_type(left.typ) {_,columns:=interface_dimensions(left.typ);columns} else if is_vector_type(left.typ) {int(left.typ[left.typ.len-1]-`0`)} else {0}
   if count<1 {return error('Cannot prove shader subscript bounds')}
   mut bounded_index:=index.source
   if value:=constant_integer(lex(index.source)!,map[string]ConstantScalar{}) {
    if value<0 || value>=count {return error('Constant shader index out of range')}
   } else {
    // A helper call evaluates side effects once and preserves unsigned values
    // until after clamping, including indices above the signed integer range.
    bounded_index='_webgl_safe_index('+index.source+','+count.str()+')'
   }
   typ:=if left.length>0 {left.typ} else if is_matrix_type(left.typ) {rows,_:=interface_dimensions(left.typ);vector_type('float',rows)} else if is_vector_type(left.typ) {scalar_of(left.typ)} else {''}
   left=ShaderExpression{typ:typ,source:left.source+'['+bounded_index+']',writable:left.writable}
   continue
  }
  if op=='.' {
   if p.at+1>=p.tokens.len {return error('Expected shader member name')}
   member:=p.tokens[p.at+1];p.at+=2
   if member=='length' && p.at+1<p.tokens.len && p.tokens[p.at]=='(' && p.tokens[p.at+1]==')' {
    if left.length<1 {return error('length() requires an array')}
    p.at+=2;left=ShaderExpression{typ:'int',source:left.length.str()};continue
   }
   mut typ:=''
   mut length:=0
   mut selector:=member
   mut writable:=left.writable
   if left.length>0 {return error('Array member access requires length()')}
   if is_vector_type(left.typ) {
    swizzle:=vector_swizzle(left.typ,member)!
    selector=swizzle.selector
    typ=vector_type(scalar_of(left.typ),member.len)
    writable=writable && swizzle.unique
   } else if definition:=p.structures[left.typ] {
    fields:=definition.fields.filter(it.name==member)
    if fields.len!=1 {return error('Unknown shader structure member: '+member)}
    typ=fields[0].typ;length=if fields[0].is_array {fields[0].array_length} else {0}
   } else if left.typ!='' {return error('Member selection requires a vector or structure')}
   left=ShaderExpression{typ:typ,length:length,source:left.source+'.'+selector,writable:writable}
   continue
  }
  if op in ['++','--'] {
   if !left.writable {return error('Increment requires a writable value')}
   p.at++;left=ShaderExpression{...left,source:'('+left.source+op+')',writable:false};continue
  }
  if op=='?' && minimum<=1 {
   if left.typ!='' && left.typ!='bool' {return error('Conditional expression requires bool')}
   p.at++
   yes:=p.expression_list()!
   if p.at>=p.tokens.len || p.tokens[p.at]!=':' {return error('Expected : in shader expression')};p.at++
   no:=p.expression(1)!
   if yes.typ!='' && no.typ!='' && (yes.typ!=no.typ || yes.length!=no.length) {return error('Conditional expression types differ')}
   left=ShaderExpression{typ:yes.typ,length:yes.length,source:'('+left.source+'?'+yes.source+':'+no.source+')'};continue
  }
  priority:=expression_priority(op)
  if priority<minimum {break}
  p.at++
  right:=p.expression(priority+if priority==0 {0} else {1})!
  known:=left.typ!='' && right.typ!=''
  mut typ:=left.typ
  mut source:='('+left.source+op+right.source+')'
  if priority==0 {
   if !left.writable {return error('Assignment requires a writable value')}
   if known && (left.typ!=right.typ || left.length!=right.length) {return error('Implicit shader assignment conversion is forbidden: '+left.typ+' <- '+right.typ)}
  } else if op in ['&&','||','^^'] {
   if (left.typ!='' && left.typ!='bool') || (right.typ!='' && right.typ!='bool') {return error('Logical operators require bool')}
   typ='bool'
   if op=='^^' {source='('+left.source+'!='+right.source+')'}
  } else if op in ['==','!='] {
   if known && (left.typ!=right.typ || left.length!=right.length) {return error('Equality operand types differ')}
   typ='bool'
   source=(if op=='!=' {'!'} else {''})+'_vox_same('+left.source+','+right.source+')'
  } else if op in ['<','<=','>','>='] {
   if known && (left.typ!=right.typ || is_vector_type(left.typ) || is_matrix_type(left.typ)) {return error('Ordered comparison requires matching scalar types')}
   typ='bool'
  } else if known {
   if scalar_of(left.typ)!=scalar_of(right.typ) && op !in ['<<','>>'] {return error('Implicit shader operand conversion is forbidden')}
   if scalar_of(left.typ)=='bool' {return error('Arithmetic requires numeric operands')}
   if left.typ!=right.typ {
    if left.typ in ['float','int','uint'] {typ=right.typ}
    else if right.typ !in ['float','int','uint'] {typ=''} // Matrix product dimensions are checked by Metal.
   }
  }
  left=ShaderExpression{typ:typ,length:if priority==0 {left.length} else {0},source:source}
 }
 return left
}

fn function_result_type(name string,args []ShaderExpression,functions []ShaderFunction,structures map[string]ShaderStruct,at int) !string {
 // This identifier is reserved from input shaders and emitted only by the
 // bounds lowering. Its overload clamps either signed or unsigned indices.
 if name=='_webgl_safe_index' {
  if args.len!=2 || args[0].typ !in ['int','uint'] || args[0].length>0 || args[1].typ!='int' || args[1].length>0 {return error('Invalid generated shader index')}
  return 'int'
 }
 if _:=metal_type(name) {return name}
 if name in structures {return name}
 targets:=functions.filter(it.name==name)
 if targets.len>0 {
  for target in targets {
   if target.parameters.len!=args.len {continue}
   mut matches:=true
   for i,param in target.parameters {
    if args[i].typ!='' && (args[i].typ!=param.typ || args[i].length!=param.array_length) {matches=false}
    if param.direction in ['out','inout'] && !args[i].writable {matches=false}
   }
   if matches {
    if !targets.any(it.start<=at && it.parameters.map(it.typ)==target.parameters.map(it.typ)) {return error('Function must be declared before use: '+name)}
    return target.typ
   }
  }
  if !texture_call(name,100) && !texture_call(name,300) && !mapped_builtin(name) {return error('No matching shader overload: '+name)}
 }
 validate_builtin_arguments(name,args)!
 if name in ['modf','frexp'] {
  if args.len!=2 || !args[1].writable {return error('Builtin output parameter requires a writable value')}
  expected:=if name=='modf' {args[0].typ} else {vector_type('int',if is_vector_type(args[0].typ) {int(args[0].typ[args[0].typ.len-1]-`0`)} else {1})}
  if args[1].typ!='' && args[1].typ!=expected {return error('Builtin output parameter type mismatch')}
 }
 if name in ['step','smoothstep'] && args.len>0 {return args.last().typ}
 if name in ['any','all','_vox_same'] {return 'bool'}
 if name in ['length','distance','dot','determinant'] {return 'float'}
 if args.len==0 {return ''}
 first:=args[0].typ
 if name in ['equal','notEqual','lessThan','lessThanEqual','greaterThan','greaterThanEqual'] {return vector_type('bool',if is_vector_type(first) {int(first[first.len-1]-`0`)} else {1})}
 if name.starts_with('texture') || name.starts_with('texelFetch') {
  if name=='textureSize' {return if first.contains('3D') || first.contains('Array') {'ivec3'} else {'ivec2'}}
  return if first.ends_with('Shadow') {'float'} else if first.starts_with('isampler') {'ivec4'} else if first.starts_with('usampler') {'uvec4'} else if first.starts_with('sampler') {'vec4'} else {''}
 }
 if name in ['floatBitsToInt','floatBitsToUint','intBitsToFloat','uintBitsToFloat'] {return vector_type(if name=='floatBitsToInt' {'int'} else if name=='floatBitsToUint' {'uint'} else {'float'},if is_vector_type(first) {int(first[first.len-1]-`0`)} else {1})}
 if name.starts_with('pack') {return 'uint'}
 if name.starts_with('unpack') {return 'vec2'}
 if name in ['sin','cos','tan','asin','acos','atan','sinh','cosh','tanh','asinh','acosh','atanh','radians','degrees','pow','exp','exp2','log','log2','sqrt','inversesqrt','abs','sign','floor','trunc','round','roundEven','ceil','fract','mod','modf','min','max','clamp','mix','step','smoothstep','normalize','faceforward','reflect','refract','matrixCompMult','inverse','frexp','ldexp','dFdx','dFdy','fwidth'] {return first}
 return ''
}

struct ExpressionReplacement {
 end int
 source string
}

fn normalize_declaration_initializers(tokens []string,declaration ShaderDeclaration,locals []ShaderSymbol,globals []ShaderSymbol,functions []ShaderFunction,structures map[string]ShaderStruct,mut replacements map[int]ExpressionReplacement) ! {
 for field in declaration.fields {
  if !field.initialized {continue}
  begin:=field.after_name+1
  expr:=expression_type(tokens[begin..field.delimiter],begin,locals,globals,functions,structures)!
  if expr.typ!='' && (expr.typ!=field.typ || expr.length!=field.length) {return error('Implicit shader initialization conversion is forbidden')}
  replacements[begin]=ExpressionReplacement{end:field.delimiter,source:expr.source}
 }
}

// An expression form that the normalizer does not understand must never leave
// a raw Metal subscript behind. Only parsed expressions and declared array
// extents may consume brackets from the input shader.
fn validate_subscript_coverage(tokens []string,functions []ShaderFunction,globals []ShaderSymbol,replacements map[int]ExpressionReplacement) ! {
 mut declarations:=map[int]bool{}
 for symbol in globals {if symbol.length>0 && symbol.start>=0 {declarations[symbol.start+1]=true}}
 mut function_ends:=map[int]int{}
 for function in functions {
  function_ends[function.start]=function.end
  for p in function.start..function.header_end {if tokens[p]=='[' {declarations[p]=true}}
  if function.body<0 {continue}
  for declaration in local_declarations(tokens,function) {
   for field in declaration.fields {if field.length>0 {declarations[field.name_at+1]=true}}
  }
 }
 mut at:=0
 for at<tokens.len {
  if end:=function_ends[at] {at=end;continue}
  mut open:=-1
  if tokens[at]=='struct' && at+2<tokens.len && tokens[at+2]=='{' {open=at+2}
  else if uniform_at:=block_uniform_at(tokens,at) {
   if uniform_at+2<tokens.len && tokens[uniform_at+2]=='{' {open=uniform_at+2}
  }
  if open>=0 {
   end:=matching_token(tokens,open)!
   // shader_structure_types has already validated these field declarations.
   for p in open+1..end {if tokens[p]=='[' {declarations[p]=true}}
   at=end+1
  } else {at++}
 }
 at=0
 for at<tokens.len {
  if replacement:=replacements[at] {at=replacement.end;continue}
  if tokens[at]=='[' && !declarations[at] {return error('Shader subscript is outside a checked expression')}
  at++
 }
}

fn normalize_shader_expressions(tokens []string,version int,stage Stage) ![]string {
 functions:=shader_functions(tokens)!
 globals:=shader_global_symbols(tokens,functions,stage)!
 structures:=shader_structure_types(tokens,version,functions)!
 mut types:=map[string]bool{}
 for p,word in tokens {if word=='struct' && p+1<tokens.len {types[tokens[p+1]]=true}}
 mut replacements:=map[int]ExpressionReplacement{}
 for declaration in ordinary_global_declarations(tokens,functions) {
  normalize_declaration_initializers(tokens,declaration,[]ShaderSymbol{},globals,functions,structures,mut replacements)!
 }
 for function in functions {
  if function.body<0 {continue}
  locals:=function_symbols(tokens,function,types,version)!
  mut declarations:=map[int]ShaderDeclaration{}
  for declaration in local_declarations(tokens,function) {
   declarations[declaration.start]=declaration
   normalize_declaration_initializers(tokens,declaration,locals,globals,functions,structures,mut replacements)!
  }
  mut p:=function.body+1
  for p<function.end-1 {
   if declaration:=declarations[p] {p=declaration.end;continue}
   word:=tokens[p]
   if word=='for' && p+1<tokens.len && tokens[p+1]=='(' {
    end:=matching_token(tokens,p+1)!
    mut clauses:=[]int{len:0};clauses << p+2
    mut q:=p+2
    for q<end {if tokens[q] in ['(', '['] {q=matching_token(tokens,q)!};if tokens[q]==';' {clauses << q+1};q++}
    if clauses.len!=3 {return error('Invalid for clauses')}
    for i,begin in clauses {
     finish:=if i<2 {clauses[i+1]-1} else {end}
     if begin==finish {continue}
     if declaration:=declarations[begin] {
      if i>1 || declaration.end!=finish+1 || (i==1 && (declaration.fields.len!=1 || declaration.fields[0].typ!='bool' || !declaration.fields[0].initialized)) {return error('Invalid for declaration')}
      continue
     }
     expr:=expression_type(tokens[begin..finish],begin,locals,globals,functions,structures)!
     if expr.typ!='' && i==1 && expr.typ!='bool' {return error('Invalid for clause type')}
     replacements[begin]=ExpressionReplacement{end:finish,source:expr.source}
    }
    p=end+1;continue
   }
   if word in ['if','while','switch'] && p+1<tokens.len && tokens[p+1]=='(' {
    end:=matching_token(tokens,p+1)!
    if declaration:=declarations[p+2] {
     if word=='switch' || declaration.end!=end+1 || declaration.fields.len!=1 || declaration.fields[0].typ!='bool' || !declaration.fields[0].initialized {return error('Condition declaration must be bool')}
     p=end+1;continue
    }
    expr:=expression_type(tokens[p+2..end],p+2,locals,globals,functions,structures)!
    if expr.typ!='' && ((word!='switch' && expr.typ!='bool') || (word=='switch' && expr.typ !in ['int','uint'])) {return error('Invalid shader condition type')}
    replacements[p+2]=ExpressionReplacement{end:end,source:expr.source};p=end+1;continue
   }
   if word=='return' {
    mut end:=p+1
    for end<function.end && tokens[end]!=';' {if tokens[end] in ['(', '['] {end=matching_token(tokens,end)!};end++}
    if end>p+1 {
     expr:=expression_type(tokens[p+1..end],p+1,locals,globals,functions,structures)!
     if expr.typ!='' && expr.typ!=function.typ {return error('Implicit shader return conversion is forbidden')}
     replacements[p+1]=ExpressionReplacement{end:end,source:expr.source}
    } else if function.typ!='void' {return error('Missing shader return value')}
    p=end+1;continue
   }
   if (p==function.body+1 || tokens[p-1] in ['{','}',';','else',')',':']) && (identifier(word) || word in ['++','--','(']) && word !in ['for','if','while','switch','do','case','default','else','break','continue','discard','const','lowp','mediump','highp'] {
    mut end:=p
    for end<function.end && tokens[end] !in [';','}'] {if tokens[end] in ['(', '['] {end=matching_token(tokens,end)!};end++}
    if end>p && end<function.end && tokens[end]==';' {
     expr:=expression_type(tokens[p..end],p,locals,globals,functions,structures)!
     replacements[p]=ExpressionReplacement{end:end,source:expr.source};p=end+1;continue
    }
   }
   p++
  }
 }
 validate_subscript_coverage(tokens,functions,globals,replacements)!
 mut result:=[]string{}
 mut at:=0
 for at<tokens.len {
  if replacement:=replacements[at] {
   result << lex(replacement.source)!
   at=replacement.end
  } else {result << tokens[at];at++}
 }
 return result
}

fn validate_builtin_arguments(name string,args []ShaderExpression) ! {
 if args.len==0 || args.any(it.typ=='') {return}
 first:=args[0].typ
 scalar:=scalar_of(first)
 floating:=name in ['sin','cos','tan','asin','acos','atan','sinh','cosh','tanh','asinh','acosh','atanh','radians','degrees','pow','exp','exp2','log','log2','sqrt','inversesqrt','floor','trunc','round','roundEven','ceil','fract','mod','modf','frexp','dFdx','dFdy','fwidth']
 if floating && scalar!='float' {return error('Floating-point builtin operand required: '+name)}
 if name in ['min','max','clamp','abs','sign'] && scalar !in ['float','int','uint'] {return error('Numeric builtin operand required: '+name)}
 if name in ['atan','pow'] && args.len==2 && args[0].typ!=args[1].typ {return error('Builtin operand types differ: '+name)}
 if name in ['any','all'] && (!first.starts_with('bvec') || args.len!=1) {return error('Boolean vector builtin operand required')}
 if name in ['equal','notEqual','lessThan','lessThanEqual','greaterThan','greaterThanEqual'] && (args.len!=2 || args[0].typ!=args[1].typ || !is_vector_type(first)) {return error('Matching vector operands required')}
 if name in ['min','max','clamp','mod'] {
  for arg in args[1..] {if arg.typ!=first && !(is_vector_type(first) && arg.typ==scalar) {return error('Builtin operand types differ: '+name)}}
 }
 if name in ['packUnorm2x16','packSnorm2x16','packHalf2x16'] && (args.len!=1 || first!='vec2') {return error('Packing requires vec2')}
 if name in ['unpackUnorm2x16','unpackSnorm2x16','unpackHalf2x16'] && (args.len!=1 || first!='uint') {return error('Unpacking requires uint')}
}
