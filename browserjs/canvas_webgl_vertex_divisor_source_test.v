// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_vertex_divisor_preserves_source_driver_and_conversion_order() {
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
	runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_vertex_divisor",width:1,height:1},"webgl2",null);globalThis.other=__webglContext({bridgeKey:"__created_vertex_divisor_other",width:1,height:1},"webgl2",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);')!
	mut context := host.contexts['__created_vertex_divisor'] or { panic('divisor owner') }
	mut other := host.contexts['__created_vertex_divisor_other'] or { panic('divisor other owner') }
	for divisor in [u32(0), u32(17), u32(0x8000_0000), u32(0xffff_ffff)] {
		context.native.make_current()
		C.vox_gl_vertex_attrib_divisor(2, divisor, 3)
		expected := C.vox_gl_vertex_attrib_parameter(2, webgl.vertex_attrib_array_divisor)
		C.vox_gl_vertex_attrib_divisor(2, 7, 3)
		assert runtime.evaluate_host('gl.vertexAttribDivisor(2,${divisor});gl.getVertexAttrib(2,gl.VERTEX_ATTRIB_ARRAY_DIVISOR)')! == expected.str()
	}
	context.native.make_current()
	C.vox_gl_vertex_attrib_divisor(0xffff_ffff, 1, 3)
	expected_error := C.vox_gl_get_error()
	other.native.make_current()
	runtime.evaluate_host('gl.vertexAttribDivisor(-1,1);')!
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(webgl.viewport, &selected[0])
	assert selected == [i32(1), 2, 3, 4]!
	assert runtime.evaluate_host('gl.getError()')! == expected_error.str()
	other.native.make_current()
	assert runtime.evaluate_host('(function(){const marker={};try{gl.vertexAttribDivisor(2,{valueOf(){throw marker}});return false}catch(error){return error===marker}})()')! == 'true'
	C.vox_gl_int_parameter(webgl.viewport, &selected[0])
	assert selected == [i32(9), 10, 11, 12]!
	assert runtime.evaluate_host('(function(){const order=[];gl.vertexAttribDivisor({valueOf(){order.push("index");return 2}},{valueOf(){order.push("divisor");return 17}});return order.join(",")==="index,divisor"&&gl.getVertexAttrib(2,gl.VERTEX_ATTRIB_ARRAY_DIVISOR)===17&&gl.getError()===gl.NO_ERROR})()')! == 'true'
	assert runtime.evaluate_host('const gl1=__webglContext({bridgeKey:"__created_vertex_divisor_webgl1",width:1,height:1},"webgl",null);typeof gl1.vertexAttribDivisor==="undefined"')! == 'true'
}
