// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn test_public_webgl_excludes_source_fixme_numeric_unpack_overloads_without_execution() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<canvas></canvas>')
	mut host := CanvasWebGLHost.create(document)
	mut runtime := Runtime.create()
	defer { runtime.close() }
	host.install(mut runtime)!
	key := host.elements.keys().filter(host.elements[it].local_name() == 'canvas')[0]
	runtime.evaluate_host('const __canvases=Object.create(null),state={bridgeKey:"${key}",width:2,height:2};function __canvasFor(s){return __canvases[s.bridgeKey]||(__canvases[s.bridgeKey]={state:s});}function __canvasDimension(s,key){return s[key];}function __element(s){return {__state:s};}')!
	runtime.evaluate_host(webgl_bootstrap())!
	runtime.evaluate_host('const gl=__webglContext(state,"webgl2",{preserveDrawingBuffer:true});')!
	mut context := host.contexts[key] or { panic('context') }
	context.native.set_native_call_recording(true)
	assert runtime.evaluate_host(r'(function(){const calls=[()=>gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,1,1,0,gl.RGBA,gl.UNSIGNED_BYTE,0),()=>gl.texSubImage2D(gl.TEXTURE_2D,0,0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,0),()=>gl.texImage3D(gl.TEXTURE_3D,0,gl.RGBA,1,1,1,0,gl.RGBA,gl.UNSIGNED_BYTE,0),()=>gl.texSubImage3D(gl.TEXTURE_3D,0,0,0,0,1,1,1,gl.RGBA,gl.UNSIGNED_BYTE,0),()=>gl.compressedTexImage2D(gl.TEXTURE_2D,0,0x83f1,4,4,0,8,0),()=>gl.compressedTexSubImage2D(gl.TEXTURE_2D,0,0,0,4,4,0x83f1,8,0),()=>gl.compressedTexImage3D(gl.TEXTURE_3D,0,0x83f1,4,4,1,0,8,0),()=>gl.compressedTexSubImage3D(gl.TEXTURE_3D,0,0,0,0,4,4,1,0x83f1,8,0)];return calls.every(call=>{try{call();return false}catch(error){return error instanceof TypeError}})&&gl.getError()===gl.NO_ERROR})()')! == 'true'
	assert context.native.native_calls().len == 0
	// The pinned overload resolver's pre-distinguishing conversion is still
	// a FIXME: a failed ambiguous selection reads no numeric argument getters.
	assert runtime.evaluate_host(r'(function(){let converted=0;const target={valueOf(){converted++;return gl.TEXTURE_2D}};try{gl.texImage2D(target,0,gl.RGBA,1,1,0,gl.RGBA,gl.UNSIGNED_BYTE,0);return false}catch(error){return error instanceof TypeError&&error.message==="Overload resolution failed"&&converted===0}})()')! == 'true'
	assert context.native.native_calls().len == 0
	// ArrayBufferData distinguishes BufferSource, not ArrayBufferView. A raw
	// buffer therefore fails this ambiguous view/source selection before ToNumber.
	assert runtime.evaluate_host(r'(function(){let converted=0;const target={valueOf(){converted++;return gl.TEXTURE_2D}};try{gl.texImage2D(target,0,gl.RGBA,1,1,0,gl.RGBA,gl.UNSIGNED_BYTE,new ArrayBuffer(4));return false}catch(error){return error instanceof TypeError&&error.message==="Overload resolution failed"&&converted===0}})()')! == 'true'
	assert context.native.native_calls().len == 0
}

fn test_public_webgl_numeric_buffer_data_object_and_supported_nullable_view_overloads() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<canvas></canvas>')
	mut host := CanvasWebGLHost.create(document)
	mut runtime := Runtime.create()
	defer { runtime.close() }
	host.install(mut runtime)!
	key := host.elements.keys().filter(host.elements[it].local_name() == 'canvas')[0]
	runtime.evaluate_host('const __canvases=Object.create(null),state={bridgeKey:"${key}",width:2,height:2};function __canvasFor(s){return __canvases[s.bridgeKey]||(__canvases[s.bridgeKey]={state:s});}function __canvasDimension(s,key){return s[key];}function __element(s){return {__state:s};}')!
	runtime.evaluate_host(webgl_bootstrap())!
	assert runtime.evaluate_host(r'(function(){globalThis.gl=__webglContext(state,"webgl2",{preserveDrawingBuffer:true});const buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);let converted=0;gl.bufferData(gl.ARRAY_BUFFER,{valueOf(){converted++;return 8}},gl.STATIC_DRAW);return converted===1&&gl.getBufferParameter(gl.ARRAY_BUFFER,gl.BUFFER_SIZE)===8&&gl.getError()===gl.NO_ERROR})()')! == 'true'
	assert runtime.evaluate_host(r'(function(){const texture=gl.createTexture();gl.bindTexture(gl.TEXTURE_2D,texture);gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,1,1,0,gl.RGBA,gl.UNSIGNED_BYTE,null);gl.texSubImage2D(gl.TEXTURE_2D,0,0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,new Uint32Array([0,0xff00ff00]),1);const framebuffer=gl.createFramebuffer();gl.bindFramebuffer(gl.FRAMEBUFFER,framebuffer);gl.framebufferTexture2D(gl.FRAMEBUFFER,gl.COLOR_ATTACHMENT0,gl.TEXTURE_2D,texture,0);const pixels=new Uint8Array(4);gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,pixels);return pixels.join(",")==="0,255,0,255"&&gl.getError()===gl.NO_ERROR})()')! == 'true'
}
