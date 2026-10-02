// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn test_public_webgl_uniform_reflection_null_undefined_and_empty_arrays() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<canvas></canvas><canvas></canvas>')
	mut host := CanvasWebGLHost.create(document)
	mut runtime := Runtime.create()
	defer { runtime.close() }
	host.install(mut runtime)!
	keys := host.elements.keys().filter(host.elements[it].local_name() == 'canvas').sorted()
	runtime.evaluate_host('const __canvases=Object.create(null),first={bridgeKey:"${keys[0]}",width:2,height:2},second={bridgeKey:"${keys[1]}",width:2,height:2};function __canvasFor(s){return __canvases[s.bridgeKey]||(__canvases[s.bridgeKey]={state:s});}function __canvasDimension(s,key){return s[key];}function __element(s){return {__state:s};}')!
	runtime.evaluate_host(webgl_bootstrap())!
	runtime.evaluate_host(r'const gl=__webglContext(first,"webgl2"),other=__webglContext(second,"webgl2");const vertex=gl.createShader(gl.VERTEX_SHADER),fragment=gl.createShader(gl.FRAGMENT_SHADER);gl.shaderSource(vertex,"#version 300 es\nvoid main(){gl_Position=vec4(0.0);}");gl.shaderSource(fragment,"#version 300 es\nprecision mediump float;uniform vec4 tint;out vec4 color;void main(){color=tint;}");gl.compileShader(vertex);gl.compileShader(fragment);const program=gl.createProgram();gl.attachShader(program,vertex);gl.attachShader(program,fragment);gl.linkProgram(program);')!
	assert runtime.evaluate_host('gl.getProgramParameter(program,gl.LINK_STATUS)')! == 'true'
	assert runtime.evaluate_host('Array.isArray(gl.getUniformIndices(program,[]))&&gl.getUniformIndices(program,[]).length===0&&other.getUniformIndices(program,["tint"])===null&&other.getError()===other.INVALID_OPERATION')! == 'true'
	assert runtime.evaluate_host('other.getActiveUniforms(program,[],other.UNIFORM_TYPE)===undefined&&other.getError()===other.INVALID_OPERATION')! == 'true'
	assert runtime.evaluate_host('Array.isArray(gl.getActiveUniforms(program,[],0xdead))&&gl.getActiveUniforms(program,[],0xdead).length===0&&gl.getError()===gl.INVALID_ENUM')! == 'true'
	assert runtime.evaluate_host('const index=gl.getUniformIndices(program,["tint"]);gl.getActiveUniforms(program,index,0xdead)===null&&gl.getError()===gl.INVALID_ENUM&&gl.getError()===gl.INVALID_ENUM&&gl.getError()===gl.NO_ERROR')! == 'true'
	assert runtime.evaluate_host('gl.deleteProgram(program);gl.getUniformIndices(program,[])===null&&gl.getError()===gl.INVALID_OPERATION&&gl.getActiveUniforms(program,[],gl.UNIFORM_TYPE)===undefined&&gl.getError()===gl.INVALID_OPERATION')! == 'true'
}
