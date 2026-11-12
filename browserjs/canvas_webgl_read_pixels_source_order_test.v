// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl

fn read_pixels_public_selected_viewport() [4]i32 {
	mut value := [i32(0), 0, 0, 0]!
	C.vox_gl_int_parameter(webgl.viewport, &value[0])
	return value
}

fn test_public_read_pixels_retains_source_body_owner_and_real_readback_after_errors() {
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
		runtime.evaluate_host('globalThis.gl=__webglContext({bridgeKey:"__created_read_source",width:2,height:2},"${kind}",null);globalThis.other=__webglContext({bridgeKey:"__created_read_other",width:2,height:2},"${kind}",null);gl.clearColor(1,0.25,0.5,1);gl.clear(gl.COLOR_BUFFER_BIT);gl.viewport(1,2,3,4);other.viewport(9,10,11,12);globalThis.pixels=new Uint8Array(12);pixels.fill(99);')!
		mut context := host.contexts['__created_read_source'] or { panic('read owner') }
		mut other := host.contexts['__created_read_other'] or { panic('other owner') }
		context.native.make_current()
		C.vox_gl_enable(0xbad)
		other.native.make_current()
		runtime.evaluate_host('gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,pixels);')!
		assert read_pixels_public_selected_viewport() == [i32(1), 2, 3, 4]!
		assert runtime.evaluate_host('pixels.join(",")')! == '255,64,128,255,99,99,99,99,99,99,99,99'
		assert runtime.evaluate_host('gl.getError()===gl.INVALID_ENUM&&gl.getError()===gl.NO_ERROR')! == 'true'
		other.native.make_current()
		runtime.evaluate_host('gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,null);')!
		assert read_pixels_public_selected_viewport() == if kind == 'webgl' {
			[i32(1), 2, 3, 4]!
		} else {
			[i32(9), 10, 11, 12]!
		}
		assert context.get_error() == webgl.invalid_value
		other.native.make_current()
		assert runtime.evaluate_host('(function(){const marker={};try{gl.readPixels({valueOf(){throw marker}},0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,pixels);return false}catch(error){return error===marker}})()')! == 'true'
		assert read_pixels_public_selected_viewport() == [i32(9), 10, 11, 12]!
		other.native.make_current()
		detached := runtime.evaluate_host('(function(){if(typeof ArrayBuffer.prototype.transfer!=="function")return "unsupported";const backing=new ArrayBuffer(4),view=new Uint8Array(backing);backing.transfer();gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,view);return "called"})()')!
		assert detached in ['called', 'unsupported']
		if detached == 'called' {
			assert read_pixels_public_selected_viewport() == [i32(1), 2, 3, 4]!
			assert context.get_error() == webgl.invalid_operation
		}
		if kind == 'webgl2' {
			other.native.make_current()
			runtime.evaluate_host('gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,4);')!
			assert read_pixels_public_selected_viewport() == [i32(1), 2, 3, 4]!
			assert context.get_error() == webgl.invalid_operation
			runtime.evaluate_host('globalThis.buffer=gl.createBuffer();gl.bindBuffer(gl.PIXEL_PACK_BUFFER,buffer);gl.bufferData(gl.PIXEL_PACK_BUFFER,new Uint8Array(12).fill(99),gl.STATIC_DRAW);')!
			context.native.make_current()
			C.vox_gl_enable(0xbad)
			other.native.make_current()
			runtime.evaluate_host('gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,4);')!
			assert read_pixels_public_selected_viewport() == [i32(1), 2, 3, 4]!
			assert runtime.evaluate_host('gl.getError()===gl.INVALID_ENUM&&gl.getError()===gl.NO_ERROR')! == 'true'
			runtime.evaluate_host('gl.getBufferSubData(gl.PIXEL_PACK_BUFFER,0,pixels);')!
			assert runtime.evaluate_host('pixels.join(",")')! == '99,99,99,99,255,64,128,255,99,99,99,99'
			other.native.make_current()
			runtime.evaluate_host('gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,pixels);')!
			assert read_pixels_public_selected_viewport() == [i32(1), 2, 3, 4]!
			assert context.get_error() == webgl.invalid_operation
		}
		assert context.get_error() == webgl.no_error
		assert other.get_error() == webgl.no_error
	}
}
