// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn test_native_program_bindings_preserve_source_retained_state_after_gl_rejection() {
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
	assert runtime.evaluate_host(r'(function(){const gl=__webglContext({bridgeKey:"__created_program_order",width:2,height:2},"webgl"),program=gl.createProgram(),vertex=gl.createShader(gl.VERTEX_SHADER),other=gl.createShader(gl.VERTEX_SHADER);gl.attachShader(program,vertex);gl.detachShader(program,other);if(gl.getError()!==gl.INVALID_OPERATION||gl.getAttachedShaders(program).length!==0||gl.getProgramParameter(program,gl.ATTACHED_SHADERS)!==1)return false;gl.detachShader(program,vertex);if(gl.getError()!==gl.NO_ERROR||gl.getProgramParameter(program,gl.ATTACHED_SHADERS)!==0)return false;gl.useProgram(program);if(gl.getError()!==gl.INVALID_OPERATION||gl.getParameter(gl.CURRENT_PROGRAM)!==program)return false;gl.useProgram(null);return gl.getError()===gl.NO_ERROR&&gl.getParameter(gl.CURRENT_PROGRAM)===null})()')! == 'true'
}
