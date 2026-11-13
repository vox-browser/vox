// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module shader

struct FragmentBuiltins {
 coord bool
 facing bool
 point bool
 depth bool
 data bool
 targets []int
}
fn fragment_builtins(tokens []string, version int, extensions map[string]bool) !FragmentBuiltins {
 data:='gl_FragData' in tokens
 depth:='gl_FragDepth' in tokens || 'gl_FragDepthEXT' in tokens
 if data && (version!=100 || !extensions['GL_EXT_draw_buffers']) {return error('gl_FragData requires the ESSL100 draw-buffers extension')}
 if depth && version==100 && !extensions['GL_EXT_frag_depth'] {return error('Fragment depth requires its ESSL100 extension')}
 if data && 'gl_FragColor' in tokens {return error('gl_FragData and gl_FragColor cannot be mixed')}
 mut targets:=[]int{}
 for i,word in tokens {
  if word!='gl_FragData' {continue}
  if i+2>=tokens.len || tokens[i+1]!='[' {return error('Expected constant fragment output index')}
  mut end:=i+2
  for end<tokens.len && tokens[end]!=']' {end++}
  if end>=tokens.len {return error('Unterminated fragment output index')}
  expression:=tokens[i+2..end]
  if expression.len==0 || expression.len>256 || expression.any(identifier(it)) {return error('Fragment output index must be a resolved integer expression')}
  mut parser:=PPExpression{tokens:expression}
  index:=parser.expression(0,true)!
  if parser.at!=expression.len || index<0 || index>7 {return error('Fragment output index exceeds draw-buffer limits')}
  if int(index) !in targets {targets << int(index)}
 }
 targets.sort()
 return FragmentBuiltins{coord:'gl_FragCoord' in tokens,facing:'gl_FrontFacing' in tokens,point:'gl_PointCoord' in tokens,depth:depth,data:data,targets:targets}
}
fn (builtins FragmentBuiltins) members() []string {
 mut result:=[]string{}
 if builtins.coord {result << 'float4 gl_FragCoord = float4(0.0);'}
 if builtins.facing {result << 'bool gl_FrontFacing = false;'}
 if builtins.point {result << 'float2 gl_PointCoord = float2(0.0);'}
 if builtins.depth {result << 'float gl_FragDepth = 0.0;'}
 if builtins.data {result << 'array<float4,8> gl_FragData = {};'}
 return result
}
fn (builtins FragmentBuiltins) arguments() []string {
 mut result:=[]string{}
 if builtins.coord {result << 'float4 _vox_frag_coord [[position]]'}
 if builtins.facing {result << 'bool _vox_front_facing [[front_facing]]'}
 if builtins.point {result << 'float2 _vox_point_coord [[point_coord]]'}
 return result
}
fn (builtins FragmentBuiltins) loads() []string {
 mut result:=[]string{}
 if builtins.coord {result << 'state.gl_FragCoord = _vox_frag_coord;'}
 if builtins.facing {result << 'state.gl_FrontFacing = _vox_front_facing;'}
 if builtins.point {result << 'state.gl_PointCoord = _vox_point_coord;'}
 return result
}

fn derivative_methods(stage Stage, version int, extensions map[string]bool, tokens []string) []string {
 mut methods:=[]string{}
 if stage!=.fragment || (version==100 && !extensions['GL_OES_standard_derivatives']) {return methods}
 for typ in ['float','float2','float3','float4'] {
  for glsl,msl in {'dFdx':'dfdx','dFdy':'dfdy','fwidth':'fwidth'} {
   if glsl in tokens {methods << '${typ} _vox_${glsl}(${typ} value) {return ${msl}(value);}'}
  }
 }
 return methods
}
