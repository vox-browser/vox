// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_vertex_pointer_retained_slot_gate_precedes_gl_and_idl_precedes_source() {
	$if !darwin {
		return
	}
	for kind in ['webgl', 'webgl2'] {
		mut document := html.parse_document('<canvas></canvas>')
		mut host := CanvasWebGLHost.create(document)
		mut runtime := Runtime.create()
		defer { runtime.close() }
		host.install(mut runtime)!
		runtime.evaluate_host('const __canvases=Object.create(null);function __canvasFor(s){return __canvases[s.bridgeKey]||(__canvases[s.bridgeKey]={state:s});}function __canvasDimension(s,key){return s[key];}function __element(s){return {state:s};}')!
		runtime.evaluate_host(webgl_bootstrap())!
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_vertex_pointer",width:1,height:1},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_vertex_pointer_other",width:1,height:1},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);')!
		mut context := host.contexts['__created_vertex_pointer'] or { panic('pointer owner') }
		mut other := host.contexts['__created_vertex_pointer_other'] or { panic('pointer other owner') }
		other.native.make_current()
		runtime.evaluate_host('gl.vertexAttribPointer(0,0,gl.FLOAT,false,-1,4);')!
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert runtime.evaluate_host('gl.getError()===gl.INVALID_OPERATION')! == 'true'
		context.native.make_current()
		C.vox_gl_vertex_attrib_pointer(0, 0, webgl.gl_float, 0, -1, 0)
		expected_error := C.vox_gl_get_error()
		other.native.make_current()
		runtime.evaluate_host('gl.vertexAttribPointer(0,0,gl.FLOAT,false,-1,0);')!
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert runtime.evaluate_host('gl.getError()')! == expected_error.str()
		assert runtime.evaluate_host('(function(){const order=[],buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);gl.bufferData(gl.ARRAY_BUFFER,32,gl.STATIC_DRAW);let booleanHook=0;gl.vertexAttribPointer({valueOf(){order.push("index");return 0}},{valueOf(){order.push("size");return 2}},{valueOf(){order.push("type");return gl.UNSIGNED_BYTE}},{valueOf(){booleanHook++;throw 1}},{valueOf(){order.push("stride");return 4}},{valueOf(){order.push("offset");return 2}});return order.join(",")==="index,size,type,stride,offset"&&booleanHook===0&&gl.getVertexAttrib(0,gl.VERTEX_ATTRIB_ARRAY_SIZE)===2&&gl.getVertexAttrib(0,gl.VERTEX_ATTRIB_ARRAY_NORMALIZED)===true&&gl.getVertexAttribOffset(0,gl.VERTEX_ATTRIB_ARRAY_POINTER)===2&&gl.getError()===gl.NO_ERROR})()')! == 'true'
		other.native.make_current()
		assert runtime.evaluate_host('(function(){const marker={};try{gl.vertexAttribPointer(0,2,gl.FLOAT,false,0,{valueOf(){throw marker}});return false}catch(error){return error===marker}})()')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
	}
}
