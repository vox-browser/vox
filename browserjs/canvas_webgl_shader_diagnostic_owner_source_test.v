// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_shader_diagnostic_source_handles_gate_actual_native_sync_owner() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_shader_diagnostic",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_shader_diagnostic_other",width:2,height:2},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);globalThis.shader=gl.createShader(gl.VERTEX_SHADER);globalThis.foreign=other.createShader(other.VERTEX_SHADER);')!
		mut owner := host.contexts['__created_shader_diagnostic'] or { panic('owner diagnostic') }
		mut other := host.contexts['__created_shader_diagnostic_other'] or { panic('other diagnostic') }
		mut selected := [i32(0), 0, 0, 0]!
		for method in ['getShaderSource', 'getShaderInfoLog'] {
			other.native.make_current()
			assert runtime.evaluate_host('gl.${method}(foreign)===null')! == 'true'
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
			assert runtime.evaluate_host('gl.getError()===gl.INVALID_OPERATION')! == 'true'
			other.native.make_current()
			assert runtime.evaluate_host('gl.${method}(shader)===""')! == 'true'
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
			other.native.make_current()
			assert runtime.evaluate_host('(function(){try{gl.${method}(Object.create(WebGLShader.prototype));return false}catch(error){return error instanceof TypeError}})()')! == 'true'
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
		}
		mut native_name := u32(0)
		for _, record in host.shaders {
			if record.object.context_id == owner.identity() {
				native_name = record.object.native_name()
			}
		}
		assert native_name != 0
		owner.native.make_current()
		actual_source := 'this is not a shader'
		C.vox_gl_shader_source(native_name, actual_source.str, actual_source.len)
		C.vox_gl_compile_shader(native_name)
		length := C.vox_gl_shader_parameter(native_name, u32(0x8b84))
		assert length > 1
		mut bytes := []u8{len: length}
		C.vox_gl_shader_log(native_name, length, bytes.data)
		actual_log := bytes[..length - 1].bytestr()
		other.native.make_current()
		assert runtime.evaluate_host('gl.getShaderSource(shader)')! == actual_source
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		other.native.make_current()
		assert runtime.evaluate_host('gl.getShaderInfoLog(shader)')! == actual_log
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert runtime.evaluate_host('gl.getError()===gl.NO_ERROR')! == 'true'
		runtime.evaluate_host('gl.deleteShader(shader)')!
		for method in ['getShaderSource', 'getShaderInfoLog'] {
			other.native.make_current()
			assert runtime.evaluate_host('gl.${method}(shader)===null')! == 'true'
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
			assert runtime.evaluate_host('gl.getError()===gl.INVALID_OPERATION')! == 'true'
		}
	}
}
