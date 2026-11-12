// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module shader

struct Macro {
 body []string
 parameters []string
 function bool
}
struct PPToken {
 text string
 hidden []string
}
struct Conditional {
 parent bool
mut:
 taken bool
 active bool
 seen_else bool
}
struct Preprocessed {
 tokens []string
 version int
}

fn preprocess(source string) !Preprocessed {
 if source.len > 1024*1024 { return error('Shader exceeds the source limit') }
 clean := pp_comments(source.replace('\\\r\n','').replace('\\\n',''))!
 mut macros := {'GL_ES':Macro{body:['1']}, 'GL_FRAGMENT_PRECISION_HIGH':Macro{body:['1']}, '__VERSION__':Macro{body:['100']}}
 mut stack := []Conditional{}
 mut pending := []string{}
 mut output := []string{}
 mut version := 100
 mut seen_code := false
 mut seen_version := false
 // GLSL joins escaped physical lines before interpreting directives.
 logical := clean
 for line in logical.split_into_lines() {
  trimmed := line.trim_space()
  if !trimmed.starts_with('#') { if stack.len == 0 || stack.last().active { pending << lex(line)!; if trimmed.len > 0 { seen_code = true } }; continue }
  if pending.len > 0 { output << pp_expand(pending,macros)!; pending.clear() }
  words := lex(trimmed[1..])!
  if words.len == 0 { continue }
  directive := words[0]
  args := words[1..]
  active := stack.len == 0 || stack.last().active
  if directive in ['if','ifdef','ifndef'] {
   if stack.len >= 64 { return error('Preprocessor nesting limit exceeded') }
   mut condition := false
   if directive in ['ifdef','ifndef'] {
    if args.len != 1 || !identifier(args[0]) { return error('Expected a macro name') }
    condition = args[0] in macros
    if directive == 'ifndef' { condition = !condition }
   } else if active { condition = pp_condition(args,macros)! }
   stack << Conditional{parent:active,taken:active && condition,active:active && condition}
   continue
  }
  if directive in ['else','elif','endif'] {
   if stack.len == 0 { return error('Unmatched #${directive}') }
   mut frame := stack[stack.len-1]
   if directive == 'endif' {
    if args.len != 0 { return error('Tokens after #endif') }
    stack.delete_last(); continue
   }
   if frame.seen_else { return error('Branch after #else') }
   if directive == 'else' {
    if args.len != 0 { return error('Tokens after #else') }
    frame.active = frame.parent && !frame.taken
    frame.seen_else = true
   } else {
    if args.len == 0 { return error('Missing #elif expression') }
    frame.active = if frame.parent && !frame.taken { pp_condition(args,macros)! } else { false }
   }
   frame.taken = frame.taken || frame.active
   stack[stack.len-1] = frame
   continue
  }
  if !active { continue }
  match directive {
   'version' {
    if seen_code || seen_version || stack.len > 0 { return error('#version must precede shader code') }
    if args == ['300','es'] { version = 300 } else if args != ['100'] { return error('Expected ESSL 100 or 300 es') }
    macros['__VERSION__'] = Macro{body:[version.str()]}
    seen_version = true
   }
   'define' {
    seen_code = true
    if args.len == 0 || !identifier(args[0]) || args[0].starts_with('GL_') || args[0].contains('__') { return error('Invalid macro name') }
    name := args[0]
    // A function macro requires '(' immediately after its name.
    tail := trimmed[1..].trim_space()['define'.len..].trim_left(' \t')
    function := tail.len > name.len && tail[name.len] == `(`
    mut parameters := []string{}
    mut begin := 1
    if function {
     begin = 2
     for begin < args.len && args[begin] != ')' {
      if !identifier(args[begin]) || args[begin] in parameters { return error('Invalid macro parameter') }
      parameters << args[begin]; begin++
      if begin < args.len && args[begin] == ')' { break }
      if begin >= args.len || args[begin] != ',' { return error('Expected macro parameter separator') }
      begin++
      if begin >= args.len || args[begin] == ')' { return error('Missing macro parameter') }
     }
     if begin >= args.len { return error('Unterminated macro parameters') }
     begin++
    }
    body := args[begin..].clone()
    if '#' in body { return error('ESSL does not support token pasting or stringification') }
    definition := Macro{body:body,parameters:parameters,function:function}
    if old := macros[name] { if old.body != body || old.parameters != parameters || old.function != function { return error('Conflicting macro redefinition') } }
    macros[name] = definition
   }
   'undef' {
    seen_code = true
    if args.len != 1 || args[0].starts_with('GL_') || args[0].contains('__') { return error('Invalid #undef') }
    macros.delete(args[0])
   }
   'error' { return error('Shader #error: '+args.join(' ')) }
   else { return error('Unsupported shader directive: #${directive}') }
  }
 }
 if stack.len != 0 { return error('Unterminated conditional directive') }
 output << pp_expand(pending,macros)!
 return Preprocessed{tokens:output,version:version}
}

