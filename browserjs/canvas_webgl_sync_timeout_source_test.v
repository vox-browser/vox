// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_client_wait_timeout_conversion_precedes_source_host_override_and_owner() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<canvas></canvas>')
	mut host := CanvasWebGLHost.create(document)
	mut runtime := Runtime.create()
	defer { runtime.close() }
	host.install(mut runtime)!
	runtime.evaluate_host('const __canvases=Object.create(null);function __canvasFor(s){return __canvases[s.bridgeKey]||(__canvases[s.bridgeKey]={state:s});}function __canvasDimension(s,key){return s[key];}function __element(s){return {state:s};}')!
	runtime.evaluate_host(webgl_bootstrap())!
	runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_sync_timeout",width:2,height:2},"webgl2",null);globalThis.other=__webglContext({bridgeKey:"__created_sync_timeout_other",width:2,height:2},"webgl2",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);globalThis.fence=gl.fenceSync(gl.SYNC_GPU_COMMANDS_COMPLETE,0);')!
	mut other := host.contexts['__created_sync_timeout_other'] or { panic('other timeout driver') }
	for requested in ['0', '1', '1000000000', '18446744073709551615'] {
		other.native.make_current()
		assert runtime.evaluate_host('(function(){let conversions=0;const result=gl.clientWaitSync(fence,0,{valueOf(){conversions++;other.viewport(9,10,11,12);return ${requested}}});return conversions===1&&(result===gl.TIMEOUT_EXPIRED||result===gl.CONDITION_SATISFIED||result===gl.ALREADY_SIGNALED)&&gl.getError()===gl.NO_ERROR})()')! == 'true'
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
	}
	other.native.make_current()
	assert runtime.evaluate_host('(function(){const marker={};try{gl.clientWaitSync(fence,0,{valueOf(){throw marker}});return false}catch(error){return error===marker}})()')! == 'true'
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(webgl.viewport, &selected[0])
	assert selected == [i32(9), 10, 11, 12]!
	assert runtime.evaluate_host('gl.getError()===gl.NO_ERROR')! == 'true'
}
