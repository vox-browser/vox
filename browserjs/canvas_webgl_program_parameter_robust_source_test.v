// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn C.glGetProgramivRobustANGLE(u32, u32, int, voidptr, &i32)

fn test_public_program_parameter_matches_exact_robust_driver_values_and_errors() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_program_robust",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_program_robust_other",width:2,height:2},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);globalThis.program=gl.createProgram();')!
		mut owner := host.contexts['__created_program_robust'] or { panic('program robust owner') }
		mut other := host.contexts['__created_program_robust_other'] or { panic('program robust other') }
		mut name := u32(0)
		for _, record in host.programs { name = record.object.native_name() }
		assert name != 0
		owner.native.make_current()
		C.vox_gl_link_program(name)
		assert C.vox_gl_program_parameter(name, u32(0x8b84)) > 1
		for pname in [webgl.attached_shaders, webgl.active_attributes, webgl.active_uniforms,
			webgl.link_status, webgl.delete_status, webgl.validate_status,
			webgl.transform_feedback_buffer_mode, webgl.transform_feedback_varyings,
			webgl.active_uniform_blocks, u32(0x8b84), u32(0xbad)] {
			owner.native.make_current()
			mut expected := i32(0)
			C.glGetProgramivRobustANGLE(name, pname, 1, unsafe { nil }, &expected)
			expected_error := C.vox_gl_get_error()
			other.native.make_current()
			numeric := pname in [webgl.attached_shaders, webgl.active_attributes,
				webgl.active_uniforms] || (kind == 'webgl2' && pname in [
				webgl.transform_feedback_buffer_mode,
				webgl.transform_feedback_varyings,
				webgl.active_uniform_blocks,
			])
			boolean := pname in [webgl.link_status, webgl.delete_status, webgl.validate_status]
			actual := runtime.evaluate_host('gl.getProgramParameter(program,${pname})')!
			assert actual == if numeric {
				expected.str()
			} else if boolean {
				(expected == 1).str()
			} else {
				'null'
			}
			if expected_error != webgl.no_error {
				assert runtime.evaluate_host('gl.getError()')! == expected_error.str()
			}
			if !numeric && !boolean {
				assert runtime.evaluate_host('gl.getError()===gl.INVALID_ENUM')! == 'true'
			}
			assert runtime.evaluate_host('gl.getError()===gl.NO_ERROR')! == 'true'
		}
		owner.native.make_current()
		C.vox_gl_delete_program(name)
		mut expected := i32(0)
		C.glGetProgramivRobustANGLE(name, webgl.link_status, 1, unsafe { nil }, &expected)
		expected_error := C.vox_gl_get_error()
		assert expected_error != webgl.no_error
		other.native.make_current()
		assert runtime.evaluate_host('gl.getProgramParameter(program,gl.LINK_STATUS)')! == (expected == 1).str()
		assert runtime.evaluate_host('gl.getError()')! == expected_error.str()
		assert runtime.evaluate_host('gl.getError()===gl.NO_ERROR')! == 'true'
	}
}
