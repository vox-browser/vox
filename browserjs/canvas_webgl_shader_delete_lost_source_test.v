// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import json2
import webgl

fn test_public_lost_shader_deletion_keeps_record_invalidation_and_retained_identity() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_shader_delete_lost",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_shader_delete_lost_other",width:2,height:2},"${kind}",null);globalThis.original=gl.createShader(gl.VERTEX_SHADER);globalThis.sentinel=other.createShader(other.VERTEX_SHADER);')!
		text := if kind == 'webgl2' {
			'#version 300 es
void main(){gl_Position=vec4(0);}'
		} else {
			'void main(){gl_Position=vec4(0);}'
		}
		runtime.evaluate_host('other.shaderSource(sentinel,${json2.encode(text)});other.compileShader(sentinel);globalThis.program=gl.createProgram();gl.attachShader(program,original)')!
		mut owner := host.contexts['__created_shader_delete_lost'] or { panic('shader source lost owner') }
		mut other := host.contexts['__created_shader_delete_lost_other'] or { panic('shader source lost other') }
		mut name := u32(0)
		mut original_name := u32(0)
		for _, record in host.shaders {
			if record.object.context_id == other.identity() { name = record.object.native_name() }
			if record.object.context_id == owner.identity() { original_name = record.object.native_name() }
		}
		assert name != 0 && original_name == name
		owner.lose_context_from_compositor_loss()
		other.viewport(9, 10, 11, 12)
		other.native.make_current()
		mut unused := i32(0)
		C.vox_gl_int_parameter(u32(0xffff_ffff), &unused)
		assert runtime.evaluate_host('globalThis.after=gl.createShader(gl.VERTEX_SHADER);after instanceof WebGLShader')! == 'true'
		for expression in ['gl.deleteShader(null)', 'gl.deleteShader(undefined)',
			'gl.deleteShader(original)', 'gl.deleteShader(after)', 'gl.deleteShader(original)',
			'gl.deleteShader(sentinel)'] {
			assert runtime.evaluate_host('${expression}===undefined')! == 'true'
		}
		for expression in ['gl.deleteShader()', 'gl.deleteShader(Object.create(WebGLShader.prototype))'] {
			assert runtime.evaluate_host('(function(){try{${expression};return false}catch(error){return error instanceof TypeError}})()')! == 'true'
		}
		assert runtime.evaluate_host('gl.isShader(original)===false&&gl.isShader(after)===false&&gl.getAttachedShaders(program)[0]===original')! == 'true'
		mut owned_invalidated := 0
		for _, record in host.shaders {
			if record.object.context_id == owner.identity() {
				assert record.object.invalidated()
				owned_invalidated++
			} else {
				assert !record.object.invalidated()
			}
		}
		assert owned_invalidated == 2
		assert C.vox_gl_is_object(9, name) == 1
		assert C.vox_gl_shader_parameter(name, webgl.delete_status) == 0
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		length := C.vox_gl_shader_parameter(name, u32(0x8b88))
		mut bytes := []u8{len: length}
		C.vox_gl_get_shader_source(name, length, bytes.data)
		assert bytes[..length - 1].bytestr() == text
		assert C.vox_gl_shader_parameter(name, webgl.compile_status) == 1
		assert C.vox_gl_get_error() == webgl.invalid_enum
		assert C.vox_gl_get_error() == webgl.no_error
		assert runtime.evaluate_host('gl.getError()===gl.CONTEXT_LOST_WEBGL&&gl.getError()===gl.NO_ERROR&&other.getError()===other.NO_ERROR')! == 'true'
	}
}
