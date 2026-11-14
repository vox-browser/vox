// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_renderbuffer_getter_preserves_source_name_gate_and_driver_results() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_renderbuffer_getter",width:1,height:1},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_renderbuffer_getter_other",width:1,height:1},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);')!
		mut context := host.contexts['__created_renderbuffer_getter'] or { panic('renderbuffer getter owner') }
		mut other := host.contexts['__created_renderbuffer_getter_other'] or { panic('renderbuffer getter other') }
		other.native.make_current()
		assert runtime.evaluate_host('gl.getRenderbufferParameter(0xffff,0xffff)===null')! == 'true'
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert runtime.evaluate_host('gl.getError()===gl.INVALID_ENUM&&gl.getError()===gl.NO_ERROR')! == 'true'
		context.native.make_current()
		native_buffer := C.vox_gl_gen_object(2)
		C.vox_gl_bind_renderbuffer(webgl.renderbuffer, native_buffer)
		C.vox_gl_renderbuffer_storage(webgl.renderbuffer, 0x8056, 5, 7)
		for target in [u32(webgl.renderbuffer), u32(0xffff)] {
			for pname in [u32(0x8d42), 0x8d43, 0x8d44, 0x8d50, 0x8d51, 0x8d52, 0x8d53, 0x8d54,
				0x8cab, 0x8d55] {
				context.native.make_current()
				expected := C.vox_gl_renderbuffer_parameter(target, pname)
				expected_error := C.vox_gl_get_error()
				other.native.make_current()
				assert runtime.evaluate_host('gl.getRenderbufferParameter(${target},${pname})')! == expected.str()
				C.vox_gl_int_parameter(webgl.viewport, &selected[0])
				assert selected == [i32(1), 2, 3, 4]!
				assert runtime.evaluate_host('gl.getError()')! == expected_error.str()
			}
		}
		other.native.make_current()
		assert runtime.evaluate_host('(function(){const marker={};try{gl.getRenderbufferParameter(gl.RENDERBUFFER,{valueOf(){throw marker}});return false}catch(error){return error===marker}})()')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		context.native.make_current()
		C.vox_gl_delete_object(2, native_buffer)
	}
}
