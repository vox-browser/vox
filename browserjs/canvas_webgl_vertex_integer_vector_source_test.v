// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_integer_vertex_vectors_preserve_source_spans_and_idl_conversion() {
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
	runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_integer_vector",width:1,height:1},"webgl2",null);globalThis.other=__webglContext({bridgeKey:"__created_integer_vector_other",width:1,height:1},"webgl2",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);')!
	mut other := host.contexts['__created_integer_vector_other'] or { panic('integer vector other') }
	for unsigned_call in [false, true] {
		method := if unsigned_call { 'vertexAttribI4uiv' } else { 'vertexAttribI4iv' }
		type_ := if unsigned_call { 'Uint32Array' } else { 'Int32Array' }
		values := if unsigned_call {
			'[0xffffffff,0xfedcba98,0x80000000,-1,13,14]'
		} else {
			'[-2147483648,2147483647,-2000000001,2000000001,13,14]'
		}
		for typed in [false, true] {
			for length in 0 .. 4 {
				short := if typed { 'new ${type_}(${length})' } else { 'Array(${length}).fill(1)' }
				other.native.make_current()
				runtime.evaluate_host('gl.${method}(-1,${short});')!
				mut selected := [i32(0), 0, 0, 0]!
				C.vox_gl_int_parameter(webgl.viewport, &selected[0])
				assert selected == [i32(9), 10, 11, 12]!
				assert runtime.evaluate_host('gl.getError()===gl.INVALID_VALUE&&gl.getError()===gl.NO_ERROR')! == 'true'
			}
			full := if typed { 'new ${type_}(${values})' } else { values }
			runtime.evaluate_host('gl.${method}(2,${full});')!
			if unsigned_call {
				mut actual := [u32(0), 0, 0, 0]!
				C.vox_gl_vertex_attrib_uint_parameter(2, &actual[0])
				assert actual == [u32(0xffff_ffff), 0xfedc_ba98, 0x8000_0000, 0xffff_ffff]!
			} else {
				mut actual := [i32(0), 0, 0, 0]!
				C.vox_gl_vertex_attrib_int_parameter(2, &actual[0])
				assert actual == [i32(-2_147_483_648), 2_147_483_647, -2_000_000_001, 2_000_000_001]!
			}
			assert runtime.evaluate_host('gl.getError()===gl.NO_ERROR')! == 'true'
		}
		other.native.make_current()
		assert runtime.evaluate_host('(function(){const marker={};try{gl.${method}(2,[1,2,3,4,{valueOf(){throw marker}}]);return false}catch(error){return error===marker}})()')! == 'true'
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert runtime.evaluate_host('(function(){const order=[],values={[Symbol.iterator](){order.push("iterator");let index=0;return {next(){if(index===5){order.push("done");return {done:true}}const value=++index;order.push("next"+value);return {done:false,value:{valueOf(){order.push("value"+value);return value}}}}}}};gl.${method}({valueOf(){order.push("index");return 2}},values);return order.join(",")==="index,iterator,next1,value1,next2,value2,next3,value3,next4,value4,next5,value5,done"&&gl.getError()===gl.NO_ERROR})()')! == 'true'
	}
	assert runtime.evaluate_host('const gl1=__webglContext({bridgeKey:"__created_integer_vector_webgl1",width:1,height:1},"webgl",null);typeof gl1.vertexAttribI4iv==="undefined"&&typeof gl1.vertexAttribI4uiv==="undefined"')! == 'true'
}
