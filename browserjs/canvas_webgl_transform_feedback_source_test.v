// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl


fn public_transform_feedback_source_owner() {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(0x0ba2, &selected[0])
	assert selected == [i32(1), 2, 3, 4]!
}

fn test_public_transform_feedback_preserves_source_unassigned_slot_and_body_order() {
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
	runtime.evaluate_host('globalThis.tfSourceGL=__webglContext({bridgeKey:"__created_transform_feedback_source",width:2,height:2},"webgl2",null);globalThis.tfSourceOther=__webglContext({bridgeKey:"__created_transform_feedback_other",width:2,height:2},"webgl2",null);globalThis.ownedTF=tfSourceGL.createTransformFeedback(),foreignTF=tfSourceOther.createTransformFeedback(),ownedTFProgram=tfSourceGL.createProgram(),foreignTFProgram=tfSourceOther.createProgram();tfSourceGL.viewport(1,2,3,4);tfSourceOther.viewport(9,10,11,12);')!
	mut context := host.contexts['__created_transform_feedback_source'] or { panic('TF context') }
	mut other := host.contexts['__created_transform_feedback_other'] or { panic('other TF context') }
	other.native.make_current()
	assert runtime.evaluate_host(r'tfSourceGL.bindTransformFeedback(tfSourceGL.TRANSFORM_FEEDBACK,ownedTF);tfSourceGL.getParameter(tfSourceGL.TRANSFORM_FEEDBACK_BINDING)===null')! == 'true'
	public_transform_feedback_source_owner()
	mut native_binding := i32(0)
	C.vox_gl_int_parameter(webgl.transform_feedback_binding, &native_binding)
	assert native_binding != 0
	assert C.vox_gl_is_object(8,u32(native_binding)) == 1
	assert context.get_error() == webgl.no_error
	for pair in [
		['bindTransformFeedback(0xbad,ownedTF)', '1280'],
		['bindTransformFeedback(0xbad,foreignTF)', '1282'],
		['deleteTransformFeedback(foreignTF)', '1282'],
		['deleteTransformFeedback(null)', '0'],
		['transformFeedbackVaryings(foreignTFProgram,[],0xbad)', '1282'],
		['transformFeedbackVaryings(ownedTFProgram,[],0xbad)', '1280'],
		['deleteTransformFeedback(ownedTF)', '0'],
		['deleteTransformFeedback(ownedTF)', '0'],
		['bindTransformFeedback(0xbad,ownedTF)', '1282'],
	] {
		other.native.make_current()
		runtime.evaluate_host('tfSourceGL.${pair[0]};')!
		public_transform_feedback_source_owner()
		assert runtime.evaluate_host('tfSourceGL.getError()')! == pair[1]
		assert runtime.evaluate_host('tfSourceGL.getParameter(tfSourceGL.TRANSFORM_FEEDBACK_BINDING)===null')! == 'true'
	}
	C.vox_gl_int_parameter(webgl.transform_feedback_binding, &native_binding)
	assert native_binding == 0
	for expression in ['bindTransformFeedback(36386,{})', 'deleteTransformFeedback({})',
		'transformFeedbackVaryings(null,[],35980)'] {
		other.native.make_current()
		assert runtime.evaluate_host('(function(){try{tfSourceGL.${expression};return false}catch(error){return error instanceof TypeError}})()')! == 'true'
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(0x0ba2, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
	}
	other.native.make_current()
	assert runtime.evaluate_host(r'(function(){const marker={};try{tfSourceGL.bindTransformFeedback({valueOf(){throw marker}},foreignTF);return false}catch(error){return error===marker}})()')! == 'true'
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(0x0ba2, &selected[0])
	assert selected == [i32(9), 10, 11, 12]!
}
