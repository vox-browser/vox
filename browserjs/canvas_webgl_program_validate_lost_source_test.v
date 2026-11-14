// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import json2
import webgl

fn test_public_lost_program_validation_preserves_other_unvalidated_driver_program() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_program_validate_lost",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_program_validate_lost_other",width:2,height:2},"${kind}",null);globalThis.original=gl.createProgram();globalThis.sentinel=other.createProgram();globalThis.vertex=other.createShader(other.VERTEX_SHADER);globalThis.fragment=other.createShader(other.FRAGMENT_SHADER);')!
		vertex_text := if kind == 'webgl2' {
			'#version 300 es
void main(){gl_Position=vec4(0);}'
		} else {
			'void main(){gl_Position=vec4(0);}'
		}
		fragment_text := if kind == 'webgl2' {
			'#version 300 es
precision mediump float;out vec4 color;void main(){color=vec4(1);}'
		} else {
			'precision mediump float;void main(){gl_FragColor=vec4(1);}'
		}
		assert runtime.evaluate_host('other.shaderSource(vertex,${json2.encode(vertex_text)});other.shaderSource(fragment,${json2.encode(fragment_text)});other.compileShader(vertex);other.compileShader(fragment);other.attachShader(sentinel,vertex);other.attachShader(sentinel,fragment);other.linkProgram(sentinel);other.getProgramParameter(sentinel,other.LINK_STATUS)===true&&other.getError()===other.NO_ERROR')! == 'true'
		mut owner := host.contexts['__created_program_validate_lost'] or { panic('lost validation owner') }
		mut other := host.contexts['__created_program_validate_lost_other'] or { panic('lost validation other') }
		mut originals := []&webgl.WebGLProgram{}
		for _, record in host.programs {
			if record.object.context_id == owner.identity() { originals << record }
		}
		assert originals.len == 1
		original := originals[0]
		mut native_name := u32(0)
		for _, record in host.programs {
			if record.object.context_id == other.identity() {
				native_name = record.object.native_name()
			}
		}
		assert native_name != 0 && native_name == original.object.native_name()
		other.native.make_current()
		baseline := C.vox_gl_create_program()
		for _, record in host.shaders {
			if record.object.context_id == other.identity() {
				C.vox_gl_attach_shader(baseline, record.object.native_name())
			}
		}
		C.vox_gl_link_program(baseline)
		C.vox_gl_validate_program(baseline)
		assert C.vox_gl_program_parameter(baseline, webgl.validate_status) == 1
		C.vox_gl_delete_program(baseline)
		assert C.vox_gl_program_parameter(native_name, webgl.validate_status) == 0
		assert C.vox_gl_get_error() == webgl.no_error
		owner.lose_context_from_compositor_loss()
		other.viewport(9, 10, 11, 12)
		other.native.make_current()
		mut unused := i32(0)
		C.vox_gl_int_parameter(u32(0xffff_ffff), &unused)
		assert runtime.evaluate_host('globalThis.after=gl.createProgram();after instanceof WebGLProgram')! == 'true'
		for argument in ['original', 'after', 'original', 'sentinel'] {
			assert runtime.evaluate_host('gl.validateProgram(${argument})===undefined')! == 'true'
		}
		for expression in ['gl.validateProgram()', 'gl.validateProgram(null)',
			'gl.validateProgram(undefined)', 'gl.validateProgram(Object.create(WebGLProgram.prototype))'] {
			assert runtime.evaluate_host('(function(){try{${expression};return false}catch(error){return error instanceof TypeError}})()')! == 'true'
		}
		assert !original.object.invalidated()
		mut unmapped := 0
		for _, record in host.programs {
			if record.object.context_id == owner.identity() {
				assert !record.object.invalidated()
				if record.object.native_name() == 0 {
					unmapped++
					assert record.object.handle(owner.identity(), owner.context_generation())! == 2
				}
			}
		}
		assert unmapped == 1

		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert C.vox_gl_is_object(10, native_name) == 1
		assert C.vox_gl_program_parameter(native_name, webgl.delete_status) == 0
		assert C.vox_gl_program_parameter(native_name, webgl.validate_status) == 0
		assert C.vox_gl_program_parameter(native_name, webgl.link_status) == 1
		assert C.vox_gl_program_parameter(native_name, webgl.attached_shaders) == 2
		mut current := i32(0)
		C.vox_gl_int_parameter(webgl.current_program, &current)
		assert current == 0
		assert C.vox_gl_get_error() == webgl.invalid_enum
		assert C.vox_gl_get_error() == webgl.no_error
		assert runtime.evaluate_host('gl.getError()===gl.CONTEXT_LOST_WEBGL&&gl.getError()===gl.NO_ERROR&&other.getParameter(other.CURRENT_PROGRAM)===null&&other.isProgram(sentinel)===true&&other.getError()===other.NO_ERROR')! == 'true'
	}
}
