// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import json2
import webgl

fn test_public_lost_compile_shader_preserves_idl_gates_and_drops_source_command() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_compile_shader_lost",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_compile_shader_lost_other",width:2,height:2},"${kind}",null);globalThis.original=gl.createShader(gl.VERTEX_SHADER);globalThis.sentinel=other.createShader(other.VERTEX_SHADER);')!
		text := if kind == 'webgl2' {
			'#version 300 es
void main(){gl_Position=vec4(0);}'
		} else {
			'void main(){gl_Position=vec4(0);}'
		}
		runtime.evaluate_host('other.shaderSource(sentinel,${json2.encode(text)})')!
		mut owner := host.contexts['__created_compile_shader_lost'] or { panic('shader source lost owner') }
		mut other := host.contexts['__created_compile_shader_lost_other'] or { panic('shader source lost other') }
		mut name := u32(0)
		for _, record in host.shaders {
			if record.object.context_id == other.identity() { name = record.object.native_name() }
		}
		assert name != 0
		owner.lose_context_from_compositor_loss()
		other.viewport(9, 10, 11, 12)
		other.native.make_current()
		mut unused := i32(0)
		C.vox_gl_int_parameter(u32(0xffff_ffff), &unused)
		assert runtime.evaluate_host('globalThis.after=gl.createShader(gl.VERTEX_SHADER);after instanceof WebGLShader')! == 'true'
		assert C.vox_gl_shader_parameter(name, webgl.compile_status) == 0
		assert runtime.evaluate_host('gl.compileShader(original)===undefined')! == 'true'
		assert runtime.evaluate_host('gl.compileShader(after)===undefined')! == 'true'
		for expression in ['gl.compileShader()', 'gl.compileShader(null)', 'gl.compileShader(undefined)'] {
			assert runtime.evaluate_host('(function(){try{${expression};return false}catch(error){return error instanceof TypeError}})()')! == 'true'
		}
		assert runtime.evaluate_host('(function(){try{gl.compileShader(Object.create(WebGLShader.prototype));return false}catch(error){return error instanceof TypeError}})()')! == 'true'
		assert runtime.evaluate_host('gl.compileShader(sentinel)===undefined')! == 'true'
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		length := C.vox_gl_shader_parameter(name, u32(0x8b88))
		mut bytes := []u8{len: length}
		C.vox_gl_get_shader_source(name, length, bytes.data)
		assert bytes[..length - 1].bytestr() == text
		assert C.vox_gl_shader_parameter(name, webgl.compile_status) == 0
		assert C.vox_gl_get_error() == webgl.invalid_enum
		assert C.vox_gl_get_error() == webgl.no_error
		assert runtime.evaluate_host('gl.getError()===gl.CONTEXT_LOST_WEBGL&&gl.getError()===gl.NO_ERROR&&other.getError()===other.NO_ERROR')! == 'true'
	}
}
