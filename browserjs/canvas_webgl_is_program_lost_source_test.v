// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_lost_is_program_sync_returns_source_boolean_without_other_driver_query() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_is_program_lost",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_is_program_lost_other",width:2,height:2},"${kind}",null);globalThis.original=gl.createProgram();globalThis.sentinel=other.createProgram();globalThis.external=gl.createProgram();')!
		mut owner := host.contexts['__created_is_program_lost'] or { panic('Boolean loss owner') }
		mut other := host.contexts['__created_is_program_lost_other'] or { panic('Boolean loss other') }
		mut original_name := u32(0)
		mut external_name := u32(0)
		mut sentinel_name := u32(0)
		for _, record in host.programs {
			if record.object.context_id == owner.identity() {
				id := record.object.handle(owner.identity(), owner.context_generation())!
				if id == 1 { original_name = record.object.native_name() }
				if id == 2 { external_name = record.object.native_name() }
			} else if record.object.context_id == other.identity() {
				sentinel_name = record.object.native_name()
			}
		}
		assert original_name != 0
		assert original_name == sentinel_name
		assert external_name != 0
		assert runtime.evaluate_host('gl.isProgram(original)===true&&gl.isProgram(external)===true')! == 'true'
		owner.native.make_current()
		C.vox_gl_delete_program(external_name)
		assert runtime.evaluate_host('gl.isProgram(external)===false&&gl.getError()===gl.NO_ERROR')! == 'true'
		owner.lose_context_from_compositor_loss()
		assert owner.native.is_lost()
		other.viewport(9, 10, 11, 12)
		other.native.make_current()
		C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
		assert runtime.evaluate_host('globalThis.after=gl.createProgram();after instanceof WebGLProgram&&after!==original')! == 'true'
		for query in ['gl.isProgram(original)===false', 'gl.isProgram(after)===false',
			'gl.isProgram(null)===false', 'gl.isProgram(undefined)===false',
			'gl.isProgram(sentinel)===false',
			'(function(){try{gl.isProgram(Object.create(WebGLProgram.prototype));return false}catch(error){return error instanceof TypeError}})()',
			'(function(){try{gl.isProgram();return false}catch(error){return error instanceof TypeError}})()'] {
			assert runtime.evaluate_host(query)! == 'true'
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
			assert C.vox_gl_is_object(10, sentinel_name) == 1
		}
		assert C.vox_gl_get_error() == webgl.invalid_value
		assert C.vox_gl_get_error() == webgl.no_error
		assert runtime.evaluate_host('gl.getError()===gl.CONTEXT_LOST_WEBGL&&gl.getError()===gl.NO_ERROR&&other.isProgram(sentinel)===true&&other.getError()===other.NO_ERROR')! == 'true'
	}
}
