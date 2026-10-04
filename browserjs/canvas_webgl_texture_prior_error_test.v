// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn test_public_nullable_and_bitmap_uploads_continue_after_actual_driver_errors() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_prior_error",width:2,height:2},"${kind}",null);globalThis.texture=gl.createTexture();gl.bindTexture(gl.TEXTURE_2D,texture);globalThis.fbo=gl.createFramebuffer();gl.bindFramebuffer(gl.FRAMEBUFFER,fbo);globalThis.redSource={width:1,height:1,data:new Uint8ClampedArray([255,0,0,255]),colorSpace:"srgb"};globalThis.blueSource={width:1,height:1,data:new Uint8ClampedArray([0,0,255,255]),colorSpace:"srgb"};globalThis.pixels=new Uint8Array(4);')!
		mut context := host.contexts['__created_prior_error'] or { panic('upload context') }
		mut cases := [
			['',
				'gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,gl.RGBA,gl.UNSIGNED_BYTE,redSource);gl.framebufferTexture2D(gl.FRAMEBUFFER,gl.COLOR_ATTACHMENT0,gl.TEXTURE_2D,texture,0);',
				'255,0,0,255'],
			['', 'gl.texSubImage2D(gl.TEXTURE_2D,0,0,0,gl.RGBA,gl.UNSIGNED_BYTE,blueSource);',
				'0,0,255,255'],
			['', 'gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,1,1,0,gl.RGBA,gl.UNSIGNED_BYTE,null);',
				'0,0,0,0'],
		]
		if kind == 'webgl2' {
			cases << [
				[
					'globalThis.buffer=gl.createBuffer();gl.bindBuffer(gl.PIXEL_UNPACK_BUFFER,buffer);gl.bufferData(gl.PIXEL_UNPACK_BUFFER,new Uint8Array([0,255,0,255]),gl.STATIC_DRAW);',
					'gl.texSubImage2D(gl.TEXTURE_2D,0,0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,null);',
					'0,255,0,255',
				],
				[
					'globalThis.arrayTexture=gl.createTexture();gl.bindTexture(gl.TEXTURE_2D_ARRAY,arrayTexture);',
					'gl.texImage3D(gl.TEXTURE_2D_ARRAY,0,gl.RGBA8,1,1,1,0,gl.RGBA,gl.UNSIGNED_BYTE,null);gl.framebufferTextureLayer(gl.FRAMEBUFFER,gl.COLOR_ATTACHMENT0,arrayTexture,0,0);',
					'0,255,0,255',
				],
				[
					'gl.bufferData(gl.PIXEL_UNPACK_BUFFER,new Uint8Array([0,0,255,255]),gl.STATIC_DRAW);',
					'gl.texSubImage3D(gl.TEXTURE_2D_ARRAY,0,0,0,0,1,1,1,gl.RGBA,gl.UNSIGNED_BYTE,null);',
					'0,0,255,255',
				],
				[
					'gl.bindBuffer(gl.PIXEL_UNPACK_BUFFER,null);',
					'gl.texImage3D(gl.TEXTURE_2D_ARRAY,0,gl.RGBA8,1,1,1,0,gl.RGBA,gl.UNSIGNED_BYTE,redSource);',
					'255,0,0,255',
				],
				[
					'',
					'gl.texSubImage3D(gl.TEXTURE_2D_ARRAY,0,0,0,0,1,1,1,gl.RGBA,gl.UNSIGNED_BYTE,blueSource);',
					'0,0,255,255',
				],
			]
		}
		for pair in cases {
			runtime.evaluate_host(pair[0])!
			assert context.get_error() == webgl.no_error
			context.native.make_current()
			C.vox_gl_enable(0xbad)
			runtime.evaluate_host(pair[1])!
			assert runtime.evaluate_host('gl.getError()===gl.INVALID_ENUM&&gl.getError()===gl.NO_ERROR')! == 'true'
			runtime.evaluate_host('gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,pixels);')!
			assert runtime.evaluate_host('pixels.join(",")')! == pair[2]
			assert context.get_error() == webgl.no_error
		}
	}
}
