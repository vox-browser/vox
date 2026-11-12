// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn public_framebuffer_layer_source_owner(expected [4]i32) {
	mut selected := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(0x0ba2, &selected[0])
	assert selected == expected
}

fn test_public_framebuffer_texture_layer_owner_and_handle_gate_after_idl_conversion() {
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
	runtime.evaluate_host('globalThis.layerSourceGL=__webglContext({bridgeKey:"__created_framebuffer_layer_source",width:2,height:2},"webgl2",null);globalThis.layerSourceOther=__webglContext({bridgeKey:"__created_framebuffer_layer_other",width:2,height:2},"webgl2",null);globalThis.layerSourceTexture=layerSourceGL.createTexture(),layerForeignTexture=layerSourceOther.createTexture();layerSourceGL.viewport(1,2,3,4);layerSourceOther.viewport(9,10,11,12);')!
	mut context := host.contexts['__created_framebuffer_layer_source'] or { panic('layer context') }
	mut other := host.contexts['__created_framebuffer_layer_other'] or { panic('other layer context') }
	other.native.make_current()
	runtime.evaluate_host('layerSourceGL.framebufferTextureLayer(0xbad,0xbad,layerForeignTexture,-1,-1)')!
	public_framebuffer_layer_source_owner([i32(1), 2, 3, 4]!)
	assert context.get_error() == webgl.invalid_operation
	assert runtime.evaluate_host(r'(function(){const gl=layerSourceGL;gl.bindTexture(gl.TEXTURE_2D_ARRAY,layerSourceTexture);gl.texImage3D(gl.TEXTURE_2D_ARRAY,0,gl.RGBA8,1,1,2,0,gl.RGBA,gl.UNSIGNED_BYTE,new Uint8Array([1,2,3,255,4,5,6,255]));const fb=gl.createFramebuffer();gl.bindFramebuffer(gl.FRAMEBUFFER,fb);gl.framebufferTextureLayer(gl.FRAMEBUFFER,gl.COLOR_ATTACHMENT0,layerSourceTexture,0,1);const pixels=new Uint8Array(4);gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,pixels);return pixels.join(",")==="4,5,6,255"&&gl.getError()===gl.NO_ERROR})()')! == 'true'
	for pair in [
		['0xbad,36064,layerSourceTexture,0,0', '1280'],
		['36160,0xbad,layerSourceTexture,0,0', '1280'],
		['36160,36064,layerSourceTexture,-1,0', '1281'],
		['36160,36064,layerSourceTexture,0,-1', '1281'],
		['36160,36064,null,0,0', '0'],
	] {
		other.native.make_current()
		runtime.evaluate_host('layerSourceGL.framebufferTextureLayer(${pair[0]})')!
		public_framebuffer_layer_source_owner([i32(1), 2, 3, 4]!)
		assert runtime.evaluate_host('layerSourceGL.getError()')! == pair[1]
	}
	runtime.evaluate_host('layerSourceGL.deleteTexture(layerSourceTexture)')!
	other.native.make_current()
	runtime.evaluate_host('layerSourceGL.framebufferTextureLayer(0xbad,0xbad,layerSourceTexture,-1,-1)')!
	public_framebuffer_layer_source_owner([i32(1), 2, 3, 4]!)
	assert context.get_error() == webgl.invalid_operation
	other.native.make_current()
	assert runtime.evaluate_host(r'(function(){try{layerSourceGL.framebufferTextureLayer(36160,36064,{},0,0);return false}catch(error){return error instanceof TypeError}})()')! == 'true'
	public_framebuffer_layer_source_owner([i32(9), 10, 11, 12]!)
	other.native.make_current()
	assert runtime.evaluate_host(r'(function(){const marker={};try{layerSourceGL.framebufferTextureLayer(36160,36064,layerForeignTexture,0,{valueOf(){throw marker}});return false}catch(error){return error===marker}})()')! == 'true'
	public_framebuffer_layer_source_owner([i32(9), 10, 11, 12]!)
}
