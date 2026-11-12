// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_integer_pointer_uses_source_driver_order_and_idl_conversion() {
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
	runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_integer_pointer",width:1,height:1},"webgl2",null);globalThis.other=__webglContext({bridgeKey:"__created_integer_pointer_other",width:1,height:1},"webgl2",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);')!
	mut context := host.contexts['__created_integer_pointer'] or { panic('integer pointer owner') }
	mut other := host.contexts['__created_integer_pointer_other'] or { panic('integer pointer other') }
	context.native.make_current()
	C.vox_gl_vertex_attrib_i_pointer(0, 0, webgl.GLenum(0x1404), -1, 4)
	expected_error := C.vox_gl_get_error()
	other.native.make_current()
	runtime.evaluate_host('gl.vertexAttribIPointer(0,0,gl.INT,-1,4);')!
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(webgl.viewport, &selected[0])
	assert selected == [i32(1), 2, 3, 4]!
	assert runtime.evaluate_host('gl.getError()')! == expected_error.str()
	assert runtime.evaluate_host('(function(){const buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);gl.bufferData(gl.ARRAY_BUFFER,64,gl.STATIC_DRAW);const order=[];gl.vertexAttribIPointer(...[0,2,gl.INT,16,4].map(value=>({valueOf(){order.push(value);return value}})));return order.join(",")==="0,2,5124,16,4"&&gl.getVertexAttrib(0,gl.VERTEX_ATTRIB_ARRAY_INTEGER)===true&&gl.getVertexAttrib(0,gl.VERTEX_ATTRIB_ARRAY_STRIDE)===16&&gl.getVertexAttribOffset(0,gl.VERTEX_ATTRIB_ARRAY_POINTER)===4&&gl.getError()===gl.NO_ERROR})()')! == 'true'
	other.native.make_current()
	assert runtime.evaluate_host('(function(){const marker={};try{gl.vertexAttribIPointer(0,2,gl.INT,0,{valueOf(){throw marker}});return false}catch(error){return error===marker}})()')! == 'true'
	C.vox_gl_int_parameter(webgl.viewport, &selected[0])
	assert selected == [i32(9), 10, 11, 12]!
}
