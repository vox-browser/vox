// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import json2
import webgl

fn test_public_program_deletion_source_gates_and_actual_current_program_lifetime() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_program_delete",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_program_delete_other",width:2,height:2},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);globalThis.program=gl.createProgram();globalThis.vertex=gl.createShader(gl.VERTEX_SHADER);globalThis.fragment=gl.createShader(gl.FRAGMENT_SHADER);globalThis.foreign=other.createProgram();')!
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
		assert runtime.evaluate_host('gl.shaderSource(vertex,${json2.encode(vertex_text)});gl.shaderSource(fragment,${json2.encode(fragment_text)});gl.compileShader(vertex);gl.compileShader(fragment);gl.attachShader(program,vertex);gl.attachShader(program,fragment);gl.linkProgram(program);gl.useProgram(program);gl.getProgramParameter(program,gl.LINK_STATUS)===true&&gl.getError()===gl.NO_ERROR')! == 'true'
		mut owner := host.contexts['__created_program_delete'] or { panic('program deletion owner') }
		mut other := host.contexts['__created_program_delete_other'] or { panic('program deletion other') }
		mut native_name := u32(0)
		for _, record in host.programs {
			if record.object.context_id == owner.identity() {
				native_name = record.object.native_name()
			}
		}
		assert native_name != 0
		other.native.make_current()
		mut unused := i32(0)
		C.vox_gl_int_parameter(u32(0xffff_ffff), &unused)
		for argument in ['null', 'undefined', 'foreign'] {
			assert runtime.evaluate_host('gl.deleteProgram(${argument})===undefined')! == 'true'
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
		}
		for expression in ['gl.deleteProgram()',
			'gl.deleteProgram(Object.create(WebGLProgram.prototype))'] {
			assert runtime.evaluate_host('(function(){try{${expression};return false}catch(error){return error instanceof TypeError}})()')! == 'true'
		}
		assert C.vox_gl_get_error() == webgl.invalid_enum
		assert C.vox_gl_get_error() == webgl.no_error
		assert runtime.evaluate_host('gl.getError()===gl.INVALID_OPERATION&&other.isProgram(foreign)===true')! == 'true'
		other.native.make_current()
		assert runtime.evaluate_host('gl.deleteProgram(program)===undefined')! == 'true'
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert C.vox_gl_is_object(10, native_name) == 1
		assert C.vox_gl_program_parameter(native_name, webgl.delete_status) == 1
		mut actual := i32(0)
		C.vox_gl_int_parameter(webgl.current_program, &actual)
		assert actual == int(native_name)
		assert runtime.evaluate_host('gl.getParameter(gl.CURRENT_PROGRAM)===null&&gl.isProgram(program)===false&&gl.getError()===gl.NO_ERROR')! == 'true'
		for expression in ['gl.deleteProgram(program)', 'other.deleteProgram(program)'] {
			other.native.make_current()
			assert runtime.evaluate_host('${expression}===undefined')! == 'true'
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
			expected := if expression.starts_with('other') {
				'other.getError()===other.INVALID_OPERATION'
			} else {
				'gl.getError()===gl.NO_ERROR'
			}
			assert runtime.evaluate_host(expected)! == 'true'
		}
		owner.native.make_current()
		C.vox_gl_use_program(0)
		assert C.vox_gl_is_object(10, native_name) == 0
		assert owner.get_error() == webgl.no_error
	}
}
