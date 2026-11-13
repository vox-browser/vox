// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl


fn public_query_native_current(target u32) int {
	mut value := i32(0)
	value = C.vox_gl_query_target_parameter(target,0x8865)
	return value
}

fn public_query_source_owner(expected [4]i32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(0x0ba2, &selected[0])
	assert selected == expected
}

fn test_public_query_source_slots_and_driver_errors_preserve_body_and_idl_order() {
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
	runtime.evaluate_host('globalThis.queryOwner=__webglContext({bridgeKey:"__created_query_source",width:2,height:2},"webgl2",null);globalThis.queryOther=__webglContext({bridgeKey:"__created_query_other",width:2,height:2},"webgl2",null);globalThis.queryForeign=queryOther.createQuery();queryOwner.viewport(1,2,3,4);queryOther.viewport(9,10,11,12);')!
	mut other := host.contexts['__created_query_other'] or { panic('other query context') }
	mut context := host.contexts['__created_query_source'] or { panic('owner query context') }
	for target in [webgl.any_samples_passed, webgl.any_samples_passed_conservative,
		webgl.transform_feedback_primitives_written] {
		runtime.evaluate_host('globalThis.queryFirst=queryOwner.createQuery();globalThis.queryReplacement=queryOwner.createQuery();queryOwner.beginQuery(${target},queryReplacement);')!
		replacement_native := public_query_native_current(target)
		assert replacement_native != 0
		runtime.evaluate_host('queryOwner.endQuery(${target});queryOwner.beginQuery(${target},queryFirst);')!
		first_native := public_query_native_current(target)
		assert first_native != 0
		C.vox_gl_begin_query(target, u32(replacement_native))
		expected_duplicate := C.vox_gl_get_error()
		assert expected_duplicate != webgl.no_error
		other.native.make_current()
		runtime.evaluate_host('queryOwner.beginQuery(${target},queryReplacement);')!
		public_query_source_owner([i32(1), 2, 3, 4]!)
		assert public_query_native_current(target) == first_native
		assert runtime.evaluate_host('queryOwner.getQuery(${target},queryOwner.CURRENT_QUERY)===queryReplacement&&queryOwner.getError()===${expected_duplicate}')! == 'true'
		C.vox_gl_end_query(target)
		C.vox_gl_end_query(target)
		expected_missing := C.vox_gl_get_error()
		assert expected_missing != webgl.no_error
		other.native.make_current()
		runtime.evaluate_host('queryOwner.endQuery(${target});')!
		public_query_source_owner([i32(1), 2, 3, 4]!)
		assert public_query_native_current(target) == 0
		assert runtime.evaluate_host('queryOwner.getQuery(${target},queryOwner.CURRENT_QUERY)===null&&queryOwner.getError()===${expected_missing}')! == 'true'
		other.native.make_current()
		assert runtime.evaluate_host('queryOwner.getQuery(${target},queryOwner.CURRENT_QUERY)===null')! == 'true'
		public_query_source_owner([i32(9), 10, 11, 12]!)
	}
	other.native.make_current()
	runtime.evaluate_host('queryOwner.beginQuery(0xbad,queryForeign);')!
	public_query_source_owner([i32(1), 2, 3, 4]!)
	assert runtime.evaluate_host('queryOwner.getError()')! == '1282'
	context.native.make_current()
	C.vox_gl_end_query(0xbad)
	expected_end := C.vox_gl_get_error()
	other.native.make_current()
	runtime.evaluate_host('queryOwner.endQuery(0xbad);')!
	public_query_source_owner([i32(1), 2, 3, 4]!)
	assert runtime.evaluate_host('queryOwner.getError()')! == expected_end.str()
	other.native.make_current()
	assert runtime.evaluate_host(r'(function(){const marker={};try{queryOwner.beginQuery({valueOf(){throw marker}},queryFirst);return false}catch(error){return error===marker}})()')! == 'true'
	public_query_source_owner([i32(9), 10, 11, 12]!)
}
