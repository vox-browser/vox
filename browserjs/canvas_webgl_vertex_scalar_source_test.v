// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import math
import webgl

fn test_public_scalar_vertex_attributes_follow_source_float_abi_and_idl_order() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_vertex_scalar",width:1,height:1},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_vertex_scalar_other",width:1,height:1},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);')!
		mut context := host.contexts['__created_vertex_scalar'] or { panic('scalar owner') }
		mut other := host.contexts['__created_vertex_scalar_other'] or { panic('other scalar owner') }
		for components in 1 .. 5 {
			context.native.make_current()
			match components {
				1 { C.vox_gl_vertex_attrib1f(2, f32(math.nan())) }
				2 { C.vox_gl_vertex_attrib2f(2, f32(math.nan()), f32(math.inf(1))) }
				3 {
					C.vox_gl_vertex_attrib3f(2, f32(math.nan()), f32(math.inf(1)), f32(math.inf(-1)))
				}
				else {
					C.vox_gl_vertex_attrib4f(2, f32(math.nan()), f32(math.inf(1)), f32(math.inf(-1)), f32(math.copysign(0, -1)))
				}
			}
			mut expected := [f32(0), 0, 0, 0]!
			C.vox_gl_vertex_attrib_float_parameter(2, &expected[0])
			C.vox_gl_vertex_attrib4f(2, 9, 10, 11, 12)
			other.native.make_current()
			arguments := ['NaN', 'Infinity', '-Infinity', '-0'][..components].join(',')
			runtime.evaluate_host('gl.vertexAttrib${components}f(2,${arguments});')!
			mut actual := [f32(0), 0, 0, 0]!
			C.vox_gl_vertex_attrib_float_parameter(2, &actual[0])
			for slot, value in expected {
				assert actual[slot] == value || (math.is_nan(actual[slot]) && math.is_nan(value))
				if value == 0 {
					assert math.signbit(f64(actual[slot])) == math.signbit(f64(value))
				}
			}
			other.native.make_current()
			assert runtime.evaluate_host('(function(){const marker={};try{gl.vertexAttrib${components}f(2,{valueOf(){throw marker}}${if components > 1 {
				',' + []string{len: components - 1, init: '1'}.join(',')
			} else {
				''
			}});return false}catch(error){return error===marker}})()')! == 'true'
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
		}
		assert runtime.evaluate_host('(function(){const order=[];gl.vertexAttrib4f({valueOf(){order.push("index");return 2}},...[1,2,3,4].map(value=>({valueOf(){order.push(value);return value}})));const a=gl.getVertexAttrib(2,gl.CURRENT_VERTEX_ATTRIB);return order.join(",")==="index,1,2,3,4"&&a instanceof Float32Array&&a.join(",")==="1,2,3,4"&&gl.getError()===gl.NO_ERROR})()')! == 'true'
	}
}
