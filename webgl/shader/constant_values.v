// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module shader

import math
import strconv

struct ConstantScalar {
 kind string
 value f64
}
fn (value ConstantScalar) source() string {
 if value.kind=='bool' {return if value.value!=0 {'true'} else {'false'}}
 if value.kind=='float' {s:=value.value.str();return if s.contains('.') || s.contains('e') {s} else {s+'.0'}}
 return i64(value.value).str()+if value.kind=='uint' {'u'} else {''}
}
struct ConstantParser {
 tokens []string
 constants map[string]ConstantScalar
mut:
 at int
}
fn constant_value(tokens []string, constants map[string]ConstantScalar) !ConstantScalar {
 if tokens.len==0 || tokens.len>256 {return error('Invalid constant expression')}
 mut parser:=ConstantParser{tokens:tokens,constants:constants}
 value:=parser.expression(0,true)!
 if parser.at!=tokens.len {return error('Invalid constant expression')}
 return value
}
fn (mut p ConstantParser) expression(minimum int, evaluate bool) !ConstantScalar {
 if p.at>=p.tokens.len {return error('Missing constant operand')}
 word:=p.tokens[p.at];p.at++
 mut left:=ConstantScalar{}
 if word in ['+','-','!','~'] {
  value:=p.expression(11,evaluate)!
  if word=='!' {
   if value.kind!='bool' {return error('Boolean constant operand required')}
   left=ConstantScalar{kind:'bool',value:if value.value==0 {1.0} else {0.0}}
  } else if word=='~' {
   if value.kind !in ['int','uint'] {return error('Integral constant operand required')}
   left=ConstantScalar{kind:value.kind,value:f64(~i64(value.value))}
  } else {left=ConstantScalar{kind:value.kind,value:if word=='-' {-value.value} else {value.value}}}
 } else if word=='(' {
  left=p.expression(0,evaluate)!
  if p.at>=p.tokens.len || p.tokens[p.at]!=')' {return error('Expected ) in constant expression')};p.at++
 } else if word in ['true','false'] {left=ConstantScalar{kind:'bool',value:if word=='true' {1.0} else {0.0}}}
 else if identifier(word) {
  if p.at<p.tokens.len && p.tokens[p.at]=='(' {
   p.at++
   mut args:=[]ConstantScalar{}
   for p.at<p.tokens.len && p.tokens[p.at]!=')' {
    args << p.expression(0,evaluate)!
    if p.at<p.tokens.len && p.tokens[p.at]==',' {p.at++;continue};break
   }
   if p.at>=p.tokens.len || p.tokens[p.at]!=')' {return error('Expected ) in constant function')};p.at++
   left=constant_function(word,args,evaluate)!
  } else if value:=p.constants[word] {left=value}
  else if value:=essl_builtin_constant(word) {left=ConstantScalar{kind:'int',value:f64(pp_integer(value)!)}}
  else {return error('Nonconstant identifier: '+word)}
 } else if word.contains('.') || word.contains('e') || word.contains('E') {
  number:=if word.ends_with('f') || word.ends_with('F') {word[..word.len-1]} else {word}
  left=ConstantScalar{kind:'float',value:strconv.atof64(number)!}
 } else if word.starts_with('-') && word.len>1 {left=ConstantScalar{kind:'int',value:-f64(pp_integer(word[1..])!)}}
 else {left=ConstantScalar{kind:if word.ends_with('u') || word.ends_with('U') {'uint'} else {'int'},value:f64(pp_integer(word)!)}}
 for p.at<p.tokens.len {
  op:=p.tokens[p.at]
  if op=='?' && minimum==0 {
   if left.kind!='bool' {return error('Conditional expression requires bool')}
   p.at++
   yes:=p.expression(0,evaluate && left.value!=0)!
   if p.at>=p.tokens.len || p.tokens[p.at]!=':' {return error('Expected : in constant expression')};p.at++
   no:=p.expression(0,evaluate && left.value==0)!
   if yes.kind!=no.kind {return error('Conditional constant types differ')}
   left=if left.value!=0 {yes} else {no};continue
  }
  priority:=precedence(op)
  if priority<minimum {break}
  p.at++
  right:=p.expression(priority+1,evaluate && !(op=='&&' && left.value==0) && !(op=='||' && left.value!=0))!
  if left.kind!=right.kind && op !in ['<<','>>'] {return error('Constant operand types differ')}
  if op in ['&&','||'] && left.kind!='bool' {return error('Boolean constant operands required')}
  if op in ['%','&','|','^','<<','>>'] && (left.kind !in ['int','uint'] || right.kind !in ['int','uint']) {return error('Integral constant operands required')}
  a:=left.value;b:=right.value
  mut value:=f64(0)
  mut kind:=left.kind
  match op {
   '+' {value=a+b} '-' {value=a-b} '*' {value=a*b}
   '/' {if b==0 && evaluate {return error('Constant division by zero')};value=if b==0 {0.0} else if kind=='float' {a/b} else {f64(i64(a)/i64(b))}}
   '%' {if b==0 && evaluate {return error('Constant division by zero')};value=if b==0 {0.0} else {f64(i64(a)%i64(b))}}
   '<<','>>' {if b<0 || b>31 {return error('Invalid constant shift')};value=if op=='<<' {f64(i64(a)<<u32(b))} else {f64(i64(a)>>u32(b))}}
   '&' {value=f64(i64(a)&i64(b))} '|' {value=f64(i64(a)|i64(b))} '^' {value=f64(i64(a)^i64(b))}
   else {
    kind='bool'
    condition:=match op {'==' {a==b} '!=' {a!=b} '<' {a<b} '>' {a>b} '<=' {a<=b} '>=' {a>=b} '&&' {a!=0 && b!=0} else {a!=0 || b!=0}}
    value=if condition {1.0} else {0.0}
   }
  }
  left=ConstantScalar{kind:kind,value:if kind=='uint' {f64(u32(i64(value)))} else {value}}
 }
 return left
}
fn constant_function(name string, args []ConstantScalar, evaluate bool) !ConstantScalar {
 if args.len==0 || args.len>3 {return error('Invalid constant function arity')}
 a:=args[0].value
 if name in ['int','uint','bool','float'] && args.len==1 {
  value:=if name=='bool' {if a==0 {0.0} else {1.0}} else if name=='float' {a} else if name=='uint' {f64(u32(i64(a)))} else {f64(i32(i64(a)))}
  return ConstantScalar{kind:name,value:value}
 }
 for arg in args {if arg.kind!=args[0].kind {return error('Constant function types differ')}}
 b:=if args.len>1 {args[1].value} else {0.0}
 c:=if args.len>2 {args[2].value} else {0.0}
 mut value:=f64(0)
 if args.len==1 {
  value=match name {
   'abs' {math.abs(a)} 'sign' {if a<0 {-1.0} else if a>0 {1.0} else {0.0}}
   'ceil' {math.ceil(a)} 'floor' {math.floor(a)} 'trunc' {math.trunc(a)}
   'round' {math.round(a)} 'roundEven' {base:=math.floor(a);fraction:=a-base;if fraction<0.5 {base} else if fraction>0.5 {base+1.0} else if i64(base)%2==0 {base} else {base+1.0}} 'sqrt' {if a<0 && evaluate {return error('Constant square root domain')};math.sqrt(a)}
   'exp' {math.exp(a)} 'exp2' {math.pow(2.0,a)} 'log' {math.log(a)} 'log2' {math.log2(a)}
   'sin' {math.sin(a)} 'cos' {math.cos(a)} 'tan' {math.tan(a)}
   else {return error('Not a scalar constant function: '+name)}
  }
 } else if args.len==2 {
  value=match name {'min' {if a<b {a} else {b}} 'max' {if a>b {a} else {b}} 'pow' {math.pow(a,b)} else {return error('Not a scalar constant function: '+name)}}
 } else if name=='clamp' {value=if a<b {b} else if a>c {c} else {a}}
 else {return error('Not a scalar constant function: '+name)}
 return ConstantScalar{kind:args[0].kind,value:value}
}
