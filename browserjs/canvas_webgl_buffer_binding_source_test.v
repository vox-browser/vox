// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn test_actual_buffer_binding_preserves_source_owner_target_and_retained_state_order() {
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
	initial := runtime.evaluate_host(r'
 (function(){for(const [kind,key] of [["webgl","__created_binding_one"],["webgl2","__created_binding_two"]]){
 const gl=__webglContext({bridgeKey:key,width:2,height:2},kind,null),other=__webglContext({bridgeKey:key+"_other",width:2,height:2},kind,null),foreign=other.createBuffer(),buffer=gl.createBuffer();
 gl.bindBuffer(0xbad,foreign);if(gl.getError()!==gl.INVALID_OPERATION)return false;
 gl.bindBuffer(0xbad,buffer);if(gl.getError()!==gl.INVALID_ENUM)return false;
 gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER,buffer);if(gl.getError()!==gl.INVALID_OPERATION)return false;
 gl.bindBuffer(gl.ARRAY_BUFFER,buffer);if(gl.getError()!==gl.NO_ERROR||gl.getParameter(gl.ARRAY_BUFFER_BINDING)!==buffer||!gl.isBuffer(buffer))return false;
 globalThis.bindingGL=gl;globalThis.bindingNext=gl.createBuffer();
 }return true})()
 ')!
	assert initial == 'true'
	mut context := host.contexts['__created_binding_two'] or { panic('native binding context') }
	context.native.make_current()
	C.vox_gl_enable(0xbad)
	state := runtime.evaluate_host('bindingGL.bindBuffer(bindingGL.ARRAY_BUFFER,bindingNext);bindingGL.getParameter(bindingGL.ARRAY_BUFFER_BINDING)===bindingNext&&bindingGL.isBuffer(bindingNext)&&bindingGL.getError()===bindingGL.INVALID_ENUM&&bindingGL.getError()===bindingGL.NO_ERROR')!
	assert state == 'true'
}
