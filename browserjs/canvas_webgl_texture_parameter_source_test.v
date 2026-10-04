// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn test_actual_texture_parameters_reach_driver_bindings_outside_source_slots() {
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
		key := '__created_texture_parameter_${kind}'
		runtime.evaluate_host('globalThis.parameterGL=__webglContext({bridgeKey:"${key}",width:2,height:2},"${kind}",null);')!
		mut context := host.contexts[key] or { panic('native texture parameter context') }
		context.native.make_current()
		native_texture := C.vox_gl_gen_object(3)
		C.vox_gl_bind_texture(0x0de1, native_texture)
		result := runtime.evaluate_host(r'
 (function(){const gl=parameterGL;if(gl.getParameter(gl.TEXTURE_BINDING_2D)!==null)return "retained slot";
 gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.NEAREST);if(gl.getTexParameter(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER)!==gl.NEAREST||gl.getError()!==gl.NO_ERROR)return "integer parameter";
 gl.texParameterf(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);if(gl.getTexParameter(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S)!==gl.CLAMP_TO_EDGE||gl.getError()!==gl.NO_ERROR)return "float parameter";
 gl.texParameteri(0xbad,gl.TEXTURE_MIN_FILTER,gl.NEAREST);if(gl.getError()!==gl.INVALID_ENUM)return "integer target";
 gl.texParameterf(0xbad,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);if(gl.getError()!==gl.INVALID_ENUM)return "float target";
 return true})()
 ')!
		assert result == 'true'
		context.native.make_current()
		C.vox_gl_delete_object(3, native_texture)
	}
}
