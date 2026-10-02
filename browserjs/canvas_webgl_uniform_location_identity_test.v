// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn test_native_uniform_location_wrappers_are_fresh_for_each_successful_source_query() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<canvas></canvas>')
	mut host := CanvasWebGLHost.create(document)
	mut runtime := Runtime.create()
	defer { runtime.close() }
	host.install(mut runtime)!
	runtime.evaluate_host('const __canvases=Object.create(null);function __canvasFor(s){return __canvases[s.bridgeKey]||(__canvases[s.bridgeKey]={state:s});}function __canvasDimension(s,key){return s[key];}function __element(s){return {state:s};}')!
	runtime.evaluate_host(webgl_bootstrap())!
	assert runtime.evaluate_host(r'(function(){const gl=__webglContext({bridgeKey:"__created_location_identity",width:2,height:2},"webgl"),vertex=gl.createShader(gl.VERTEX_SHADER),fragment=gl.createShader(gl.FRAGMENT_SHADER),program=gl.createProgram();gl.shaderSource(vertex,"uniform vec4 position;void main(){gl_Position=position;}");gl.shaderSource(fragment,"precision mediump float;void main(){gl_FragColor=vec4(1);}");gl.compileShader(vertex);gl.compileShader(fragment);gl.attachShader(program,vertex);gl.attachShader(program,fragment);gl.linkProgram(program);gl.useProgram(program);const first=gl.getUniformLocation(program,"position"),second=gl.getUniformLocation(program,"position");if(first===null||second===null||first===second||Object.getPrototypeOf(first)!==WebGLUniformLocation.prototype||Object.getPrototypeOf(first)!==Object.getPrototypeOf(second))return false;gl.uniform4f(first,1,2,3,4);gl.uniform4f(second,4,3,2,1);gl.linkProgram(program);const third=gl.getUniformLocation(program,"position");return third!==null&&third!==first&&third!==second&&gl.getUniformLocation(program,"missing")===null&&gl.getError()===gl.NO_ERROR})()')! == 'true'
}
