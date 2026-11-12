// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import json2
import webgl

fn test_public_program_validate_gates_precede_native_owner_and_preserve_driver_compilation() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_program_validate",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_program_validate_other",width:2,height:2},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);globalThis.program=gl.createProgram();globalThis.vertex=gl.createShader(gl.VERTEX_SHADER);globalThis.fragment=gl.createShader(gl.FRAGMENT_SHADER);globalThis.foreign=other.createProgram();')!
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
		assert runtime.evaluate_host('gl.shaderSource(vertex,${json2.encode(vertex_text)});gl.shaderSource(fragment,${json2.encode(fragment_text)});gl.compileShader(vertex);gl.compileShader(fragment);gl.attachShader(program,vertex);gl.attachShader(program,fragment);gl.getError()===gl.NO_ERROR')! == 'true'
		mut owner := host.contexts['__created_program_validate'] or { panic('program validate owner') }
		mut other := host.contexts['__created_program_validate_other'] or { panic('program validate other') }
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
		assert runtime.evaluate_host('gl.validateProgram(foreign)===undefined')! == 'true'
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		for expression in ['gl.validateProgram()', 'gl.validateProgram(null)',
			'gl.validateProgram(undefined)', 'gl.validateProgram(Object.create(WebGLProgram.prototype))'] {
			assert runtime.evaluate_host('(function(){try{${expression};return false}catch(error){return error instanceof TypeError}})()')! == 'true'
		}
		assert C.vox_gl_get_error() == webgl.invalid_enum
		assert C.vox_gl_get_error() == webgl.no_error
		assert runtime.evaluate_host('gl.getError()===gl.INVALID_OPERATION&&other.getProgramParameter(foreign,other.VALIDATE_STATUS)===false')! == 'true'
		assert runtime.evaluate_host('gl.linkProgram(program);globalThis.baseline=gl.createProgram();gl.attachShader(baseline,vertex);gl.attachShader(baseline,fragment);gl.linkProgram(baseline);gl.getError()===gl.NO_ERROR')! == 'true'
		mut baseline_name := u32(0)
		for _, record in host.programs {
			if record.object.context_id == owner.identity() && record.object.native_name() != native_name {
				baseline_name = record.object.native_name()
			}
		}
		assert baseline_name != 0
		owner.native.make_current()
		C.vox_gl_validate_program(baseline_name)
		expected_validation := C.vox_gl_program_parameter(baseline_name, webgl.validate_status)
		assert expected_validation == 1
		assert C.vox_gl_get_error() == webgl.no_error
		assert C.vox_gl_program_parameter(native_name, webgl.validate_status) == 0
		other.native.make_current()
		assert runtime.evaluate_host('gl.validateProgram(program)===undefined')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert C.vox_gl_program_parameter(native_name, webgl.validate_status) == expected_validation
		assert runtime.evaluate_host('gl.getProgramParameter(program,gl.VALIDATE_STATUS)===true&&gl.getError()===gl.NO_ERROR')! == 'true'
		runtime.evaluate_host('gl.deleteProgram(program)')!
		other.native.make_current()
		C.vox_gl_int_parameter(u32(0xffff_ffff), &unused)
		assert runtime.evaluate_host('gl.validateProgram(program)===undefined')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert C.vox_gl_get_error() == webgl.invalid_enum
		assert C.vox_gl_get_error() == webgl.no_error
		assert runtime.evaluate_host('gl.getError()===gl.INVALID_OPERATION')! == 'true'
		runtime.evaluate_host('gl.deleteProgram(baseline);globalThis.rejected=gl.createProgram()')!
		mut rejected_name := u32(0)
		for _, record in host.programs {
			if record.object.context_id == owner.identity() && !record.object.invalidated() {
				rejected_name = record.object.native_name()
			}
		}
		assert rejected_name != 0
		owner.native.make_current()
		C.vox_gl_delete_program(rejected_name)
		C.vox_gl_validate_program(rejected_name)
		expected := C.vox_gl_get_error()
		assert expected != webgl.no_error
		other.native.make_current()
		assert runtime.evaluate_host('gl.validateProgram(rejected)===undefined')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert runtime.evaluate_host('gl.getError()===${expected}')! == 'true'
	}
}
