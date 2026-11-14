// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_vertex_getters_preserve_source_early_returns_and_reply_shapes() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_vertex_getter",width:1,height:1},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_vertex_getter_other",width:1,height:1},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);')!
		mut other := host.contexts['__created_vertex_getter_other'] or { panic('getter other owner') }
		mut early_names := [u32(0xffff)]
		if kind == 'webgl' {
			early_names << u32(webgl.vertex_attrib_array_integer)
			early_names << u32(webgl.vertex_attrib_array_divisor)
		}
		for pname in early_names {
			other.native.make_current()
			assert runtime.evaluate_host('gl.getVertexAttrib(-1,${pname})===null')! == 'true'
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
			assert runtime.evaluate_host('gl.getError()===gl.INVALID_ENUM&&gl.getError()===gl.NO_ERROR')! == 'true'
		}
		other.native.make_current()
		assert runtime.evaluate_host('gl.getVertexAttribOffset(-1,0xffff)===0')! == 'true'
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert runtime.evaluate_host('gl.getError()===gl.INVALID_ENUM')! == 'true'
		runtime.evaluate_host('globalThis.buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);gl.bufferData(gl.ARRAY_BUFFER,64,gl.STATIC_DRAW);gl.vertexAttribPointer(2,2,gl.UNSIGNED_BYTE,true,8,4);gl.enableVertexAttribArray(2);gl.vertexAttrib4f(2,1,2,3,4);')!
		for query in ['gl.getVertexAttrib(2,gl.CURRENT_VERTEX_ATTRIB)',
			'gl.getVertexAttrib(2,gl.VERTEX_ATTRIB_ARRAY_SIZE)',
			'gl.getVertexAttrib(2,gl.VERTEX_ATTRIB_ARRAY_BUFFER_BINDING)',
			'gl.getVertexAttribOffset(2,gl.VERTEX_ATTRIB_ARRAY_POINTER)'] {
			other.native.make_current()
			runtime.evaluate_host(query)!
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
		}
		assert runtime.evaluate_host('(function(){const a=gl.getVertexAttrib(2,gl.CURRENT_VERTEX_ATTRIB),b=gl.getVertexAttrib(2,gl.CURRENT_VERTEX_ATTRIB),x=gl.getVertexAttrib(2,gl.VERTEX_ATTRIB_ARRAY_BUFFER_BINDING),y=gl.getVertexAttrib(2,gl.VERTEX_ATTRIB_ARRAY_BUFFER_BINDING);return a instanceof Float32Array&&a.join(",")==="1,2,3,4"&&a!==b&&a.buffer!==b.buffer&&x instanceof WebGLBuffer&&y instanceof WebGLBuffer&&x!==y&&x!==buffer&&gl.getVertexAttrib(2,gl.VERTEX_ATTRIB_ARRAY_ENABLED)===true&&gl.getVertexAttrib(2,gl.VERTEX_ATTRIB_ARRAY_NORMALIZED)===true&&gl.getVertexAttrib(2,gl.VERTEX_ATTRIB_ARRAY_STRIDE)===8&&gl.getVertexAttribOffset(2,gl.VERTEX_ATTRIB_ARRAY_POINTER)===4&&gl.getError()===gl.NO_ERROR})()')! == 'true'
		other.native.make_current()
		assert runtime.evaluate_host('(function(){const marker={};try{gl.getVertexAttrib(2,{valueOf(){throw marker}});return false}catch(error){return error===marker}})()')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
	}
}
