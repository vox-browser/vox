// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn test_actual_renderbuffer_storage_uses_native_binding_and_source_depth_stencil_mapping() {
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
		key := '__created_renderbuffer_storage_${kind}'
		runtime.evaluate_host('globalThis.storageGL=__webglContext({bridgeKey:"${key}",width:2,height:2},"${kind}",null);')!
		mut context := host.contexts[key] or { panic('native storage context') }
		context.native.make_current()
		native_buffer := C.vox_gl_gen_object(2)
		C.vox_gl_bind_renderbuffer(0x8d41, native_buffer)
		C.vox_gl_renderbuffer_storage(0x8d41, 0x88f0, 6, 8)
		expected_format := C.vox_gl_renderbuffer_parameter(0x8d41, 0x8d44)
		mapped_error := C.vox_gl_get_error()
		assert mapped_error == 0
		runtime.evaluate_host('globalThis.storageExpectedFormat=${expected_format};')!
		result := runtime.evaluate_host(r'
 (function(){const gl=storageGL;if(gl.getParameter(gl.RENDERBUFFER_BINDING)!==null)return "retained binding";
 gl.renderbufferStorage(gl.RENDERBUFFER,gl.DEPTH_STENCIL,7,9);if(gl.getRenderbufferParameter(gl.RENDERBUFFER,gl.RENDERBUFFER_INTERNAL_FORMAT)!==storageExpectedFormat||gl.getRenderbufferParameter(gl.RENDERBUFFER,gl.RENDERBUFFER_WIDTH)!==7||gl.getRenderbufferParameter(gl.RENDERBUFFER,gl.RENDERBUFFER_HEIGHT)!==9||gl.getRenderbufferParameter(gl.RENDERBUFFER,gl.RENDERBUFFER_DEPTH_SIZE)!==24||gl.getRenderbufferParameter(gl.RENDERBUFFER,gl.RENDERBUFFER_STENCIL_SIZE)!==8||gl.getError()!==gl.NO_ERROR)return "depth stencil";
 if(gl instanceof WebGL2RenderingContext){gl.renderbufferStorageMultisample(gl.RENDERBUFFER,0,gl.RGBA8,5,6);if(gl.getRenderbufferParameter(gl.RENDERBUFFER,gl.RENDERBUFFER_WIDTH)!==5||gl.getRenderbufferParameter(gl.RENDERBUFFER,gl.RENDERBUFFER_HEIGHT)!==6||gl.getRenderbufferParameter(gl.RENDERBUFFER,gl.RENDERBUFFER_SAMPLES)!==0||gl.getError()!==gl.NO_ERROR)return "multisample";}
 return true})()
 ')!
		assert result == 'true'
		context.native.make_current()
		C.vox_gl_delete_object(2, native_buffer)
	}
}
