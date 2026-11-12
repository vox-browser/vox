// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_vertex_vectors_preserve_source_short_span_owner_and_idl_sequence_order() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_vertex_vector",width:1,height:1},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_vertex_vector_other",width:1,height:1},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);')!
		mut other := host.contexts['__created_vertex_vector_other'] or { panic('vector other owner') }
		for components in 1 .. 5 {
			for typed in [false, true] {
				other.native.make_current()
				short := if typed {
					'new Float32Array(${components - 1})'
				} else {
					'Array(${components - 1}).fill(1)'
				}
				runtime.evaluate_host('gl.vertexAttrib${components}fv(2,${short});')!
				mut selected := [i32(0), 0, 0, 0]!
				C.vox_gl_int_parameter(webgl.viewport, &selected[0])
				assert selected == [i32(9), 10, 11, 12]!
				assert runtime.evaluate_host('gl.getError()===gl.INVALID_VALUE&&gl.getError()===gl.NO_ERROR')! == 'true'
				full := if typed { 'new Float32Array([1,2,3,4,13,14])' } else { '[1,2,3,4,13,14]' }
				assert runtime.evaluate_host('(function(){gl.vertexAttrib${components}fv(2,${full});const a=gl.getVertexAttrib(2,gl.CURRENT_VERTEX_ATTRIB);return a instanceof Float32Array&&a.slice(0,${components}).join(",")==="${[]string{len: components, init: (index + 1).str()}.join(',')}"&&gl.getError()===gl.NO_ERROR})()')! == 'true'
			}
		}
		assert runtime.evaluate_host('(function(){const order=[],values={[Symbol.iterator](){order.push("iterator");let index=0;return {next(){order.push("next");return index++?{done:true}:{done:false,value:{valueOf(){order.push("value");return 3}}}}}}};gl.vertexAttrib1fv({valueOf(){order.push("index");return 2}},values);return order.join(",")==="index,iterator,next,value,next"&&gl.getVertexAttrib(2,gl.CURRENT_VERTEX_ATTRIB)[0]===3&&gl.getError()===gl.NO_ERROR})()')! == 'true'
	}
}
