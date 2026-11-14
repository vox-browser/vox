// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_shader_parameter_conversion_and_source_handle_gate_precede_sync_owner() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_shader_parameter",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_shader_parameter_other",width:2,height:2},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);globalThis.shader=gl.createShader(gl.VERTEX_SHADER);globalThis.foreign=other.createShader(other.VERTEX_SHADER);')!
		mut other := host.contexts['__created_shader_parameter_other'] or { panic('other shader parameter') }
		mut selected := [i32(0), 0, 0, 0]!
		other.native.make_current()
		assert runtime.evaluate_host('(function(){let conversions=0;const result=gl.getShaderParameter(foreign,{valueOf(){conversions++;other.viewport(9,10,11,12);return 0xbad}});return result===null&&conversions===1})()')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert runtime.evaluate_host('gl.getError()===gl.INVALID_OPERATION&&gl.getError()===gl.NO_ERROR')! == 'true'
		other.native.make_current()
		assert runtime.evaluate_host('(function(){const marker={};try{gl.getShaderParameter(shader,{valueOf(){throw marker}});return false}catch(error){return error===marker}})()')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		other.native.make_current()
		assert runtime.evaluate_host('(function(){let conversions=0;try{gl.getShaderParameter(Object.create(WebGLShader.prototype),{valueOf(){conversions++;return gl.SHADER_TYPE}});return false}catch(error){return error instanceof TypeError&&conversions===0}})()')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		other.native.make_current()
		assert runtime.evaluate_host('(function(){let conversions=0;const result=gl.getShaderParameter(shader,{valueOf(){conversions++;other.viewport(9,10,11,12);return gl.COMPILE_STATUS}});return result===false&&conversions===1})()')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		other.native.make_current()
		assert runtime.evaluate_host('gl.getShaderParameter(shader,0xbad)===null')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert runtime.evaluate_host('gl.getError()===gl.INVALID_ENUM&&gl.getError()===gl.INVALID_ENUM&&gl.getError()===gl.NO_ERROR')! == 'true'
		runtime.evaluate_host('gl.deleteShader(shader)')!
		other.native.make_current()
		assert runtime.evaluate_host('gl.getShaderParameter(shader,0xbad)===null')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert runtime.evaluate_host('gl.getError()===gl.INVALID_OPERATION')! == 'true'
	}
}
