// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_lost_sync_wait_preserves_source_default_and_other_driver() {
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
	runtime.evaluate_host('globalThis.owner=__webglContext({bridgeKey:"__created_sync_lost_owner",width:2,height:2},"webgl2",null);globalThis.other=__webglContext({bridgeKey:"__created_sync_lost_other",width:2,height:2},"webgl2",null);globalThis.beforeLoss=owner.fenceSync(owner.SYNC_GPU_COMMANDS_COMPLETE,0);')!
	mut owner := host.contexts['__created_sync_lost_owner'] or { panic('source lost owner') }
	mut other := host.contexts['__created_sync_lost_other'] or { panic('source other driver') }
	owner.lose_context_from_compositor_loss()
	runtime.evaluate_host('other.viewport(9,10,11,12);globalThis.sentinel=other.fenceSync(other.SYNC_GPU_COMMANDS_COMPLETE,0);')!
	other.native.make_current()
	C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
	assert runtime.evaluate_host('globalThis.afterLoss=owner.fenceSync(owner.SYNC_GPU_COMMANDS_COMPLETE,0);afterLoss instanceof WebGLSync&&beforeLoss!==afterLoss&&owner.isContextLost()')! == 'true'
	for flags in ['0', '1', '2'] {
		for timeout in ['0', '1', '18446744073709551615'] {
			assert runtime.evaluate_host('owner.clientWaitSync(beforeLoss,${flags},${timeout})===0&&owner.clientWaitSync(afterLoss,${flags},${timeout})===0')! == 'true'
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
		}
	}
	assert C.vox_gl_get_error() == webgl.invalid_value
	assert C.vox_gl_get_error() == webgl.no_error
	assert runtime.evaluate_host('other.getSyncParameter(sentinel,other.SYNC_CONDITION)===other.SYNC_GPU_COMMANDS_COMPLETE&&other.getError()===other.NO_ERROR&&owner.getError()===owner.CONTEXT_LOST_WEBGL&&owner.getError()===owner.NO_ERROR')! == 'true'
}
