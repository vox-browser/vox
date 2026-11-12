// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_base_draws_select_owner_and_notify_while_driver_validates_after_idl() {
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
	for kind in ['webgl', 'webgl2'] {
		key := '__created_draw_base_${kind}'
		other_key := '__created_draw_base_other_${kind}'
		runtime.evaluate_host('globalThis.baseDrawGL=__webglContext({bridgeKey:"${key}",width:2,height:2},"${kind}",null);globalThis.baseDrawOther=__webglContext({bridgeKey:"${other_key}",width:2,height:2},"${kind}",null);baseDrawGL.viewport(1,2,3,4);baseDrawOther.viewport(9,10,11,12);')!
		mut context := host.contexts[key] or { panic('base draw context') }
		mut other := host.contexts[other_key] or { panic('other base draw context') }
		for indexed in [false, true] {
			context.native.make_current()
			if indexed {
				C.vox_gl_draw_elements(0xbad, -1, 0xbad, -1)
			} else {
				C.vox_gl_draw_arrays(0xbad, -1, -1)
			}
			expected := C.vox_gl_get_error()
			assert expected != webgl.no_error
			context.native.present_with_preserved_buffer(true)
			assert !context.needs_to_present()
			other.native.make_current()
			expression := if indexed {
				'drawElements(0xbad,-1,0xbad,-1)'
			} else {
				'drawArrays(0xbad,-1,-1)'
			}
			runtime.evaluate_host('baseDrawGL.${expression}')!
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(0x0ba2, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
			assert context.needs_to_present()
			assert runtime.evaluate_host('baseDrawGL.getError()')! == expected.str()
		}
		for expression in ['drawArrays(4,0,{valueOf(){throw marker}})',
			'drawElements(4,0,5121,{valueOf(){throw marker}})'] {
			context.native.make_current()
			context.native.present_with_preserved_buffer(true)
			other.native.make_current()
			assert runtime.evaluate_host('(function(){const marker={};try{baseDrawGL.${expression};return false}catch(error){return error===marker}})()')! == 'true'
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(0x0ba2, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
			assert !context.needs_to_present()
		}
	}
}
