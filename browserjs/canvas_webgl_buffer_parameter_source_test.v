// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_actual_buffer_parameter_query_returns_source_integer_for_native_binding_errors() {
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
 const gl=__webglContext({bridgeKey:"__created_buffer_parameter",width:2,height:2},"webgl2",null);
 const unbound=gl.getBufferParameter(gl.ARRAY_BUFFER,gl.BUFFER_SIZE),unboundError=gl.getError(),invalidTarget=gl.getBufferParameter(0xbad,gl.BUFFER_USAGE),targetError=gl.getError(),unknown=gl.getBufferParameter(gl.ARRAY_BUFFER,0xbad),unknownError=gl.getError();
 unbound===0&&unboundError===gl.INVALID_OPERATION&&invalidTarget===0&&targetError===gl.INVALID_ENUM&&unknown===null&&unknownError===gl.INVALID_ENUM&&gl.getError()===gl.NO_ERROR;
 ')!
	assert initial == 'true'
	mut context := host.contexts['__created_buffer_parameter'] or { panic('native buffer context') }
	context.native.make_current()
	native_buffer := C.vox_gl_gen_object(0)
	C.vox_gl_bind_buffer(0x8892, native_buffer)
	C.vox_gl_buffer_data(0x8892, 23, unsafe { nil }, 0x88e8)
	actual := runtime.evaluate_host('gl.getBufferParameter(gl.ARRAY_BUFFER,gl.BUFFER_SIZE)===23&&gl.getBufferParameter(gl.ARRAY_BUFFER,gl.BUFFER_USAGE)===gl.DYNAMIC_DRAW&&gl.getError()===gl.NO_ERROR')!
	assert actual == 'true'
	C.vox_gl_delete_object(0, native_buffer)
}

fn test_public_buffer_parameter_source_gate_precedes_actual_driver_selection() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_buffer_parameter_owner",width:1,height:1},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_buffer_parameter_other",width:1,height:1},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);')!
		mut other := host.contexts['__created_buffer_parameter_other'] or { panic('buffer parameter other') }
		other.native.make_current()
		assert runtime.evaluate_host('gl.getBufferParameter(0xbad,0xbad)===null')! == 'true'
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert runtime.evaluate_host('gl.getError()===gl.INVALID_ENUM&&gl.getError()===gl.NO_ERROR')! == 'true'
		other.native.make_current()
		assert runtime.evaluate_host('gl.getBufferParameter(0xbad,gl.BUFFER_SIZE)===0')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert runtime.evaluate_host('gl.getError()===gl.INVALID_ENUM&&gl.getError()===gl.NO_ERROR')! == 'true'
		other.native.make_current()
		assert runtime.evaluate_host('(function(){const marker={};try{gl.getBufferParameter(gl.ARRAY_BUFFER,{valueOf(){throw marker}});return false}catch(error){return error===marker}})()')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
	}
}
