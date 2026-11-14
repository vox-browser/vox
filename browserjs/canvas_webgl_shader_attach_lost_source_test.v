// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn public_shader_attach_lost_other_driver(program u32, vertex u32, fragment u32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(webgl.viewport, &selected[0])
	assert selected == [i32(9), 10, 11, 12]!
	mut bound := i32(-1)
	C.vox_gl_int_parameter(webgl.current_program, &bound)
	assert bound == 0
	assert C.vox_gl_program_parameter(program, webgl.attached_shaders) == 0
	assert C.vox_gl_program_parameter(program, webgl.delete_status) == 0
	for shader in [vertex, fragment] {
		assert C.vox_gl_shader_parameter(shader, webgl.compile_status) == 0
		assert C.vox_gl_shader_parameter(shader, webgl.delete_status) == 0
	}
}

fn test_public_lost_shader_attachment_retains_actual_wrappers_without_other_driver_changes() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_shader_attach_lost",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_shader_attach_lost_other",width:2,height:2},"${kind}",null);globalThis.original=gl.createProgram();globalThis.vertex=gl.createShader(gl.VERTEX_SHADER);globalThis.fragment=gl.createShader(gl.FRAGMENT_SHADER);globalThis.sentinel=other.createProgram();globalThis.otherVertex=other.createShader(other.VERTEX_SHADER);globalThis.otherFragment=other.createShader(other.FRAGMENT_SHADER);')!
		mut owner := host.contexts['__created_shader_attach_lost'] or { panic('lost attach owner') }
		mut other := host.contexts['__created_shader_attach_lost_other'] or { panic('lost attach other') }
		mut program_name := u32(0)
		mut vertex_name := u32(0)
		mut fragment_name := u32(0)
		for _, record in host.programs {
			if record.object.context_id == other.identity() {
				program_name = record.object.native_name()
			}
		}
		for _, record in host.shaders {
			if record.object.context_id == other.identity() {
				if record.type_ == webgl.vertex_shader {
					vertex_name = record.object.native_name()
				} else {
					fragment_name = record.object.native_name()
				}
			}
		}
		assert program_name != 0 && vertex_name != 0 && fragment_name != 0
		for _, record in host.programs {
			if record.object.context_id == owner.identity() {
				assert record.object.native_name() == program_name
			}
		}
		for _, record in host.shaders {
			if record.object.context_id == owner.identity() {
				assert record.object.native_name() == if record.type_ == webgl.vertex_shader {
					vertex_name
				} else {
					fragment_name
				}
			}
		}
		owner.lose_context_from_compositor_loss()
		other.viewport(9, 10, 11, 12)
		mut unused := i32(0)
		C.vox_gl_int_parameter(u32(0xffff_ffff), &unused)
		assert runtime.evaluate_host('globalThis.after=gl.createProgram();globalThis.afterVertex=gl.createShader(gl.VERTEX_SHADER);globalThis.afterFragment=gl.createShader(gl.FRAGMENT_SHADER);after instanceof WebGLProgram&&afterVertex instanceof WebGLShader&&afterFragment instanceof WebGLShader')! == 'true'
		public_shader_attach_lost_other_driver(program_name, vertex_name, fragment_name)
		for argument in ['fragment', 'vertex'] {
			assert runtime.evaluate_host('gl.attachShader(original,${argument})===undefined')! == 'true'
			public_shader_attach_lost_other_driver(program_name, vertex_name, fragment_name)
		}
		assert runtime.evaluate_host('(function(){const a=gl.getAttachedShaders(original),b=gl.getAttachedShaders(original);return a!==b&&a.length===2&&a[0]===vertex&&a[1]===fragment&&a[0]===b[0]&&a[1]===b[1]})()')! == 'true'
		public_shader_attach_lost_other_driver(program_name, vertex_name, fragment_name)
		for argument in ['afterVertex', 'afterFragment'] {
			assert runtime.evaluate_host('gl.attachShader(after,${argument})===undefined')! == 'true'
			public_shader_attach_lost_other_driver(program_name, vertex_name, fragment_name)
		}
		assert runtime.evaluate_host('gl.getAttachedShaders(after)[0]===afterVertex&&gl.getAttachedShaders(after)[1]===afterFragment')! == 'true'
		for argument in ['vertex', 'fragment', 'afterVertex', 'afterFragment', 'otherVertex'] {
			assert runtime.evaluate_host('gl.attachShader(original,${argument})===undefined&&gl.getAttachedShaders(original)[0]===vertex&&gl.getAttachedShaders(original)[1]===fragment')! == 'true'
			public_shader_attach_lost_other_driver(program_name, vertex_name, fragment_name)
		}
		assert runtime.evaluate_host('gl.attachShader(sentinel,vertex)===undefined&&other.getAttachedShaders(sentinel).length===0')! == 'true'
		public_shader_attach_lost_other_driver(program_name, vertex_name, fragment_name)
		for expression in ['gl.attachShader()', 'gl.attachShader(original)',
			'gl.attachShader(null,vertex)', 'gl.attachShader(original,null)',
			'gl.attachShader(Object.create(WebGLProgram.prototype),vertex)',
			'gl.attachShader(original,Object.create(WebGLShader.prototype))'] {
			assert runtime.evaluate_host('(function(){try{${expression};return false}catch(error){return error instanceof TypeError}})()')! == 'true'
			assert runtime.evaluate_host('gl.getAttachedShaders(original)[0]===vertex&&gl.getAttachedShaders(original)[1]===fragment')! == 'true'
			public_shader_attach_lost_other_driver(program_name, vertex_name, fragment_name)
		}
		assert runtime.evaluate_host('gl.deleteShader(vertex);gl.attachShader(original,vertex)===undefined&&gl.getAttachedShaders(original)[0]===vertex&&gl.getAttachedShaders(original)[1]===fragment')! == 'true'
		public_shader_attach_lost_other_driver(program_name, vertex_name, fragment_name)
		mut unmapped_programs := 0
		mut unmapped_shaders := 0
		for _, record in host.programs {
			if record.object.context_id == owner.identity() && record.object.native_name() == 0 {
				assert record.object.handle(owner.identity(), owner.context_generation())! == 4
				assert !record.object.invalidated()
				unmapped_programs++
			}
		}
		for _, record in host.shaders {
			if record.object.context_id == owner.identity() && record.object.native_name() == 0 {
				assert record.object.handle(owner.identity(), owner.context_generation())! == if record.type_ == webgl.vertex_shader {
					5
				} else {
					6
				}
				assert !record.object.invalidated()
				unmapped_shaders++
			}
		}
		assert unmapped_programs == 1 && unmapped_shaders == 2
		assert C.vox_gl_get_error() == webgl.invalid_enum
		assert C.vox_gl_get_error() == webgl.no_error
		assert runtime.evaluate_host('gl.getError()===gl.CONTEXT_LOST_WEBGL&&gl.getError()===gl.NO_ERROR&&other.getError()===other.NO_ERROR')! == 'true'
	}
}
