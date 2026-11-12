// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn C.glGetQueryiv(u32, u32, &i32)

fn query_record_other_stays_selected() {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(0x0ba2, &selected[0])
	assert selected == [i32(9), 10, 11, 12]!
}

fn test_public_get_query_wraps_actual_retained_deleted_records_without_selecting_owner() {
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
	runtime.evaluate_host('globalThis.recordQueryOwner=__webglContext({bridgeKey:"__created_query_record",width:2,height:2},"webgl2",null);globalThis.recordQueryOther=__webglContext({bridgeKey:"__created_query_record_other",width:2,height:2},"webgl2",null);recordQueryOwner.viewport(1,2,3,4);recordQueryOther.viewport(9,10,11,12);')!
	mut context := host.contexts['__created_query_record'] or { panic('query record owner') }
	mut other := host.contexts['__created_query_record_other'] or { panic('query record other') }
	for target in [webgl.any_samples_passed, webgl.any_samples_passed_conservative,
		webgl.transform_feedback_primitives_written] {
		mut query := context.create_query()
		query.object.set_label('retained deleted query ${target}')
		context.begin_query(target, mut query)
		// Real GL can end a query independently of the source retained slot.
		C.vox_gl_end_query(target)
		mut native_current := i32(-1)
		C.glGetQueryiv(target, webgl.current_query, &native_current)
		assert native_current == 0
		context.delete_query(mut query)
		assert query.object.invalidated()
		assert context.get_error() == webgl.no_error
		assert voidptr(&query.object) !in host.platform_objects
		other.native.make_current()
		assert runtime.evaluate_host('globalThis.retainedQuery=recordQueryOwner.getQuery(${target},recordQueryOwner.CURRENT_QUERY);retainedQuery instanceof WebGLQuery&&retainedQuery===recordQueryOwner.getQuery(${target},recordQueryOwner.CURRENT_QUERY)')! == 'true'
		query_record_other_stays_selected()
		wrapper := host.platform_objects[voidptr(&query.object)] or { panic('query wrapper') }
		registered := host.queries[wrapper] or { panic('retained query record') }
		assert registered == query
		assert registered.object.label() == 'retained deleted query ${target}'
		assert runtime.evaluate_host('recordQueryOwner.getError()')! == '0'
		assert runtime.evaluate_host('recordQueryOwner.getQueryParameter(retainedQuery,recordQueryOwner.QUERY_RESULT)===null&&recordQueryOwner.getError()===recordQueryOwner.INVALID_OPERATION')! == 'true'
		assert runtime.evaluate_host('recordQueryOwner.deleteQuery(retainedQuery);recordQueryOwner.getError()===recordQueryOwner.NO_ERROR&&recordQueryOwner.getQuery(${target},recordQueryOwner.CURRENT_QUERY)===retainedQuery')! == 'true'
		other.native.make_current()
		assert runtime.evaluate_host('recordQueryOwner.getQuery(${target},0xbad)===null')! == 'true'
		query_record_other_stays_selected()
		assert runtime.evaluate_host('recordQueryOwner.getError()')! == '1280'
		context.end_query(target)
		assert context.get_error() == webgl.invalid_operation
		other.native.make_current()
		assert runtime.evaluate_host('recordQueryOwner.getQuery(${target},recordQueryOwner.CURRENT_QUERY)===null')! == 'true'
		query_record_other_stays_selected()
	}
}
