// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_is_shader_source_optional_gate_preserves_other_owner_and_actual_native_names() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_is_shader",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_is_shader_other",width:2,height:2},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);')!
		mut owner := host.contexts['__created_is_shader'] or { panic('is-shader owner') }
		mut other := host.contexts['__created_is_shader_other'] or { panic('is-shader other') }
		owner.native.make_current()
		mut reserved := []u32{}
		for _ in 0 .. 8 { reserved << C.vox_gl_create_shader(webgl.vertex_shader) }
		runtime.evaluate_host('globalThis.shader=gl.createShader(gl.VERTEX_SHADER);globalThis.program=gl.createProgram();gl.attachShader(program,shader);globalThis.foreign=other.createShader(other.VERTEX_SHADER);')!
		owner.native.make_current()
		C.vox_gl_delete_shader(reserved[0])
		mut name := u32(0)
		for _, record in host.shaders {
			if record.object.context_id == owner.identity() {
				name = record.object.native_name()
				assert record.object.handle(owner.identity(), owner.context_generation())! == 1
			}
		}
		assert name !in reserved
		mut selected := [i32(0), 0, 0, 0]!
		other.native.make_current()
		assert runtime.evaluate_host('gl.isShader(foreign)===false')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert runtime.evaluate_host('gl.getError()===gl.INVALID_OPERATION')! == 'true'
		other.native.make_current()
		assert runtime.evaluate_host('(function(){try{gl.isShader(Object.create(WebGLShader.prototype));return false}catch(error){return error instanceof TypeError}})()')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		other.native.make_current()
		assert runtime.evaluate_host('gl.isShader(shader)===true')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		runtime.evaluate_host('gl.deleteShader(shader)')!
		assert C.vox_gl_is_object(9, name) == 1
		other.native.make_current()
		assert runtime.evaluate_host('gl.isShader(shader)===false')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert runtime.evaluate_host('gl.getError()===gl.NO_ERROR')! == 'true'
		runtime.evaluate_host('other.deleteShader(foreign)')!
		other.native.make_current()
		assert runtime.evaluate_host('gl.isShader(foreign)===false')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert runtime.evaluate_host('gl.getError()===gl.INVALID_OPERATION')! == 'true'
		owner.native.make_current()
		for native in reserved[1..] { C.vox_gl_delete_shader(native) }
		assert runtime.evaluate_host('gl.getError()===gl.NO_ERROR')! == 'true'
	}
}
