// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_raster_enum_setters_use_owning_driver_and_keep_idl_conversion_order() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_raster_enum",width:1,height:1},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_raster_enum_other",width:1,height:1},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);')!
		mut context := host.contexts['__created_raster_enum'] or { panic('raster owner') }
		mut other := host.contexts['__created_raster_enum_other'] or { panic('other owner') }
		for method in ['cullFace', 'depthFunc', 'frontFace', 'hint'] {
			context.native.make_current()
			match method {
				'cullFace' { C.vox_gl_cull_face(0xbad) }
				'depthFunc' { C.vox_gl_depth_func(0xbad) }
				'frontFace' { C.vox_gl_front_face(0xbad) }
				else { C.vox_gl_hint(webgl.generate_mipmap_hint, 0xbad) }
			}
			expected_error := C.vox_gl_get_error()
			assert expected_error != webgl.no_error
			context.set_error(webgl.invalid_value)
			other.native.make_current()
			expression := if method == 'hint' { 'gl.GENERATE_MIPMAP_HINT,0xbad' } else { '0xbad' }
			runtime.evaluate_host('gl.${method}(${expression});')!
			mut selected := [i32(0), 0, 0, 0]!
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(1), 2, 3, 4]!
			assert runtime.evaluate_host('gl.getError()')! == expected_error.str()
			assert runtime.evaluate_host('gl.getError()===gl.INVALID_VALUE&&gl.getError()===gl.NO_ERROR')! == 'true'
			other.native.make_current()
			throwing := if method == 'hint' {
				'gl.GENERATE_MIPMAP_HINT,{valueOf(){throw marker}}'
			} else {
				'{valueOf(){throw marker}}'
			}
			assert runtime.evaluate_host('(function(){const marker={};try{gl.${method}(${throwing});return false}catch(error){return error===marker}})()')! == 'true'
			C.vox_gl_int_parameter(webgl.viewport, &selected[0])
			assert selected == [i32(9), 10, 11, 12]!
		}
		assert runtime.evaluate_host('gl.cullFace(gl.FRONT);gl.depthFunc(gl.GEQUAL);gl.frontFace(gl.CW);gl.hint(gl.GENERATE_MIPMAP_HINT,gl.NICEST);gl.getParameter(gl.CULL_FACE_MODE)===gl.FRONT&&gl.getParameter(gl.DEPTH_FUNC)===gl.GEQUAL&&gl.getParameter(gl.FRONT_FACE)===gl.CW&&gl.getParameter(gl.GENERATE_MIPMAP_HINT)===gl.NICEST&&gl.getError()===gl.NO_ERROR')! == 'true'
		assert other.get_error() == webgl.no_error
	}
}
