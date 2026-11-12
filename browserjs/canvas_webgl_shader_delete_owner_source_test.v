// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_nullable_shader_delete_preserves_source_early_owner_and_actual_attachment() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_shader_delete",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_shader_delete_other",width:2,height:2},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);globalThis.shader=gl.createShader(gl.VERTEX_SHADER);globalThis.foreign=other.createShader(other.VERTEX_SHADER);globalThis.program=gl.createProgram();gl.attachShader(program,shader);')!
		mut owner := host.contexts['__created_shader_delete'] or { panic('owner deletion') }
		mut other := host.contexts['__created_shader_delete_other'] or { panic('other deletion') }
		mut selected := [i32(0), 0, 0, 0]!
		for argument in ['null', 'undefined', 'foreign'] {
			other.native.make_current()
			runtime.evaluate_host('gl.deleteShader(${argument})')!
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
			expected := if argument == 'foreign' { 'gl.INVALID_OPERATION' } else { 'gl.NO_ERROR' }
			assert runtime.evaluate_host('gl.getError()===${expected}')! == 'true'
		}
		other.native.make_current()
		assert runtime.evaluate_host('(function(){try{gl.deleteShader(Object.create(WebGLShader.prototype));return false}catch(error){return error instanceof TypeError}})()')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		mut native_name := u32(0)
		for _, record in host.shaders {
			if record.object.context_id == owner.identity() {
				native_name = record.object.native_name()
			}
		}
		assert native_name != 0
		other.native.make_current()
		runtime.evaluate_host('gl.deleteShader(shader)')!
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert C.vox_gl_is_object(9, native_name) == 1
		assert C.vox_gl_shader_parameter(native_name, webgl.delete_status) == 1
		assert runtime.evaluate_host('gl.getError()===gl.NO_ERROR&&gl.getAttachedShaders(program)[0]===shader')! == 'true'
		for expression in ['gl.deleteShader(shader)', 'other.deleteShader(shader)'] {
			other.native.make_current()
			runtime.evaluate_host(expression)!
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
			expected := if expression.starts_with('other') {
				'other.getError()===other.INVALID_OPERATION'
			} else {
				'gl.getError()===gl.NO_ERROR'
			}
			assert runtime.evaluate_host(expected)! == 'true'
		}
	}
}
