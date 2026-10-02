// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn test_native_diagnostic_query_null_results_keep_source_gl_errors_and_identity() {
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
	runtime.evaluate_host(r'const owner=__webglContext({bridgeKey:"__created_diagnostics_owner",width:2,height:2},"webgl"),other=__webglContext({bridgeKey:"__created_diagnostics_other",width:2,height:2},"webgl"),vertex=owner.createShader(owner.VERTEX_SHADER),fragment=owner.createShader(owner.FRAGMENT_SHADER),program=owner.createProgram();')!
	assert runtime.evaluate_host(r'(function(){if(owner.getShaderSource(vertex)!==""||owner.getAttachedShaders(program).length!==0)return false;owner.attachShader(program,vertex);owner.attachShader(program,fragment);const shaders=owner.getAttachedShaders(program);if(shaders.length!==2||shaders[0]!==vertex||shaders[1]!==fragment)return false;for(const [method,value] of [["getAttachedShaders",program],["getProgramInfoLog",program],["getShaderInfoLog",vertex],["getShaderSource",vertex]])if(other[method](value)!==null||other.getError()!==other.INVALID_OPERATION)return false;owner.shaderSource(vertex,"attribute vec2 position;void main(){gl_Position=vec4(position,0,1);}");if(!owner.getShaderSource(vertex).includes("attribute vec2 position"))return false;owner.deleteProgram(program);owner.deleteShader(vertex);for(const [method,value] of [["getAttachedShaders",program],["getProgramInfoLog",program],["getShaderInfoLog",vertex],["getShaderSource",vertex]])if(owner[method](value)!==null||owner.getError()!==owner.INVALID_OPERATION)return false;return owner.getError()===owner.NO_ERROR&&other.getError()===other.NO_ERROR})()')! == 'true'
}
