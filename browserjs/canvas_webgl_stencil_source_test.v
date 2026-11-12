// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_stencil_setters_keep_actual_driver_owner_error_priority_and_idl_order() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_stencil_source",width:1,height:1},"${kind}",{stencil:true});globalThis.other=__webglContext({bridgeKey:"__created_stencil_other",width:1,height:1},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);')!
		mut context := host.contexts['__created_stencil_source'] or { panic('stencil owner') }
		mut other := host.contexts['__created_stencil_other'] or { panic('other owner') }
		for operation in 0 .. 5 {
			context.native.make_current()
			match operation {
				0 { C.vox_gl_stencil_func(0xbad, 1, 0xff) }
				1 { C.vox_gl_stencil_func_separate(0xbad, webgl.always, 1, 0xff) }
				2 { C.vox_gl_stencil_mask_separate(0xbad, 0xff) }
				3 { C.vox_gl_stencil_op(webgl.keep, 0xbad, webgl.keep) }
				else {
					C.vox_gl_stencil_op_separate(webgl.front_and_back, webgl.keep, webgl.keep, 0xbad)
				}
			}
			expected_error := C.vox_gl_get_error()
			assert expected_error != webgl.no_error
			context.set_error(webgl.invalid_value)
			other.native.make_current()
			expression := match operation {
				0 { 'stencilFunc(0xbad,1,255)' }
				1 { 'stencilFuncSeparate(0xbad,gl.ALWAYS,1,255)' }
				2 { 'stencilMaskSeparate(0xbad,255)' }
				3 { 'stencilOp(gl.KEEP,0xbad,gl.KEEP)' }
				else { 'stencilOpSeparate(gl.FRONT_AND_BACK,gl.KEEP,gl.KEEP,0xbad)' }
			}
			runtime.evaluate_host('gl.${expression};')!
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
			assert runtime.evaluate_host('gl.getError()')! == expected_error.str()
			assert runtime.evaluate_host('gl.getError()===gl.INVALID_VALUE&&gl.getError()===gl.NO_ERROR')! == 'true'
		}
		for expression in ['stencilFunc(gl.ALWAYS,{valueOf(){throw marker}},255)',
			'stencilFuncSeparate(gl.FRONT,gl.ALWAYS,1,{valueOf(){throw marker}})',
			'stencilMask({valueOf(){throw marker}})',
			'stencilMaskSeparate(gl.BACK,{valueOf(){throw marker}})',
			'stencilOp(gl.KEEP,gl.KEEP,{valueOf(){throw marker}})',
			'stencilOpSeparate(gl.FRONT,gl.KEEP,gl.KEEP,{valueOf(){throw marker}})'] {
			other.native.make_current()
			assert runtime.evaluate_host('(function(){const marker={};try{gl.${expression};return false}catch(error){return error===marker}})()')! == 'true'
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
		}
		assert runtime.evaluate_host('gl.stencilFunc(gl.ALWAYS,0,0xffffffff);gl.stencilFuncSeparate(gl.FRONT,gl.EQUAL,7,0x0f);gl.stencilMask(0xffffffff);gl.stencilMaskSeparate(gl.BACK,0xf0);gl.stencilOp(gl.REPLACE,gl.INCR,gl.DECR_WRAP);gl.stencilOpSeparate(gl.FRONT,gl.INVERT,gl.KEEP,gl.DECR);gl.getParameter(gl.STENCIL_FUNC)===gl.EQUAL&&gl.getParameter(gl.STENCIL_REF)===7&&gl.getParameter(gl.STENCIL_VALUE_MASK)===15&&gl.getParameter(gl.STENCIL_BACK_WRITEMASK)===240&&gl.getParameter(gl.STENCIL_FAIL)===gl.INVERT&&gl.getParameter(gl.STENCIL_BACK_FAIL)===gl.REPLACE&&gl.getError()===gl.NO_ERROR')! == 'true'
		assert other.get_error() == webgl.no_error
	}
}
