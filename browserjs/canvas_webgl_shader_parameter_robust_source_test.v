// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn C.glGetShaderivRobustANGLE(u32, u32, int, voidptr, &i32)

fn test_public_shader_parameter_matches_genuine_robust_native_results_and_errors() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_shader_robust",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_shader_robust_other",width:2,height:2},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);globalThis.shader=gl.createShader(gl.VERTEX_SHADER);gl.shaderSource(shader,"this is not a shader");gl.compileShader(shader);')!
		mut owner := host.contexts['__created_shader_robust'] or { panic('robust owner') }
		mut other := host.contexts['__created_shader_robust_other'] or { panic('robust other') }
		mut name := u32(0)
		for _, record in host.shaders { name = record.object.native_name() }
		assert name != 0
		for pname in [webgl.shader_type, webgl.compile_status, webgl.delete_status, u32(0x8b84),
			u32(0xbad)] {
			owner.native.make_current()
			mut expected := i32(0)
			C.glGetShaderivRobustANGLE(name, pname, 1, unsafe { nil }, &expected)
			expected_error := C.vox_gl_get_error()
			other.native.make_current()
			result := runtime.evaluate_host('gl.getShaderParameter(shader,${pname})')!
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
			assert result == if pname == webgl.shader_type {
				expected.str()
			} else if pname in [webgl.compile_status, webgl.delete_status] {
				(expected == 1).str()
			} else {
				'null'
			}
			if expected_error != webgl.no_error {
				assert runtime.evaluate_host('gl.getError()')! == expected_error.str()
			}
			if pname !in [webgl.shader_type, webgl.compile_status, webgl.delete_status] {
				assert runtime.evaluate_host('gl.getError()===gl.INVALID_ENUM')! == 'true'
			}
			assert runtime.evaluate_host('gl.getError()===gl.NO_ERROR')! == 'true'
		}
		owner.native.make_current()
		C.vox_gl_delete_shader(name)
		mut expected := i32(0)
		C.glGetShaderivRobustANGLE(name, webgl.shader_type, 1, unsafe { nil }, &expected)
		expected_error := C.vox_gl_get_error()
		assert expected_error != webgl.no_error
		other.native.make_current()
		assert runtime.evaluate_host('gl.getShaderParameter(shader,gl.SHADER_TYPE)')! == expected.str()
		assert runtime.evaluate_host('gl.getError()')! == expected_error.str()
		assert runtime.evaluate_host('gl.getError()===gl.NO_ERROR')! == 'true'
	}
}
