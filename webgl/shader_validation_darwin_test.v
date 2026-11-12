module webgl

import webgl.metal as mtl_validation

fn essl_validation(source string, fragment bool, version int) bool {
 mut target:=mtl_validation.DrawingBuffer.create(1,1) or {return false}
 defer {target.close()}
 mtl_validation.validate_shader(target,source,fragment,if version==300 {3} else {2}) or {return false}
 return true
}

fn test_essl_validation_rejects_desktop_only_syntax_and_missing_precision() {
	assert !essl_validation('void main(){int x=1;gl_Position=vec4(float(x << 1));}', false, 100)
	assert !essl_validation('uniform int n;void main(){float x=0.0;for(int i=0;i<n;i++){x+=1.0;}gl_Position=vec4(x);}', false, 100)
	assert !essl_validation('#version 300 es\nout vec4 color;void main(){color=vec4(1.0);}', true, 300)
	assert essl_validation('#version 300 es\nvoid main(){int x=1;gl_Position=vec4(float(x << 1));}', false, 300)
	assert essl_validation('#version 300 es\nuniform int n;void main(){float x=0.0;for(int i=0;i<n;i++){x+=1.0;}gl_Position=vec4(x);}', false, 300)
}

fn test_essl_validation_keeps_legal_sampler_names_and_preprocessor_branches() {
	assert essl_validation('precision mediump float;uniform sampler2D texture;void main(){gl_FragColor=texture2D(texture,vec2(0.5));}', true, 100)
	assert essl_validation('void main(){float x=0.0;for(int i=0;i<4;i++){x+=1.0;}gl_Position=vec4(x);}', false, 100)
	assert essl_validation('precision mediump float;\n#if 0\ndouble x;\n#endif\nvoid main(){gl_FragColor=vec4(1.0);}', true, 100)
	assert !essl_validation('precision mediump float;void main(){gl_FragColor=vec4(1.0) }', true, 100)
}
