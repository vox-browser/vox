module shader

fn test_unreferenced_resources_do_not_require_runtime_bindings() {
 vertex:=translate_with_bindings('attribute vec2 position;attribute vec4 unused;uniform float never_used;uniform vec4 colors[2];varying vec4 value;void main(){gl_Position=vec4(position,0.0,1.0);value=colors[0];}',.vertex,{'position':5})!
 assert vertex.inputs.map(it.name)==['position']
 assert vertex.inputs[0].location==5
 assert vertex.uniforms.map(it.name)==['colors']
 assert vertex.uniform_roots.map(it.name)==['never_used','colors']
 fragment:=translate('precision mediump float;uniform sampler2D unusedImage;varying vec4 value;void main(){gl_FragColor=value;}',.fragment)!
 assert fragment.textures.len==0 && fragment.texture_roots.len==1
 link(vertex,fragment)!
}

fn test_referenced_roots_in_helpers_are_conservatively_retained() {
 vertex:=translate('uniform vec4 value;vec4 helper(){return value;}void main(){gl_Position=helper();}',.vertex)!
 assert vertex.uniforms.len==1 && vertex.uniforms[0].name=='value'
 unused:=translate('uniform vec4 value;void main(){gl_Position=vec4(1.0);}',.vertex)!
 assert unused.uniforms.len==0 && unused.uniform_buffer_size==0
}

fn test_function_reachability_and_local_shadowing_prune_inactive_roots() {
 result:=translate('attribute vec2 position;uniform vec4 tint;uniform vec4 dead;vec4 unused(){return dead;}vec4 shade(vec4 tint){return tint;}void main(){gl_Position=shade(vec4(position,0.0,1.0));}',.vertex)!
 assert result.inputs.map(it.name)==['position']
 assert result.uniforms.len==0
 assert !result.source.contains('unused(')
 assert result.validation_source.contains('unused(')
 result2:=translate('uniform vec4 tint;vec4 a(){return tint;}vec4 b(){return a();}void main(){gl_Position=b();}',.vertex)!
 assert result2.uniforms.map(it.name)==['tint']
}
