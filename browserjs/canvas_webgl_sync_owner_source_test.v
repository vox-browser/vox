// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn public_sync_source_owner(expected [4]i32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(0x0ba2, &selected[0])
	assert selected == expected
}

fn test_public_sync_source_cpu_returns_preserve_other_and_native_dispatch_selects_owner() {
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
	runtime.evaluate_host('globalThis.syncBodyOwner=__webglContext({bridgeKey:"__created_sync_owner_source",width:2,height:2},"webgl2",null);globalThis.syncBodyOther=__webglContext({bridgeKey:"__created_sync_other_source",width:2,height:2},"webgl2",null);globalThis.ownedBodySync=syncBodyOwner.fenceSync(37143,0);globalThis.foreignBodySync=syncBodyOther.fenceSync(37143,0);syncBodyOwner.viewport(1,2,3,4);syncBodyOther.viewport(9,10,11,12);')!
	mut other := host.contexts['__created_sync_other_source'] or { panic('other sync context') }
	for pair in [
		['clientWaitSync(foreignBodySync,2,0)', '1282', 'early'],
		['waitSync(foreignBodySync,2,0)', '1282', 'early'],
		['deleteSync(foreignBodySync)', '1282', 'early'],
		['getSyncParameter(foreignBodySync,37139)', '1282', 'early'],
		['deleteSync(null)', '0', 'early'],
		['deleteSync(ownedBodySync)', '0', 'driver'],
		['deleteSync(ownedBodySync)', '0', 'early'],
		['clientWaitSync(ownedBodySync,2,0)', '1282', 'early'],
		['waitSync(ownedBodySync,2,0)', '1282', 'early'],
		['getSyncParameter(ownedBodySync,37139)', '1282', 'early'],
	] {
		other.native.make_current()
		runtime.evaluate_host('syncBodyOwner.${pair[0]};')!
		public_sync_source_owner(if pair[2] == 'driver' { [i32(1), 2, 3, 4]! } else { [i32(9), 10, 11, 12]! })
		assert runtime.evaluate_host('syncBodyOwner.getError()')! == pair[1]
	}
	for expression in ['clientWaitSync(null,0,0)', 'waitSync(null,0,0)', 'deleteSync({})'] {
		other.native.make_current()
		assert runtime.evaluate_host('(function(){try{syncBodyOwner.${expression};return false}catch(error){return error instanceof TypeError}})()')! == 'true'
		public_sync_source_owner([i32(9), 10, 11, 12]!)
	}
	other.native.make_current()
	assert runtime.evaluate_host(r'(function(){const marker={};try{syncBodyOwner.waitSync(foreignBodySync,0,{valueOf(){throw marker}});return false}catch(error){return error===marker}})()')! == 'true'
	public_sync_source_owner([i32(9), 10, 11, 12]!)
}
