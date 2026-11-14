// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_shader_command_source_gates_follow_argument_conversion_before_native_owner() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_shader_command",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_shader_command_other",width:2,height:2},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);globalThis.shader=gl.createShader(gl.VERTEX_SHADER);globalThis.foreign=other.createShader(other.VERTEX_SHADER);other.shaderSource(foreign,"foreign original");')!
		mut other := host.contexts['__created_shader_command_other'] or { panic('other shader command') }
		for expression in ['gl.shaderSource(foreign,"rejected")', 'gl.compileShader(foreign)'] {
			other.native.make_current()
			runtime.evaluate_host(expression)!
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
			assert runtime.evaluate_host('gl.getError()===gl.INVALID_OPERATION')! == 'true'
		}
		other.native.make_current()
		assert runtime.evaluate_host('(function(){let conversions=0;gl.shaderSource(foreign,{toString(){conversions++;other.viewport(9,10,11,12);return "rejected"}});return conversions===1})()')! == 'true'
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert runtime.evaluate_host('gl.getError()===gl.INVALID_OPERATION&&other.getShaderSource(foreign)==="foreign original"&&other.getError()===other.NO_ERROR')! == 'true'
		other.native.make_current()
		assert runtime.evaluate_host('(function(){const marker={};try{gl.shaderSource(foreign,{toString(){throw marker}});return false}catch(error){return error===marker}})()')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		text := if kind == 'webgl2' {
			r'#version 300 es\nvoid main(){gl_Position=vec4(0);}'
		} else {
			'void main(){gl_Position=vec4(0);}'
		}
		for expression in ['gl.shaderSource(shader,"${text}")', 'gl.compileShader(shader)'] {
			other.native.make_current()
			runtime.evaluate_host(expression)!
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
			assert runtime.evaluate_host('gl.getError()===gl.NO_ERROR')! == 'true'
		}
		assert runtime.evaluate_host('gl.getShaderParameter(shader,gl.COMPILE_STATUS)===true')! == 'true'
		runtime.evaluate_host('gl.deleteShader(shader)')!
		for expression in ['gl.shaderSource(shader,"deleted")', 'gl.compileShader(shader)'] {
			other.native.make_current()
			runtime.evaluate_host(expression)!
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
			assert runtime.evaluate_host('gl.getError()===gl.INVALID_OPERATION')! == 'true'
		}
	}
}
