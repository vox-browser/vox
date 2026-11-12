// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn test_source_public_2d_byte_uploads_use_actual_texture_binding_and_owner() {
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
		key := '__created_texture_upload_${kind}'
		other_key := '__created_texture_upload_other_${kind}'
		runtime.evaluate_host('globalThis.uploadGL=__webglContext({bridgeKey:"${key}",width:2,height:2},"${kind}",null);globalThis.uploadOther=__webglContext({bridgeKey:"${other_key}",width:2,height:2},"${kind}",null);uploadGL.viewport(1,2,3,4);uploadOther.viewport(9,10,11,12);globalThis.uploadTexture=uploadGL.createTexture();uploadGL.bindTexture(uploadGL.TEXTURE_2D,uploadTexture);')!
		mut context := host.contexts[key] or { panic('native texture upload context') }
		mut other := host.contexts[other_key] or { panic('other native texture upload context') }
		mut native_texture := i32(0)
		C.vox_gl_int_parameter(0x8069, &native_texture)
		assert native_texture != 0
		runtime.evaluate_host('uploadGL.bindTexture(uploadGL.TEXTURE_2D,null);')!
		C.vox_gl_bind_texture(0x0de1, u32(native_texture))
		result := runtime.evaluate_host(r'
 (function(){const gl=uploadGL;if(gl.getParameter(gl.TEXTURE_BINDING_2D)!==null)return "retained slot";
 gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,2,2,0,gl.RGBA,gl.UNSIGNED_BYTE,new Uint8Array([255,0,0,255,0,255,0,255,0,0,255,255,255,255,0,255]));if(gl.getError()!==gl.NO_ERROR)return "image upload";
 const framebuffer=gl.createFramebuffer();gl.bindFramebuffer(gl.FRAMEBUFFER,framebuffer);gl.framebufferTexture2D(gl.FRAMEBUFFER,gl.COLOR_ATTACHMENT0,gl.TEXTURE_2D,uploadTexture,0);if(gl.checkFramebufferStatus(gl.FRAMEBUFFER)!==gl.FRAMEBUFFER_COMPLETE)return "framebuffer";
 const pixels=new Uint8Array(16);gl.readPixels(0,0,2,2,gl.RGBA,gl.UNSIGNED_BYTE,pixels);if(pixels.join(",")!=="255,0,0,255,0,255,0,255,0,0,255,255,255,255,0,255")return "image readback";
 gl.texSubImage2D(gl.TEXTURE_2D,0,1,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,new Uint8Array([64,128,192,255]));if(gl.getError()!==gl.NO_ERROR)return "sub image upload";const pixel=new Uint8Array(4);gl.readPixels(1,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,pixel);if(pixel.join(",")!=="64,128,192,255")return "sub image readback";return true})()
 ')!
		assert result == 'true'
		other.native.make_current()
		if kind == 'webgl2' {
			runtime.evaluate_host('uploadGL.texImage2D(0xbad,0,uploadGL.RGBA,1,1,0,uploadGL.RGBA,uploadGL.UNSIGNED_BYTE,new Uint8Array(4),5);')!
		} else {
			runtime.evaluate_host('uploadGL.texSubImage2D(0xbad,0,0,0,1,1,uploadGL.RGBA,uploadGL.UNSIGNED_BYTE,null);')!
		}
		mut selected := [i32(0), 0, 0, 0]!
		C.vox_gl_int_parameter(0x0ba2, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		expected_error := if kind == 'webgl2' { '1282' } else { '1281' }
		assert runtime.evaluate_host('uploadGL.getError()')! == expected_error
		context.native.make_current()
	}
}