fn pp_comments(source string) !string {
 for c in source { if c == 0 { return error('NUL in shader source') } }
 mut bytes := source.bytes()
 mut i := 0
 for i < bytes.len {
  if bytes[i] == 0 { return error('NUL in shader source') }
  if i+1 < bytes.len && bytes[i] == `/` && bytes[i+1] == `/` {
   for i < bytes.len && bytes[i] != `\n` { bytes[i] = ` `; i++ }
  } else if i+1 < bytes.len && bytes[i] == `/` && bytes[i+1] == `*` {
   bytes[i] = ` `; bytes[i+1] = ` `; i += 2
   for i+1 < bytes.len && !(bytes[i] == `*` && bytes[i+1] == `/`) { if bytes[i] !in [`\n`,`\r`] { bytes[i] = ` ` }; i++ }
   if i+1 >= bytes.len { return error('Unterminated shader comment') }
   bytes[i] = ` `; bytes[i+1] = ` `; i += 2
  } else { i++ }
 }
 return bytes.bytestr()
}

fn pp_expand(input []string, macros map[string]Macro) ![]string {
 return pp_expand_depth(input,macros,0)
}
fn pp_expand_depth(input []string, macros map[string]Macro, nesting int) ![]string {
 if nesting > 64 { return error('Macro nesting limit exceeded') }
 mut tokens := input.map(PPToken{text:it})
 mut at := 0
 mut steps := 0
 for at < tokens.len {
  steps++
  if steps > 100000 || tokens.len > 100000 { return error('Macro expansion limit exceeded') }
  token := tokens[at]
  definition := macros[token.text] or { at++; continue }
  if token.text in token.hidden { at++; continue }
  mut end := at+1
  mut macro_args := [][]string{}
  if definition.function {
   if end >= tokens.len || tokens[end].text != '(' { at++; continue }
   end++
   mut argument := []string{}
   mut depth := 0
   for end < tokens.len {
    word := tokens[end].text
    if word == ')' && depth == 0 { if argument.len > 0 || definition.parameters.len > 0 { macro_args << argument.clone() }; break }
    if word == ',' && depth == 0 { macro_args << argument.clone(); argument.clear() }
    else { argument << word; if word == '(' { depth++ }; if word == ')' { depth-- } }
    end++
   }
   if end >= tokens.len || macro_args.len != definition.parameters.len { return error('Invalid macro_args for macro ${token.text}') }
   end++
  }
  mut replacement := []PPToken{}
  mut hidden := token.hidden.clone()
  hidden << token.text
  for word in definition.body {
   parameter := definition.parameters.index(word)
   expanded := if parameter >= 0 { pp_expand_depth(macro_args[parameter],macros,nesting+1)! } else { [word] }
   for value in expanded { replacement << PPToken{text:value,hidden:hidden.clone()} }
  }
  tokens.delete_many(at,end-at)
  tokens.insert(at,replacement)
 }
 return tokens.map(it.text)
}

