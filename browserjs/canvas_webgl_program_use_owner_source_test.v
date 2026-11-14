// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import json2
import webgl

fn test_public_use_program_gates_null_dispatch_and_actual_rejection_retained_identity() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_program_use",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_program_use_other",width:2,height:2},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);globalThis.program=gl.createProgram();globalThis.vertex=gl.createShader(gl.VERTEX_SHADER);globalThis.fragment=gl.createShader(gl.FRAGMENT_SHADER);globalThis.foreign=other.createProgram();globalThis.deleted=gl.createProgram();gl.deleteProgram(deleted);')!
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
		mut owner := host.contexts['__created_program_use'] or { panic('use owner') }
		mut other := host.contexts['__created_program_use_other'] or { panic('use other') }
		original := owner.get_parameter(webgl.current_program).program or { panic('actual retained current program') }
		name := original.object.native_name()
		mut selected := [i32(0), 0, 0, 0]!
		for argument in ['foreign', 'deleted'] {
			other.native.make_current()
			mut unused := i32(0)
			C.vox_gl_int_parameter(u32(0xffff_ffff), &unused)
			assert runtime.evaluate_host('gl.useProgram(${argument})===undefined')! == 'true'
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
			assert C.vox_gl_get_error() == webgl.invalid_enum
			assert C.vox_gl_get_error() == webgl.no_error
			assert runtime.evaluate_host('gl.getParameter(gl.CURRENT_PROGRAM)===program&&gl.getError()===gl.INVALID_OPERATION')! == 'true'
		}
		for expression in ['gl.useProgram()', 'gl.useProgram(Object.create(WebGLProgram.prototype))'] {
			other.native.make_current()
			assert runtime.evaluate_host('(function(){try{${expression};return false}catch(error){return error instanceof TypeError}})()')! == 'true'
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
		}
		for argument in ['null', 'undefined'] {
			runtime.evaluate_host('gl.useProgram(program)')!
			other.native.make_current()
			assert runtime.evaluate_host('gl.useProgram(${argument})===undefined')! == 'true'
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
			mut actual := i32(-1)
			C.vox_gl_int_parameter(webgl.current_program, &actual)
			assert actual == 0
			assert runtime.evaluate_host('gl.getParameter(gl.CURRENT_PROGRAM)===null&&gl.getError()===gl.NO_ERROR')! == 'true'
		}
		runtime.evaluate_host('gl.useProgram(program);globalThis.rejected=gl.createProgram()')!
		rejected := owner.get_parameter(webgl.current_program).program or { panic('still bound original') }
		assert rejected == original
		mut rejected_name := u32(0)
		for _, record in host.programs {
			if record.object.context_id == owner.identity() && !record.object.invalidated() && record != original {
				rejected_name = record.object.native_name()
			}
		}
		assert rejected_name != 0
		owner.native.make_current()
		C.vox_gl_use_program(rejected_name)
		expected := C.vox_gl_get_error()
		assert expected != webgl.no_error
		other.native.make_current()
		assert runtime.evaluate_host('gl.useProgram(rejected)===undefined')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		mut actual := i32(-1)
		C.vox_gl_int_parameter(webgl.current_program, &actual)
		assert actual == int(name)
		assert runtime.evaluate_host('gl.getParameter(gl.CURRENT_PROGRAM)===rejected&&gl.getError()===${expected}')! == 'true'
	}
}
