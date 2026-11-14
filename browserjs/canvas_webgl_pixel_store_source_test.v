// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_pixel_store_preserves_source_early_returns_driver_validation_and_idl_order() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_pixel_store",width:1,height:1},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_pixel_store_other",width:1,height:1},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);')!
		mut context := host.contexts['__created_pixel_store'] or { panic('pixel store owner') }
		mut other := host.contexts['__created_pixel_store_other'] or { panic('other owner') }
		for expression in ['pixelStorei(gl.UNPACK_ALIGNMENT,3)',
			'pixelStorei(gl.UNPACK_FLIP_Y_WEBGL,-1)', 'pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL,9)',
			'pixelStorei(gl.UNPACK_COLORSPACE_CONVERSION_WEBGL,-1)'] {
			other.native.make_current()
			runtime.evaluate_host('gl.${expression};')!
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
			assert C.vox_gl_get_error() == webgl.no_error
		}
		assert runtime.evaluate_host('gl.getError()===gl.INVALID_VALUE&&gl.getError()===gl.NO_ERROR&&gl.getParameter(gl.UNPACK_ALIGNMENT)===4&&gl.getParameter(gl.UNPACK_FLIP_Y_WEBGL)===true&&gl.getParameter(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL)===true&&gl.getParameter(gl.UNPACK_COLORSPACE_CONVERSION_WEBGL)===4294967295')! == 'true'
		context.native.make_current()
		C.vox_gl_pixel_storei(webgl.pack_alignment, 3)
		expected_error := C.vox_gl_get_error()
		context.set_error(webgl.invalid_operation)
		other.native.make_current()
		runtime.evaluate_host('gl.pixelStorei(gl.PACK_ALIGNMENT,3);')!
		assert runtime.evaluate_host('gl.getError()')! == expected_error.str()
		assert runtime.evaluate_host('gl.getError()===gl.INVALID_OPERATION&&gl.getError()===gl.NO_ERROR')! == 'true'
		other.native.make_current()
		assert runtime.evaluate_host('(function(){const marker={};try{gl.pixelStorei(gl.UNPACK_ALIGNMENT,{valueOf(){throw marker}});return false}catch(error){return error===marker}})()')! == 'true'
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(webgl.viewport, &selected[0])
		assert selected == [i32(9), 10, 11, 12]!
		assert other.get_error() == webgl.no_error
	}
}
