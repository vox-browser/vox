module shader

fn test_macro_expansion_rescans_aliases_and_keeps_recursive_names_finite() {
 processed := preprocess('#define A B\n#define B A\n#define ID(x) x\n#define ALIAS ID\nA ID(ID(3)) ALIAS(4) ID(5)')!
 assert processed.tokens == ['A','3','4','5']
 assert preprocess('#define F(x,y) x+y\nF(vec2(1,2),3)')!.tokens == ['vec2','(','1',',','2',')','+','3']
 assert preprocess('#define EMPTY()\nEMPTY() 1')!.tokens == ['1']
 assert preprocess('#define OBJ (1)\nOBJ')!.tokens == ['(','1',')']
 assert preprocess('#define N 2\nN\n#undef N\nN')!.tokens == ['2','N']
}

fn test_conditionals_expand_macros_defined_and_integer_precedence() {
 result := preprocess('#version 300 es\n#define V 2\n#if defined(V) && (__VERSION__ >= 300) && GL_ES\nyes\n#if 0\n#error dead\n#elif V * 3 + 1 == 7\nnested\n#else\nwrong\n#endif\n#elif 1\nwrong\n#endif')!
 assert result.version == 300
 assert result.tokens == ['yes','nested']
 for expression in ['1 || (1/0)', '0 && (1/0) || 1', '010 == 8 && 0x10 == 16', '(1 << 3) == 8', '~0 == -1', 'UNDEFINED == 0', '!defined(MISSING)', '7 % 3 == 1', '(5 & 3) == 1 && (4 | 1) == 5 && (5 ^ 1) == 4'] {
  assert preprocess('#if '+expression+'\nyes\n#else\nno\n#endif')!.tokens == ['yes'],expression
 }
 assert preprocess('#if 0\n#if bad(/\n#error ignored\n#endif\n#else\ncorrect\n#endif')!.tokens == ['correct']
}

fn test_directives_and_comments_reject_malformed_active_input() {
 for source in ['#if 1\n', '#else', '#endif', '#if 1\n#else\n#else\n#endif', '#if 1\n#else\n#elif 1\n#endif', '#if 1/0\n#endif', '#if 1 << 64\n#endif', '#if 09\n#endif', '#if 1.5\n#endif', '#if defined()\n#endif', '#define F(x,) x', '#define F(x,x) x', '#define F(x) x\nF(1,2)', '#define A 1\n#define A 2', '#define GL_ES 0', '#undef __VERSION__', '#define F(x) x ## x', '#error broken', '#include <a>', '#version 300', 'void main(){}\n#version 300 es', '/*\x00*/', '/*unterminated'] {
  preprocess(source) or { continue }
  assert false,source
 }
 assert preprocess('/* #error no */\n#define VALUE \\\n2 // hi\nVALUE')!.tokens == ['2']
}

fn test_macro_expansion_limits_are_reported_as_errors() {
 mut source := '#define A0 x\n'
 for i in 1..18 { source += '#define A${i} A${i-1} A${i-1}\n' }
 preprocess(source+'A17') or { assert err.msg().contains('limit'); return }
 assert false
}

fn test_macro_expanded_shader_uses_only_the_selected_essl_branch() {
 vertex := translate('#version 300 es\n#define POSITION gl_Position\n#define V(x) vec4(x)\n#if __VERSION__ < 300\ndouble invalid;\n#else\nvoid main(){POSITION=V(1.0);}\n#endif',.vertex)!
 assert vertex.version == 300
 fragment := translate('#version 300 es\n#if GL_ES\n#define FP mediump\nprecision FP float;\n#endif\nout vec4 color;\n#define SET(c) color=c\nvoid main(){SET(vec4(1.0));}',.fragment)!
 link(vertex,fragment)!
}

fn test_line_file_macros_and_ternary_conditions_preserve_locations() {
 result:=preprocess('#version 300 es\n#define HERE __LINE__\nHERE\n#line 40 7\nHERE __FILE__\n#if __LINE__ == 41 && (0 ? (1/0) : 2) == 2\nyes\n#endif\n#pragma optimize(off)\n#pragma debug(on)\n#pragma vendor_extension\n')!
 assert result.tokens==['3','40','7','yes']
 assert preprocess('#define HERE __LINE__\nHERE\nHERE')!.tokens==['2','3']
 assert preprocess('#define ID(x) x\nID(\n__LINE__\n)')!.tokens==['3']
 assert preprocess('#define A \\\n2\n__LINE__')!.tokens==['3']
 for source in ['#line -1','#line 2 0 8','#pragma debug(maybe)','#version 300 es\n#if UNKNOWN\n#endif'] {
  preprocess(source) or {continue}
  assert false,source
 }
}

fn test_unknown_optional_directives_do_not_disable_other_preprocessing() {
 result:=preprocess('#version 300 es\n#pragma vendor_unknown "ignored text"\n#extension GL_vendor_unknown : enable\nvoid main(){}')!
 assert result.tokens==['void','main','(',')','{','}']
 preprocess('#pragma debug(off)\n#version 300 es') or {return}
 assert false
}
