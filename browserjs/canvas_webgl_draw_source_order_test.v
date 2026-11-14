// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_webgl2_draw_source_owner_and_notifications_follow_idl_and_driver() {
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
	runtime.evaluate_host('globalThis.drawSourceGL=__webglContext({bridgeKey:"__created_draw_source_order",width:2,height:2},"webgl2",null);globalThis.drawSourceOther=__webglContext({bridgeKey:"__created_draw_source_other",width:2,height:2},"webgl2",null);drawSourceGL.viewport(1,2,3,4);drawSourceOther.viewport(9,10,11,12);')!
	mut context := host.contexts['__created_draw_source_order'] or { panic('draw context') }
	mut other := host.contexts['__created_draw_source_other'] or { panic('other draw context') }
	for index, expression in ['drawArraysInstanced(0xbad,-1,-1,-1)',
		'drawElementsInstanced(0xbad,-1,0xbad,-1,-1)', 'drawRangeElements(0xbad,2,1,-1,0xbad,-1)'] {
		context.native.make_current()
		match index {
			0 { C.vox_gl_draw_arrays_instanced(0xbad, -1, -1, -1, 3) }
			1 { C.vox_gl_draw_elements_instanced(0xbad, -1, 0xbad, -1, -1, 3) }
			else { C.vox_gl_draw_range_elements(0xbad, 2, 1, -1, 0xbad, -1) }
		}
		expected := C.vox_gl_get_error()
		assert expected != webgl.no_error
		context.native.present_with_preserved_buffer(true)
		assert !context.needs_to_present()
		other.native.make_current()
		runtime.evaluate_host('drawSourceGL.${expression}')!
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(0x0ba2, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert context.needs_to_present()
		assert runtime.evaluate_host('drawSourceGL.getError()')! == expected.str()
	}
	for expression in ['drawArraysInstanced(4,0,0,{valueOf(){throw marker}})',
		'drawElementsInstanced(4,0,5121,0,{valueOf(){throw marker}})',
		'drawRangeElements(4,0,0,0,5121,{valueOf(){throw marker}})'] {
		context.native.make_current()
		context.native.present_with_preserved_buffer(true)
		other.native.make_current()
		assert runtime.evaluate_host('(function(){const marker={};try{drawSourceGL.${expression};return false}catch(error){return error===marker}})()')! == 'true'
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(0x0ba2, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert !context.needs_to_present()
	}
}
