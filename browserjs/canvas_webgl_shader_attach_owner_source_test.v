// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn C.glGetAttachedShaders(u32, int, &i32, &u32)

fn test_public_shader_attachment_source_gates_and_actual_driver_retained_identities() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_shader_attach",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_shader_attach_other",width:2,height:2},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);globalThis.program=gl.createProgram();globalThis.foreignProgram=other.createProgram();globalThis.foreign=other.createShader(other.VERTEX_SHADER);globalThis.vertex=gl.createShader(gl.VERTEX_SHADER);globalThis.fragment=gl.createShader(gl.FRAGMENT_SHADER);globalThis.sameVertex=gl.createShader(gl.VERTEX_SHADER);globalThis.sameFragment=gl.createShader(gl.FRAGMENT_SHADER);globalThis.deleted=gl.createShader(gl.VERTEX_SHADER);gl.deleteShader(deleted);')!
		mut owner := host.contexts['__created_shader_attach'] or { panic('attach owner') }
		mut other := host.contexts['__created_shader_attach_other'] or { panic('attach other') }
		mut selected := [i32(0), 0, 0, 0]!
		for expression in ['gl.attachShader(program,foreign)', 'gl.attachShader(foreignProgram,vertex)',
			'gl.attachShader(program,deleted)'] {
			other.native.make_current()
			assert runtime.evaluate_host('${expression}===undefined')! == 'true'
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
			assert runtime.evaluate_host('gl.getAttachedShaders(program).length===0&&gl.getError()===gl.INVALID_OPERATION')! == 'true'
		}
		for expression in ['gl.attachShader()', 'gl.attachShader(program)',
			'gl.attachShader(null,vertex)', 'gl.attachShader(program,null)',
			'gl.attachShader(Object.create(WebGLProgram.prototype),vertex)',
			'gl.attachShader(foreignProgram,Object.create(WebGLShader.prototype))'] {
			other.native.make_current()
			assert runtime.evaluate_host('(function(){try{${expression};return false}catch(error){return error instanceof TypeError}})()')! == 'true'
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
		}
		mut program_name := u32(0)
		for _, record in host.programs {
			if record.object.context_id == owner.identity() {
				program_name = record.object.native_name()
			}
		}
		assert program_name != 0
		for argument in ['fragment', 'vertex'] {
			other.native.make_current()
			assert runtime.evaluate_host('gl.attachShader(program,${argument})===undefined')! == 'true'
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
		}
		mut count := 0
		mut names := [u32(0), 0]!
		C.glGetAttachedShaders(program_name, 2, &count, &names[0])
		assert count == 2
		assert runtime.evaluate_host('(function(){const first=gl.getAttachedShaders(program),second=gl.getAttachedShaders(program);return first!==second&&first.length===2&&first[0]===vertex&&first[1]===fragment&&first[0]===second[0]&&first[1]===second[1]})()')! == 'true'
		for argument in ['vertex', 'fragment', 'sameVertex', 'sameFragment'] {
			other.native.make_current()
			mut unused := i32(0)
			C.vox_gl_int_parameter(u32(0xffff_ffff), &unused)
			assert runtime.evaluate_host('gl.attachShader(program,${argument})===undefined')! == 'true'
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
			assert C.vox_gl_get_error() == webgl.invalid_enum
			assert C.vox_gl_get_error() == webgl.no_error
			assert runtime.evaluate_host('gl.getAttachedShaders(program)[0]===vertex&&gl.getAttachedShaders(program)[1]===fragment&&gl.getError()===gl.INVALID_OPERATION')! == 'true'
		}
		runtime.evaluate_host('gl.deleteProgram(program)')!
		other.native.make_current()
		assert runtime.evaluate_host('gl.attachShader(program,sameVertex)===undefined')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert runtime.evaluate_host('gl.getError()===gl.INVALID_OPERATION')! == 'true'
		runtime.evaluate_host('globalThis.rejected=gl.createProgram()')!
		mut rejected_name := u32(0)
		mut vertex_name := u32(0)
		for _, record in host.programs {
			if record.object.context_id == owner.identity() && !record.object.invalidated() {
				rejected_name = record.object.native_name()
			}
		}
		for _, record in host.shaders {
			if record.object.context_id == owner.identity() && record.type_ == webgl.vertex_shader && !record.object.invalidated() {
				candidate := record.object.native_name()
				if candidate in names { vertex_name = candidate }
			}
		}
		assert rejected_name != 0 && vertex_name != 0
		owner.native.make_current()
		C.vox_gl_delete_program(rejected_name)
		C.vox_gl_attach_shader(rejected_name, vertex_name)
		expected := C.vox_gl_get_error()
		assert expected != webgl.no_error
		other.native.make_current()
		assert runtime.evaluate_host('gl.attachShader(rejected,vertex)===undefined')! == 'true'
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert runtime.evaluate_host('gl.getAttachedShaders(rejected)[0]===vertex&&gl.getError()===${expected}')! == 'true'
	}
}
