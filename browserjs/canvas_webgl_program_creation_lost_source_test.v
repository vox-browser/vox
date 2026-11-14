// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_lost_create_program_returns_distinct_owned_records_with_absent_native_mapping() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_program_lost_creation",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_program_lost_creation_other",width:2,height:2},"${kind}",null);globalThis.original=gl.createProgram();globalThis.sentinel=other.createProgram();')!
		mut owner := host.contexts['__created_program_lost_creation'] or { panic('creation lost owner') }
		mut other := host.contexts['__created_program_lost_creation_other'] or { panic('creation other') }
		mut sentinel_name := u32(0)
		for _, record in host.programs {
			if record.object.context_id == other.identity() {
				sentinel_name = record.object.native_name()
			}
		}
		assert sentinel_name != 0
		assert runtime.evaluate_host('gl.isProgram(original)===true&&other.isProgram(sentinel)===true')! == 'true'
		owner.lose_context_from_compositor_loss()
		assert owner.native.is_lost()
		other.viewport(9, 10, 11, 12)
		other.native.make_current()
		C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
		assert runtime.evaluate_host('globalThis.first=gl.createProgram();globalThis.second=gl.createProgram();globalThis.third=gl.createProgram();first instanceof WebGLProgram&&second instanceof WebGLProgram&&third instanceof WebGLProgram&&first!==second&&first!==third&&second!==third&&first!==original&&gl.isContextLost()')! == 'true'
		mut ids := []u32{}
		for _, record in host.programs {
			if record.object.context_id != owner.identity() { continue }
			id := record.object.handle(owner.identity(), owner.context_generation())!
			ids << id
			assert owner.owns(&record.object)
			if id > 1 {
				assert record.object.native_name() == 0
			}
		}
		ids.sort()
		assert ids == [u32(1), 2, 3, 4]
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert C.vox_gl_is_object(10, sentinel_name) == 1
		assert C.vox_gl_get_error() == webgl.invalid_value
		assert C.vox_gl_get_error() == webgl.no_error
		assert runtime.evaluate_host('gl.getError()===gl.CONTEXT_LOST_WEBGL&&gl.getError()===gl.NO_ERROR&&other.isProgram(sentinel)===true&&other.getError()===other.NO_ERROR')! == 'true'
		owner.request_context_restore()
		assert owner.restore_context_after_compositor_reconnect()
		assert runtime.evaluate_host('globalThis.restored=gl.createProgram();restored instanceof WebGLProgram&&restored!==first&&gl.isProgram(restored)===true')! == 'true'
		mut restored_name := u32(0)
		for _, record in host.programs {
			if record.object.context_id == owner.identity() && owner.owns(&record.object) {
				assert record.object.handle(owner.identity(), owner.context_generation())! == 5
				restored_name = record.object.native_name()
			}
		}
		assert restored_name != 0
		assert C.vox_gl_is_object(10, restored_name) == 1
		assert runtime.evaluate_host('gl.getError()===gl.NO_ERROR')! == 'true'
	}
}
