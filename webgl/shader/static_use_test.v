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
