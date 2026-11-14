// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn public_deletion_query_owner() {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(0x0ba2, &selected[0])
	assert selected == [i32(1), 2, 3, 4]!
}

fn test_public_source_query_delete_selects_owner_before_null_foreign_and_repeat() {
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
	runtime.evaluate_host('globalThis.deleteQueryOwner=__webglContext({bridgeKey:"__created_query_delete",width:2,height:2},"webgl2",null);globalThis.deleteQueryOther=__webglContext({bridgeKey:"__created_query_delete_other",width:2,height:2},"webgl2",null);globalThis.deletedQuery=deleteQueryOwner.createQuery();globalThis.foreignDeletedQuery=deleteQueryOther.createQuery();deleteQueryOwner.viewport(1,2,3,4);deleteQueryOther.viewport(9,10,11,12);')!
	mut other := host.contexts['__created_query_delete_other'] or { panic('other query context') }
	for pair in [
		['deleteQuery(foreignDeletedQuery)', '1282'],
		['deleteQuery(null)', '0'],
		['deleteQuery(deletedQuery)', '0'],
		['deleteQuery(deletedQuery)', '0'],
	] {
		other.native.make_current()
		runtime.evaluate_host('deleteQueryOwner.${pair[0]};')!
		public_deletion_query_owner()
		assert runtime.evaluate_host('deleteQueryOwner.getError()')! == pair[1]
	}
	// A binding type error remains an IDL error before source body entry.
	other.native.make_current()
	assert runtime.evaluate_host(r'(function(){try{deleteQueryOwner.deleteQuery({});return false}catch(error){return error instanceof TypeError}})()')! == 'true'
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(0x0ba2, &selected[0])
	assert selected == [i32(9), 10, 11, 12]!
}
