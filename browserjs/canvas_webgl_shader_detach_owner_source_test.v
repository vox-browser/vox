// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn public_shader_detach_owner(expected [4]i32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(webgl.viewport, &selected[0])
	assert selected == expected
}

fn test_public_detach_shader_source_handle_order_and_actual_rejected_attachment_state() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_shader_detach",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_shader_detach_other",width:2,height:2},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);globalThis.program=gl.createProgram();globalThis.vertex=gl.createShader(gl.VERTEX_SHADER);globalThis.fragment=gl.createShader(gl.FRAGMENT_SHADER);globalThis.unattached=gl.createShader(gl.VERTEX_SHADER);globalThis.deleted=gl.createShader(gl.VERTEX_SHADER);gl.deleteShader(deleted);gl.attachShader(program,vertex);gl.attachShader(program,fragment);globalThis.foreignProgram=other.createProgram();globalThis.foreign=other.createShader(other.VERTEX_SHADER);')!
		mut owner := host.contexts['__created_shader_detach'] or { panic('detach owner') }
		mut other := host.contexts['__created_shader_detach_other'] or { panic('detach other') }
		for expression in ['gl.detachShader(program,foreign)', 'gl.detachShader(program,deleted)',
			'gl.detachShader(foreignProgram,vertex)'] {
			other.native.make_current()
			mut unused := i32(0)
			C.vox_gl_int_parameter(u32(0xffff_ffff), &unused)
			assert runtime.evaluate_host('${expression}===undefined&&gl.getAttachedShaders(program)[0]===vertex&&gl.getAttachedShaders(program)[1]===fragment')! == 'true'
			public_shader_detach_owner([i32(9), 10, 11, 12]!)
			assert C.vox_gl_get_error() == webgl.invalid_enum
			assert C.vox_gl_get_error() == webgl.no_error
			assert runtime.evaluate_host('gl.getError()===gl.INVALID_OPERATION')! == 'true'
		}
		for expression in ['gl.detachShader()', 'gl.detachShader(program)',
			'gl.detachShader(null,vertex)', 'gl.detachShader(program,null)',
			'gl.detachShader(Object.create(WebGLProgram.prototype),vertex)',
			'gl.detachShader(foreignProgram,Object.create(WebGLShader.prototype))'] {
			other.native.make_current()
			assert runtime.evaluate_host('(function(){try{${expression};return false}catch(error){return error instanceof TypeError}})()')! == 'true'
			public_shader_detach_owner([i32(9), 10, 11, 12]!)
			assert runtime.evaluate_host('gl.getAttachedShaders(program)[0]===vertex&&gl.getAttachedShaders(program)[1]===fragment')! == 'true'
		}
		mut program_name := u32(0)
		mut unattached_name := u32(0)
		for _, record in host.programs {
			if record.object.context_id == owner.identity() {
				program_name = record.object.native_name()
			}
		}
		for _, record in host.shaders {
			if record.object.context_id == owner.identity() && !record.object.invalidated() && record.object.handle(owner.identity(), owner.context_generation())! == 4 {
				unattached_name = record.object.native_name()
			}
		}
		assert program_name != 0 && unattached_name != 0
		owner.native.make_current()
		C.vox_gl_detach_shader(program_name, unattached_name)
		expected := C.vox_gl_get_error()
		assert expected != webgl.no_error
		assert C.vox_gl_program_parameter(program_name, webgl.attached_shaders) == 2
		other.native.make_current()
		assert runtime.evaluate_host('gl.detachShader(program,unattached)===undefined&&gl.getAttachedShaders(program).length===1&&gl.getAttachedShaders(program)[0]===fragment')! == 'true'
		public_shader_detach_owner([i32(1), 2, 3, 4]!)
		assert C.vox_gl_program_parameter(program_name, webgl.attached_shaders) == 2
		assert runtime.evaluate_host('gl.getError()===${expected}')! == 'true'
		other.native.make_current()
		assert runtime.evaluate_host('gl.detachShader(program,vertex)===undefined&&gl.getAttachedShaders(program)[0]===fragment')! == 'true'
		public_shader_detach_owner([i32(1), 2, 3, 4]!)
		assert C.vox_gl_program_parameter(program_name, webgl.attached_shaders) == 1
		assert runtime.evaluate_host('gl.getError()===gl.NO_ERROR')! == 'true'
		other.native.make_current()
		assert runtime.evaluate_host('gl.detachShader(program,fragment)===undefined&&gl.getAttachedShaders(program).length===0')! == 'true'
		public_shader_detach_owner([i32(1), 2, 3, 4]!)
		assert C.vox_gl_program_parameter(program_name, webgl.attached_shaders) == 0
		assert runtime.evaluate_host('gl.getError()===gl.NO_ERROR')! == 'true'
		runtime.evaluate_host('gl.deleteProgram(program)')!
		other.native.make_current()
		assert runtime.evaluate_host('gl.detachShader(program,vertex)===undefined')! == 'true'
		public_shader_detach_owner([i32(9), 10, 11, 12]!)
		assert runtime.evaluate_host('gl.getError()===gl.INVALID_OPERATION')! == 'true'
	}
}
