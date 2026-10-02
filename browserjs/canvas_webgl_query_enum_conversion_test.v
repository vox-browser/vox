// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn test_public_webgl_query_result_shapes_use_once_converted_source_enum() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<canvas></canvas>')
	mut host := CanvasWebGLHost.create(document)
	mut runtime := Runtime.create()
	defer { runtime.close() }
	host.install(mut runtime)!
	key := host.elements.keys().filter(host.elements[it].local_name() == 'canvas')[0]
	runtime.evaluate_host('const __canvases=Object.create(null),state={bridgeKey:"${key}",width:2,height:2};function __canvasFor(s){return __canvases[s.bridgeKey]||(__canvases[s.bridgeKey]={state:s});}function __canvasDimension(s,key){return s[key];}function __element(s){return {__state:s};}')!
	runtime.evaluate_host(webgl_bootstrap())!
	runtime.evaluate_host('const gl=__webglContext(state,"webgl2",{preserveDrawingBuffer:true});')!
	assert runtime.evaluate_host(r'(function(){let converted=0;const enumValue={valueOf(){if(converted++)throw "second enum conversion";return 0x100000000+gl.VIEWPORT}},result=gl.getParameter(enumValue);return converted===1&&result instanceof Int32Array&&result.join(",")==="0,0,2,2"&&gl.getError()===gl.NO_ERROR})()')! == 'true'
	assert runtime.evaluate_host(r'(function(){let converted=0;gl.vertexAttrib4f(0,0.25,0.5,0.75,1);const enumValue={valueOf(){if(converted++)throw "second enum conversion";return 0x100000000+gl.CURRENT_VERTEX_ATTRIB}},result=gl.getVertexAttrib(0,enumValue);return converted===1&&result instanceof Float32Array&&result.join(",")==="0.25,0.5,0.75,1"&&gl.getError()===gl.NO_ERROR})()')! == 'true'
	runtime.evaluate_host(r'const vertex=gl.createShader(gl.VERTEX_SHADER),fragment=gl.createShader(gl.FRAGMENT_SHADER),program=gl.createProgram();gl.shaderSource(vertex,"#version 300 es\nlayout(std140) uniform Block {vec4 position;};void main(){gl_Position=position;}");gl.shaderSource(fragment,"#version 300 es\nprecision mediump float;out vec4 color;void main(){color=vec4(1);}");gl.compileShader(vertex);gl.compileShader(fragment);gl.attachShader(program,vertex);gl.attachShader(program,fragment);gl.linkProgram(program);')!
	assert runtime.evaluate_host(r'(function(){let converted=0;const enumValue={valueOf(){if(converted++)throw "second enum conversion";return 0x100000000+gl.UNIFORM_BLOCK_ACTIVE_UNIFORM_INDICES}},index=gl.getUniformBlockIndex(program,"Block"),result=gl.getActiveUniformBlockParameter(program,index,enumValue),uniform=gl.getUniformIndices(program,["position"]);return gl.getProgramParameter(program,gl.LINK_STATUS)&&converted===1&&result instanceof Uint32Array&&result.length===1&&result[0]===uniform[0]&&gl.getError()===gl.NO_ERROR})()')! == 'true'
}
