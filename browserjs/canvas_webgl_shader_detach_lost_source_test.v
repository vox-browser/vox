// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn public_shader_detach_lost_other_driver(program u32, vertex u32, fragment u32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(webgl.viewport, &selected[0])
	assert selected == [i32(9), 10, 11, 12]!
	assert C.vox_gl_program_parameter(program, webgl.attached_shaders) == 2
	assert C.vox_gl_program_parameter(program, webgl.delete_status) == 0
	for shader in [vertex, fragment] {
		assert C.vox_gl_shader_parameter(shader, webgl.compile_status) == 0
		assert C.vox_gl_shader_parameter(shader, webgl.delete_status) == 0
	}
}

fn test_public_lost_detach_shader_clears_source_slots_while_other_actual_attachments_survive() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_shader_detach_lost",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_shader_detach_lost_other",width:2,height:2},"${kind}",null);globalThis.original=gl.createProgram();globalThis.vertex=gl.createShader(gl.VERTEX_SHADER);globalThis.fragment=gl.createShader(gl.FRAGMENT_SHADER);globalThis.unattached=gl.createShader(gl.VERTEX_SHADER);gl.attachShader(original,vertex);gl.attachShader(original,fragment);globalThis.sentinel=other.createProgram();globalThis.otherVertex=other.createShader(other.VERTEX_SHADER);globalThis.otherFragment=other.createShader(other.FRAGMENT_SHADER);other.attachShader(sentinel,otherVertex);other.attachShader(sentinel,otherFragment);')!
		mut owner := host.contexts['__created_shader_detach_lost'] or { panic('lost detach owner') }
		mut other := host.contexts['__created_shader_detach_lost_other'] or { panic('lost detach other') }
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
		owner.lose_context_from_compositor_loss()
		other.viewport(9, 10, 11, 12)
		mut unused := i32(0)
		C.vox_gl_int_parameter(u32(0xffff_ffff), &unused)
		assert runtime.evaluate_host('globalThis.after=gl.createProgram();globalThis.afterVertex=gl.createShader(gl.VERTEX_SHADER);globalThis.afterFragment=gl.createShader(gl.FRAGMENT_SHADER);gl.attachShader(after,afterVertex);gl.attachShader(after,afterFragment);gl.getAttachedShaders(after)[0]===afterVertex&&gl.getAttachedShaders(after)[1]===afterFragment')! == 'true'
		public_shader_detach_lost_other_driver(program_name, vertex_name, fragment_name)
		for expression in ['gl.detachShader(original,otherVertex)', 'gl.detachShader(sentinel,vertex)'] {
			assert runtime.evaluate_host('${expression}===undefined&&gl.getAttachedShaders(original)[0]===vertex&&gl.getAttachedShaders(original)[1]===fragment&&other.getAttachedShaders(sentinel)[0]===otherVertex&&other.getAttachedShaders(sentinel)[1]===otherFragment')! == 'true'
			public_shader_detach_lost_other_driver(program_name, vertex_name, fragment_name)
		}
		for expression in ['gl.detachShader()', 'gl.detachShader(original)',
			'gl.detachShader(null,vertex)', 'gl.detachShader(original,null)',
			'gl.detachShader(Object.create(WebGLProgram.prototype),vertex)',
			'gl.detachShader(original,Object.create(WebGLShader.prototype))'] {
			assert runtime.evaluate_host('(function(){try{${expression};return false}catch(error){return error instanceof TypeError}})()')! == 'true'
			assert runtime.evaluate_host('gl.getAttachedShaders(original)[0]===vertex&&gl.getAttachedShaders(original)[1]===fragment')! == 'true'
			public_shader_detach_lost_other_driver(program_name, vertex_name, fragment_name)
		}
		assert runtime.evaluate_host('gl.deleteShader(vertex);gl.detachShader(original,vertex)===undefined&&gl.getAttachedShaders(original)[0]===vertex&&gl.getAttachedShaders(original)[1]===fragment')! == 'true'
		public_shader_detach_lost_other_driver(program_name, vertex_name, fragment_name)
		assert runtime.evaluate_host('gl.detachShader(original,unattached)===undefined&&gl.getAttachedShaders(original).length===1&&gl.getAttachedShaders(original)[0]===fragment')! == 'true'
		public_shader_detach_lost_other_driver(program_name, vertex_name, fragment_name)
		assert runtime.evaluate_host('gl.detachShader(original,fragment)===undefined&&gl.getAttachedShaders(original).length===0')! == 'true'
		public_shader_detach_lost_other_driver(program_name, vertex_name, fragment_name)
		assert runtime.evaluate_host('(function(){gl.detachShader(after,afterVertex);const a=gl.getAttachedShaders(after),b=gl.getAttachedShaders(after);return a!==b&&a.length===1&&a[0]===afterFragment&&b[0]===afterFragment})()')! == 'true'
		public_shader_detach_lost_other_driver(program_name, vertex_name, fragment_name)
		for _ in 0 .. 2 {
			assert runtime.evaluate_host('gl.detachShader(after,afterFragment)===undefined&&gl.getAttachedShaders(after).length===0')! == 'true'
			public_shader_detach_lost_other_driver(program_name, vertex_name, fragment_name)
		}
		mut unmapped_programs := 0
		mut unmapped_shaders := 0
		for _, record in host.programs {
			if record.object.context_id == owner.identity() && record.object.native_name() == 0 {
				assert record.object.handle(owner.identity(), owner.context_generation())! == 5
				unmapped_programs++
			}
		}
		for _, record in host.shaders {
			if record.object.context_id == owner.identity() && record.object.native_name() == 0 {
				assert record.object.handle(owner.identity(), owner.context_generation())! == if record.type_ == webgl.vertex_shader {
					6
				} else {
					7
				}
				unmapped_shaders++
			}
		}
		assert unmapped_programs == 1 && unmapped_shaders == 2
		assert C.vox_gl_get_error() == webgl.invalid_enum
		assert C.vox_gl_get_error() == webgl.no_error
		assert runtime.evaluate_host('gl.getError()===gl.CONTEXT_LOST_WEBGL&&gl.getError()===gl.NO_ERROR&&other.getAttachedShaders(sentinel)[0]===otherVertex&&other.getAttachedShaders(sentinel)[1]===otherFragment&&other.getError()===other.NO_ERROR')! == 'true'
	}
}
