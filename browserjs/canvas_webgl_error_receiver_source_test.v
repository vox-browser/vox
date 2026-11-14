// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn error_receiver_source_viewport() [4]i32 {
	mut value := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(webgl.viewport, &value[0])
	return value
}

fn test_public_get_error_preserves_early_returns_and_owning_sync_driver() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_error_receiver",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_error_other",width:2,height:2},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);')!
		mut context := host.contexts['__created_error_receiver'] or { panic('error owner') }
		mut other := host.contexts['__created_error_other'] or { panic('other owner') }
		context.native.set_pending_local_error(webgl.out_of_memory)
		context.set_error(webgl.invalid_operation)
		context.native.make_current()
		C.vox_gl_enable(0xbad)
		other.native.make_current()
		C.vox_gl_viewport(0, 0, -1, 1)
		assert runtime.evaluate_host('gl.getError()===gl.OUT_OF_MEMORY')! == 'true'
		assert error_receiver_source_viewport() == [i32(9), 10, 11, 12]!
		assert runtime.evaluate_host('gl.getError()===gl.INVALID_ENUM')! == 'true'
		assert error_receiver_source_viewport() == [i32(1), 2, 3, 4]!
		assert runtime.evaluate_host('gl.getError()===gl.INVALID_OPERATION&&gl.getError()===gl.NO_ERROR')! == 'true'
		assert runtime.evaluate_host('other.getError()===other.INVALID_VALUE&&other.getError()===other.NO_ERROR')! == 'true'
		context.native.set_pending_local_error(webgl.out_of_memory)
		context.lose_context('source actual receiver loss')
		other.native.make_current()
		assert runtime.evaluate_host('gl.getError()===gl.CONTEXT_LOST_WEBGL&&gl.getError()===gl.NO_ERROR')! == 'true'
		assert error_receiver_source_viewport() == [i32(9), 10, 11, 12]!
		assert context.native.take_pending_local_error() == webgl.out_of_memory
		assert other.get_error() == webgl.no_error
	}
}
