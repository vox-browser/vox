// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import json2
import webgl

fn test_public_lost_program_deletion_preserves_other_driver_and_clears_source_pointer() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_program_delete_lost",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_program_delete_lost_other",width:2,height:2},"${kind}",null);globalThis.original=gl.createProgram();gl.useProgram(original);globalThis.sentinel=other.createProgram();globalThis.vertex=other.createShader(other.VERTEX_SHADER);globalThis.fragment=other.createShader(other.FRAGMENT_SHADER);')!
		assert runtime.evaluate_host('gl.getError()===gl.INVALID_OPERATION')! == 'true'
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
		assert runtime.evaluate_host('other.shaderSource(vertex,${json2.encode(vertex_text)});other.shaderSource(fragment,${json2.encode(fragment_text)});other.compileShader(vertex);other.compileShader(fragment);other.attachShader(sentinel,vertex);other.attachShader(sentinel,fragment);other.linkProgram(sentinel);other.useProgram(sentinel);other.getProgramParameter(sentinel,other.LINK_STATUS)===true&&other.getError()===other.NO_ERROR')! == 'true'
		mut owner := host.contexts['__created_program_delete_lost'] or { panic('lost deletion owner') }
		mut other := host.contexts['__created_program_delete_lost_other'] or { panic('lost deletion other') }
		original := owner.get_parameter(webgl.current_program).program or { panic('source retained original') }
		mut native_name := u32(0)
		for _, record in host.programs {
			if record.object.context_id == other.identity() {
				native_name = record.object.native_name()
			}
		}
		assert native_name != 0 && native_name == original.object.native_name()
		owner.lose_context_from_compositor_loss()
		other.viewport(9, 10, 11, 12)
		other.native.make_current()
		mut unused := i32(0)
		C.vox_gl_int_parameter(u32(0xffff_ffff), &unused)
		assert runtime.evaluate_host('globalThis.after=gl.createProgram();after instanceof WebGLProgram')! == 'true'
		for argument in ['null', 'undefined', 'sentinel', 'after'] {
			assert runtime.evaluate_host('gl.deleteProgram(${argument})===undefined')! == 'true'
			assert runtime.evaluate_host('gl.getParameter(gl.CURRENT_PROGRAM)===original')! == 'true'
		}
		for expression in ['gl.deleteProgram()',
			'gl.deleteProgram(Object.create(WebGLProgram.prototype))'] {
			assert runtime.evaluate_host('(function(){try{${expression};return false}catch(error){return error instanceof TypeError}})()')! == 'true'
		}
		assert runtime.evaluate_host('gl.deleteProgram(original)===undefined&&gl.deleteProgram(original)===undefined')! == 'true'
		assert owner.get_parameter(webgl.current_program).program == none
		assert original.object.invalidated()
		assert runtime.evaluate_host('gl.getParameter(gl.CURRENT_PROGRAM)===null&&gl.isProgram(original)===false&&gl.isProgram(after)===false')! == 'true'
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert C.vox_gl_is_object(10, native_name) == 1
		assert C.vox_gl_program_parameter(native_name, webgl.delete_status) == 0
		assert C.vox_gl_program_parameter(native_name, webgl.link_status) == 1
		assert C.vox_gl_program_parameter(native_name, webgl.attached_shaders) == 2
		mut current := i32(0)
		C.vox_gl_int_parameter(webgl.current_program, &current)
		assert current == int(native_name)
		assert C.vox_gl_get_error() == webgl.invalid_enum
		assert C.vox_gl_get_error() == webgl.no_error
		assert runtime.evaluate_host('gl.getError()===gl.CONTEXT_LOST_WEBGL&&gl.getError()===gl.NO_ERROR&&other.getParameter(other.CURRENT_PROGRAM)===sentinel&&other.isProgram(sentinel)===true&&other.getError()===other.NO_ERROR')! == 'true'
	}
}
