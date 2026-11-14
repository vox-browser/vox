// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_viewport_scissor_use_actual_driver_and_preserve_idl_order() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_raster_source",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_raster_other",width:2,height:2},"${kind}",null);gl.viewport(1,2,3,4);gl.scissor(1,2,3,4);other.viewport(9,10,11,12);')!
		mut context := host.contexts['__created_raster_source'] or { panic('raster owner') }
		mut other := host.contexts['__created_raster_other'] or { panic('other owner') }
		for method in ['viewport', 'scissor'] {
			context.set_error(webgl.invalid_operation)
			other.native.make_current()
			runtime.evaluate_host('gl.${method}(0,0,-1,2);')!
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
			assert runtime.evaluate_host('gl.getError()===gl.INVALID_VALUE&&gl.getError()===gl.INVALID_OPERATION&&gl.getError()===gl.NO_ERROR&&Array.from(gl.getParameter(gl.${if method == 'viewport' {
				'VIEWPORT'
			} else {
				'SCISSOR_BOX'
			}})).join(",")==="1,2,3,4"')! == 'true'
			other.native.make_current()
			assert runtime.evaluate_host('(function(){const marker={};try{gl.${method}(0,0,{valueOf(){throw marker}},2);return false}catch(error){return error===marker}})()')! == 'true'
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
		}
		assert runtime.evaluate_host('gl.disable(gl.SCISSOR_TEST);gl.clearColor(0,0,1,1);gl.clear(gl.COLOR_BUFFER_BIT);gl.enable(gl.SCISSOR_TEST);gl.scissor(0,0,1,1);gl.scissor(0,0,-1,2);const rejected=gl.getError()===gl.INVALID_VALUE;gl.clearColor(1,0,0,1);gl.clear(gl.COLOR_BUFFER_BIT);gl.disable(gl.SCISSOR_TEST);const pixels=new Uint8Array(16);gl.readPixels(0,0,2,2,gl.RGBA,gl.UNSIGNED_BYTE,pixels);rejected&&Array.from(pixels).join(",")==="255,0,0,255,0,0,255,255,0,0,255,255,0,0,255,255"&&gl.getError()===gl.NO_ERROR')! == 'true'
		assert other.get_error() == webgl.no_error
	}
}
