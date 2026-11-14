// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn test_public_3d_byte_uploads_use_driver_storage_and_select_owner_before_bad_spans() {
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
	key := '__created_3d_upload'
	other_key := '__created_3d_upload_other'
	runtime.evaluate_host('globalThis.volumeGL=__webglContext({bridgeKey:"${key}",width:2,height:2},"webgl2",null);globalThis.volumeOther=__webglContext({bridgeKey:"${other_key}",width:2,height:2},"webgl2",null);volumeGL.viewport(1,2,3,4);volumeOther.viewport(9,10,11,12);globalThis.volumeTexture=volumeGL.createTexture();volumeGL.bindTexture(volumeGL.TEXTURE_3D,volumeTexture);')!
	mut context := host.contexts[key] or { panic('native 3D upload context') }
	mut other := host.contexts[other_key] or { panic('other 3D upload context') }
	mut native_texture := i32(0)
	C.vox_gl_int_parameter(0x806a, &native_texture)
	assert native_texture != 0
	runtime.evaluate_host('volumeGL.bindTexture(volumeGL.TEXTURE_3D,null);')!
	C.vox_gl_bind_texture(0x806f, u32(native_texture))
	result := runtime.evaluate_host(r'
 (function(){const gl=volumeGL;if(gl.getParameter(gl.TEXTURE_BINDING_3D)!==null)return "retained slot";
 gl.texImage3D(gl.TEXTURE_3D,0,gl.RGBA8,1,1,2,0,gl.RGBA,gl.UNSIGNED_BYTE,new Uint8Array([9,9,9,9,255,0,0,255,0,0,255,255]),4);if(gl.getError()!==gl.NO_ERROR)return "image upload";
 const framebuffer=gl.createFramebuffer();gl.bindFramebuffer(gl.FRAMEBUFFER,framebuffer);gl.framebufferTextureLayer(gl.FRAMEBUFFER,gl.COLOR_ATTACHMENT0,volumeTexture,0,1);if(gl.checkFramebufferStatus(gl.FRAMEBUFFER)!==gl.FRAMEBUFFER_COMPLETE)return "framebuffer";
 const pixel=new Uint8Array(4);gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,pixel);if(pixel.join(",")!=="0,0,255,255")return "image readback";
 gl.texSubImage3D(gl.TEXTURE_3D,0,0,0,1,1,1,1,gl.RGBA,gl.UNSIGNED_BYTE,new Uint8Array([9,9,9,9,64,128,192,255]),4);if(gl.getError()!==gl.NO_ERROR)return "sub image upload";gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,pixel);if(pixel.join(",")!=="64,128,192,255")return "sub image readback";return true})()
 ')!
	assert result == 'true'
	pixels := [u8(255), 0, 0, 255]
	C.vox_gl_tex_image3d(0xbad, 0, 0x8058, -1, 1, 1, 1, 0x1908, 0x1401, pixels.len, pixels.data)
	expected_image := C.vox_gl_get_error()
	other.native.make_current()
	runtime.evaluate_host('volumeGL.texImage3D(0xbad,0,volumeGL.RGBA8,-1,1,1,1,volumeGL.RGBA,volumeGL.UNSIGNED_BYTE,new Uint8Array([255,0,0,255]));')!
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(0x0ba2, &selected[0])
	assert selected == [i32(1), 2, 3, 4]!
	assert runtime.evaluate_host('volumeGL.getError()')! == expected_image.str()
	for call in [
		'volumeGL.texImage3D(0xbad,0,volumeGL.RGBA8,1,1,1,0,volumeGL.RGBA,volumeGL.UNSIGNED_BYTE,new Uint8Array(4),5);',
		'volumeGL.texSubImage3D(0xbad,0,0,0,0,1,1,1,volumeGL.RGBA,volumeGL.UNSIGNED_BYTE,new Uint8Array(4),5);',
	] {
		other.native.make_current()
		runtime.evaluate_host(call)!
		C.vox_gl_int_parameter(0x0ba2, &selected[0])
		assert selected == [i32(1), 2, 3, 4]!
		assert runtime.evaluate_host('volumeGL.getError()')! == '1282'
	}
	context.native.make_current()
}