fn pp_condition(input []string, macros map[string]Macro) !bool {
 mut defined := []string{}
 mut at := 0
 for at < input.len {
  if input[at] != 'defined' { defined << input[at]; at++; continue }
  at++
  parenthesized := at < input.len && input[at] == '('
  if parenthesized { at++ }
  if at >= input.len || !identifier(input[at]) { return error('Expected defined macro name') }
  defined << if input[at] in macros {'1'} else {'0'}
  at++
  if parenthesized { if at >= input.len || input[at] != ')' { return error('Expected ) after defined') }; at++ }
 }
 expanded := pp_expand(defined,macros)!
 if expanded.len > 256 { return error('Preprocessor expression limit exceeded') }
 mut parser := PPExpression{tokens:expanded}
 value := parser.expression(0,true)!
 if parser.at != expanded.len { return error('Invalid preprocessor expression') }
 return value != 0
}

struct PPExpression {
 tokens []string
mut:
 at int
}
fn precedence(op string) int {
 return match op { '||' {1} '&&' {2} '|' {3} '^' {4} '&' {5} '==','!=' {6} '<','>','<=','>=' {7} '<<','>>' {8} '+','-' {9} '*','/','%' {10} else {-1} }
}
fn (mut p PPExpression) expression(minimum int, evaluate bool) !i64 {
 if p.at >= p.tokens.len { return error('Missing preprocessor operand') }
 word := p.tokens[p.at]; p.at++
 mut left := i64(0)
 if word in ['!','~','+','-'] {
  value := p.expression(11,evaluate)!
  left = match word { '!' {if value == 0 {i64(1)} else {i64(0)}} '~' {~value} '-' {-value} else {value} }
 } else if word == '(' {
  left = p.expression(0,evaluate)!
  if p.at >= p.tokens.len || p.tokens[p.at] != ')' { return error('Expected ) in preprocessor expression') }; p.at++
 } else if identifier(word) { left = 0 }
 else { left = pp_integer(word)! }
 for p.at < p.tokens.len {
  op := p.tokens[p.at]
  priority := precedence(op)
  if priority < minimum { break }
  p.at++
  rhs_evaluate := evaluate && !(op == '&&' && left == 0) && !(op == '||' && left != 0)
  right := p.expression(priority+1,rhs_evaluate)!
  if !evaluate { left = 0; continue }
  left = match op {
   '+' {left+right} '-' {left-right} '*' {left*right}
   '/' {if right == 0 {return error('Division by zero in #if')}; if left == min_i64 && right == -1 {return error('Overflow in #if')}; left/right}
   '%' {if right == 0 {return error('Division by zero in #if')}; if left == min_i64 && right == -1 {i64(0)} else {left%right}}
   '<<','>>' {if right < 0 || right > 63 {return error('Invalid shift in #if')}; if op == '<<' {i64(u64(left) << u32(right))} else {left >> u32(right)}}
   '&' {left & right} '|' {left | right} '^' {left ^ right}
   else { comparison := match op { '==' {left==right} '!=' {left!=right} '<' {left<right} '>' {left>right} '<=' {left<=right} '>=' {left>=right} '&&' {left!=0 && right!=0} else {left!=0 || right!=0} }; if comparison {i64(1)} else {i64(0)} }
  }
 }
 return left
}
fn pp_integer(word string) !i64 {
 mut number := word
 if number.ends_with('u') || number.ends_with('U') { number = number[..number.len-1] }
 mut base := 10
 if number.starts_with('0x') || number.starts_with('0X') { base = 16; number = number[2..] }
 else if number.len > 1 && number[0] == `0` { base = 8 }
 if number.len == 0 { return error('Invalid integer in #if') }
 mut value := u64(0)
 for c in number.to_lower() {
  digit := if c >= `0` && c <= `9` {int(c-`0`)} else if c >= `a` && c <= `f` {int(c-`a`)+10} else {-1}
  if digit < 0 || digit >= base || value > (u64(max_i64)-u64(digit))/u64(base) { return error('Invalid integer in #if') }
  value = value*u64(base)+u64(digit)
 }
 return i64(value)
}
