// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn test_public_texture_copy_uses_source_owner_and_actual_driver_error_order() {
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
		key := '__created_texture_copy_${kind}'
		other_key := '__created_texture_copy_other_${kind}'
		runtime.evaluate_host('globalThis.copyGL=__webglContext({bridgeKey:"${key}",width:2,height:2},"${kind}",null);globalThis.copyOther=__webglContext({bridgeKey:"${other_key}",width:2,height:2},"${kind}",null);copyGL.viewport(1,2,3,4);copyOther.viewport(9,10,11,12);')!
		mut context := host.contexts[key] or { panic('native texture copy context') }
		mut other := host.contexts[other_key] or { panic('other texture copy context') }
		context.native.make_current()
		C.vox_gl_copy_tex_image2d(0xbad, 0, 0x1908, 0, 0, -1, 1, 1)
		expected_image := C.vox_gl_get_error()
		other.native.make_current()
		runtime.evaluate_host('copyGL.copyTexImage2D(0xbad,0,copyGL.RGBA,0,0,-1,1,1);')!
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(0x0ba2, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert runtime.evaluate_host('copyGL.getError()')! == expected_image.str()
		C.vox_gl_copy_tex_sub_image2d(0xbad, 0, 0, 0, 0, 0, -1, 1)
		expected_sub_image := C.vox_gl_get_error()
		other.native.make_current()
		runtime.evaluate_host('copyGL.copyTexSubImage2D(0xbad,0,0,0,0,0,-1,1);')!
		C.vox_gl_int_parameter(0x0ba2, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert runtime.evaluate_host('copyGL.getError()')! == expected_sub_image.str()
	}
}
