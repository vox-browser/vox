// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_active_texture_preserves_source_owner_driver_and_conversion_order() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_active_source",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_active_other",width:2,height:2},"${kind}",null);gl.activeTexture(gl.TEXTURE0+1);other.activeTexture(other.TEXTURE0+2);')!
		mut context := host.contexts['__created_active_source'] or { panic('texture owner') }
		mut other := host.contexts['__created_active_other'] or { panic('other owner') }
		context.native.make_current()
		C.vox_gl_enable(0xbad)
		other.native.make_current()
		runtime.evaluate_host('gl.activeTexture(gl.TEXTURE0+3);')!
		mut selected := i32(0)
		C.vox_gl_int_parameter(webgl.active_texture, &selected)
		assert selected == int(webgl.texture0 + 3)
		assert runtime.evaluate_host('gl.getParameter(gl.ACTIVE_TEXTURE)===gl.TEXTURE0+3&&gl.getError()===gl.INVALID_ENUM&&gl.getError()===gl.NO_ERROR')! == 'true'
		other.native.make_current()
		assert runtime.evaluate_host('gl.activeTexture(0xbad);gl.getError()===gl.INVALID_ENUM&&gl.getParameter(gl.ACTIVE_TEXTURE)===gl.TEXTURE0+3')! == 'true'
		other.native.make_current()
		assert runtime.evaluate_host('(function(){const marker={};try{gl.activeTexture({valueOf(){throw marker}});return false}catch(error){return error===marker}})()')! == 'true'
		C.vox_gl_int_parameter(webgl.active_texture, &selected)
		assert selected == int(webgl.texture0 + 2)
		assert context.get_error() == webgl.no_error
		assert other.get_error() == webgl.no_error
	}
}
