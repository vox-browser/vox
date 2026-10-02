// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn test_public_webgl_domstring_arguments_use_source_string_hint_and_symbol_errors() {
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
	runtime.evaluate_host('const gl=__webglContext(state,"webgl2",{preserveDrawingBuffer:true}),shader=gl.createShader(gl.VERTEX_SHADER);')!
	assert runtime.evaluate_host(r'(function(){const hints=[],source="void main(){gl_Position=vec4(0,0,0,1);}";gl.shaderSource(shader,{[Symbol.toPrimitive](hint){hints.push(hint);return source}});gl.compileShader(shader);return hints.join(",")==="string"&&gl.getShaderSource(shader)===source&&gl.getShaderParameter(shader,gl.COMPILE_STATUS)&&gl.getError()===gl.NO_ERROR})()')! == 'true'
	assert runtime.evaluate_host(r'(function(){const order=[],source="void main(){gl_Position=vec4(1,0,0,1);}";gl.shaderSource(shader,{get toString(){order.push("toString");return function(){order.push("call");return source}},get valueOf(){throw "number hint"}});return order.join(",")==="toString,call"&&gl.getShaderSource(shader)===source&&gl.getError()===gl.NO_ERROR})()')! == 'true'
	assert runtime.evaluate_host(r'(function(){const marker={},calls=[()=>gl.shaderSource(shader,Symbol("source")),()=>gl.getExtension(Symbol("extension")),()=>gl.getUniformIndices(gl.createProgram(),[Symbol("name")])];if(!calls.every(call=>{try{call();return false}catch(error){return error instanceof TypeError}}))return false;try{gl.shaderSource(shader,{toString(){throw marker},valueOf(){throw "later"}});return false}catch(error){return error===marker&&gl.getError()===gl.NO_ERROR}})()')! == 'true'
	assert runtime.evaluate_host(r'(function(){const hints=[],order=[],marker={},names={[Symbol.iterator](){let index=0;return {next(){return index++===0?{done:false,value:{[Symbol.toPrimitive](hint){hints.push(hint);throw marker}}}:{done:true}},return(){order.push("closed");return {done:true}}}}};try{gl.getUniformIndices(gl.createProgram(),names);return false}catch(error){return error===marker&&hints.join(",")==="string"&&order.length===0&&gl.getError()===gl.NO_ERROR}})()')! == 'true'
}
