// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_actual_texture_source_slots_own_one_branded_wrapper_across_native_bind_failure() {
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
		key := '__created_texture_source_${kind}'
		runtime.evaluate_host('globalThis.sourceTextureGL=__webglContext({bridgeKey:"${key}",width:2,height:2},"${kind}",null);')!
		mut context := host.contexts[key] or { panic('source texture context') }
		texture := context.create_texture()
		context.bind_texture(webgl.texture_2d, texture)
		result := runtime.evaluate_host(r'
 (function(){const gl=sourceTextureGL,first=gl.getParameter(gl.TEXTURE_BINDING_2D),second=gl.getParameter(gl.TEXTURE_BINDING_2D);if(!(first instanceof WebGLTexture)||first!==second)return "first exposure";
 gl.bindTexture(gl.TEXTURE_CUBE_MAP,first);if(gl.getError()!==gl.INVALID_OPERATION||gl.getParameter(gl.TEXTURE_BINDING_CUBE_MAP)!==first||gl.getParameter(gl.TEXTURE_BINDING_2D)!==first)return "native conflict retained";
 gl.bindTexture(0xbad,first);if(gl.getError()!==gl.INVALID_ENUM||gl.getParameter(gl.TEXTURE_BINDING_CUBE_MAP)!==first)return "invalid target";
 if(gl instanceof WebGL2RenderingContext){for(const [target,pname] of [[gl.TEXTURE_3D,gl.TEXTURE_BINDING_3D],[gl.TEXTURE_2D_ARRAY,gl.TEXTURE_BINDING_2D_ARRAY]]){gl.bindTexture(target,first);if(gl.getError()!==gl.INVALID_OPERATION||gl.getParameter(pname)!==first)return "webgl2 retained";}}
 gl.deleteTexture(first);if(gl.getParameter(gl.TEXTURE_BINDING_2D)!==null||gl.getParameter(gl.TEXTURE_BINDING_CUBE_MAP)!==null||gl.getError()!==gl.NO_ERROR)return "delete retained";
 return true})()
 ')!
		assert result == 'true'
	}
}
