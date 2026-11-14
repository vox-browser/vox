// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_integer_scalar_vertex_attributes_use_source_widths_and_conversion_order() {
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
	runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_vertex_integer_scalar",width:1,height:1},"webgl2",null);globalThis.other=__webglContext({bridgeKey:"__created_vertex_integer_scalar_other",width:1,height:1},"webgl2",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);')!
	mut other := host.contexts['__created_vertex_integer_scalar_other'] or { panic('integer other owner') }
	runtime.evaluate_host('gl.vertexAttribI4i(2,-2147483648,2147483647,-2000000001,2000000001);')!
	mut signed := [i32(0), 0, 0, 0]!
	C.vox_gl_vertex_attrib_int_parameter(2, &signed[0])
	assert signed == [i32(-2_147_483_648), 2_147_483_647, -2_000_000_001, 2_000_000_001]!
	runtime.evaluate_host('gl.vertexAttribI4ui(2,0xffffffff,0xfedcba98,0x80000000,-1);')!
	mut unsigned := [u32(0), 0, 0, 0]!
	C.vox_gl_vertex_attrib_uint_parameter(2, &unsigned[0])
	assert unsigned == [u32(0xffff_ffff), 0xfedc_ba98, 0x8000_0000, 0xffff_ffff]!
	for method in ['vertexAttribI4i', 'vertexAttribI4ui'] {
		other.native.make_current()
		assert runtime.evaluate_host('(function(){const marker={};try{gl.${method}(2,1,2,{valueOf(){throw marker}},4);return false}catch(error){return error===marker}})()')! == 'true'
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert runtime.evaluate_host('(function(){const order=[];gl.${method}(...[2,1,2,3,4].map(value=>({valueOf(){order.push(value);return value}})));return order.join(",")==="2,1,2,3,4"&&gl.getError()===gl.NO_ERROR})()')! == 'true'
	}
	assert runtime.evaluate_host('const gl1=__webglContext({bridgeKey:"__created_vertex_integer_webgl1",width:1,height:1},"webgl",null);typeof gl1.vertexAttribI4i==="undefined"&&typeof gl1.vertexAttribI4ui==="undefined"')! == 'true'
}
