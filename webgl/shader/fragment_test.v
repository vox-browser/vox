module shader

fn test_draw_buffers_require_extension_and_emit_only_selected_targets() {
 source:='#extension GL_EXT_draw_buffers : require\nprecision mediump float;void main(){gl_FragData[0]=vec4(1.0);gl_FragData[1+1]=vec4(0.0);}'
 result:=translate(source,.fragment)!
 assert result.source.contains('[[color(0)]]') && result.source.contains('[[color(2)]]')
 assert !result.source.contains('[[color(1)]]')
 for invalid in ['precision mediump float;void main(){gl_FragData[0]=vec4(1.0);}',source.replace('[1+1]','[8]'),source.replace('[1+1]','[unknown]'),source.replace('gl_FragData[0]','gl_FragColor')] {
  translate(invalid,.fragment) or {continue}
  assert false,invalid
 }
}

fn test_fragment_builtin_arguments_and_depth_output_are_explicit() {
 result:=translate('#version 300 es\nprecision highp float;out vec4 color;void main(){gl_FragDepth=0.25;color=gl_FrontFacing?gl_FragCoord:vec4(gl_PointCoord,0.0,1.0);}',.fragment)!
 assert result.source.contains('[[position]]') && result.source.contains('[[front_facing]]') && result.source.contains('[[point_coord]]')
 assert result.source.contains('[[depth(any)]]')
 legacy:=translate('#extension GL_EXT_frag_depth : enable\nprecision highp float;void main(){gl_FragDepthEXT=0.5;gl_FragColor=vec4(1.0);}',.fragment)!
 assert legacy.source.contains('state.gl_FragDepth')
}
