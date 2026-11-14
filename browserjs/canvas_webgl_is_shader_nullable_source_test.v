// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_actual_is_shader_nullable_host_call_reaches_source_false_return_without_driver_selection() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_is_shader_nullable",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_is_shader_nullable_other",width:2,height:2},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);globalThis.shader=gl.createShader(gl.VERTEX_SHADER);')!
		mut other := host.contexts['__created_is_shader_nullable_other'] or { panic('nullable other') }
		for argument in ['null', 'undefined'] {
			other.native.make_current()
			C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
			assert runtime.evaluate_host('gl.isShader(${argument})===false')! == 'true'
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
			assert C.vox_gl_get_error() == webgl.invalid_value
			assert C.vox_gl_get_error() == webgl.no_error
			assert runtime.evaluate_host('gl.getError()===gl.NO_ERROR')! == 'true'
		}
		other.native.make_current()
		assert host.call('{"key":"__created_is_shader_nullable","method":"isShader","args":[null]}')! == 'false'
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert runtime.evaluate_host('gl.isShader(shader)===true')! == 'true'
		assert runtime.evaluate_host('(function(){try{gl.isShader();return false}catch(error){return error instanceof TypeError}})()')! == 'true'
		assert runtime.evaluate_host('(function(){try{gl.isShader(Object.create(WebGLShader.prototype));return false}catch(error){return error instanceof TypeError}})()')! == 'true'
		assert runtime.evaluate_host('gl.getError()===gl.NO_ERROR')! == 'true'
	}
}
