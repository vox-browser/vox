// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn public_string_cache_selected_driver(expected [4]i32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(webgl.viewport, &selected[0])
	assert selected == expected
}

fn test_public_parameter_strings_share_the_actual_owner_cache_across_aliases_loss_and_restore() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_string_cache",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_string_cache_other",width:2,height:2},"${kind}",null);gl.viewport(1,2,3,4);other.viewport(9,10,11,12)')!
		mut owner := host.contexts['__created_string_cache'] or { panic('actual string-cache owner') }
		mut other := host.contexts['__created_string_cache_other'] or { panic('actual string-cache other') }
		assert runtime.evaluate_host('globalThis.vendor=gl.getParameter(gl.VENDOR);typeof vendor==="string"&&vendor.length>0')! == 'true'
		public_string_cache_selected_driver([i32(1), 2, 3, 4]!)
		assert runtime.evaluate_host('globalThis.info=gl.getExtension("WEBGL_debug_renderer_info");info!==null')! == 'true'
		other.native.make_current()
		mut unused := i32(0)
		C.vox_gl_int_parameter(u32(0xffff_ffff), &unused)
		assert runtime.evaluate_host('(function(){let calls=0;const value=gl.getParameter({valueOf(){calls++;return gl.VENDOR}});return calls===1&&value===vendor})()')! == 'true'
		public_string_cache_selected_driver([i32(9), 10, 11, 12]!)
		assert runtime.evaluate_host('gl.getParameter(info.UNMASKED_VENDOR_WEBGL)===vendor')! == 'true'
		public_string_cache_selected_driver([i32(9), 10, 11, 12]!)
		assert runtime.evaluate_host('(function(){const marker={};try{gl.getParameter({valueOf(){throw marker}});return false}catch(error){return error===marker}})()')! == 'true'
		public_string_cache_selected_driver([i32(9), 10, 11, 12]!)
		assert C.vox_gl_get_error() == webgl.invalid_enum
		assert C.vox_gl_get_error() == webgl.no_error
		assert runtime.evaluate_host('globalThis.renderer=gl.getParameter(info.UNMASKED_RENDERER_WEBGL);typeof renderer==="string"&&renderer.length>0')! == 'true'
		public_string_cache_selected_driver([i32(1), 2, 3, 4]!)
		other.native.make_current()
		assert runtime.evaluate_host('gl.getParameter(gl.RENDERER)===renderer')! == 'true'
		public_string_cache_selected_driver([i32(9), 10, 11, 12]!)
		owner.lose_context_from_compositor_loss()
		other.native.make_current()
		C.vox_gl_vertex_attrib_enable(0xffff_ffff, 1)
		assert runtime.evaluate_host('gl.getParameter(gl.VENDOR)===vendor&&gl.getParameter(info.UNMASKED_VENDOR_WEBGL)===vendor&&gl.getParameter(gl.RENDERER)===renderer&&gl.getParameter(info.UNMASKED_RENDERER_WEBGL)===renderer&&gl.getParameter(gl.VERSION)===""&&gl.getParameter(gl.SHADING_LANGUAGE_VERSION)===""')! == 'true'
		public_string_cache_selected_driver([i32(9), 10, 11, 12]!)
		assert C.vox_gl_get_error() == webgl.invalid_value
		assert C.vox_gl_get_error() == webgl.no_error
		assert runtime.evaluate_host('gl.isContextLost()&&gl.getError()===gl.CONTEXT_LOST_WEBGL&&gl.getError()===gl.NO_ERROR')! == 'true'
		owner.request_context_restore()
		assert owner.restore_context_after_compositor_reconnect()
		owner.viewport(1, 2, 3, 4)
		other.native.make_current()
		assert runtime.evaluate_host('gl.getParameter(gl.VENDOR)===vendor')! == 'true'
		public_string_cache_selected_driver([i32(1), 2, 3, 4]!)
		other.native.make_current()
		assert runtime.evaluate_host('gl.getParameter(gl.VENDOR)===vendor')! == 'true'
		public_string_cache_selected_driver([i32(9), 10, 11, 12]!)
		assert runtime.evaluate_host('typeof gl.getParameter(gl.VERSION)==="string"&&gl.getParameter(gl.VERSION).length>0&&gl.getError()===gl.NO_ERROR')! == 'true'
	}
}
