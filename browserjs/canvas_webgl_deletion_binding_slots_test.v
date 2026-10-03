// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html
import webgl
import x.json2

fn test_retained_typed_objects_receive_one_host_wrapper_after_deletion() {
	mut document := html.parse_document('<canvas></canvas>')
	mut host := CanvasWebGLHost.create(document)
	mut context := webgl.WebGLRenderingContext.new(.webgl2, webgl.WebGLContextAttributes{}, [])
	buffer := context.create_buffer()
	context.bind_buffer(webgl.array_buffer, buffer)
	context.delete_buffer(buffer)
	rbo := context.create_renderbuffer()
	context.bind_renderbuffer(webgl.renderbuffer, rbo)
	context.delete_renderbuffer(rbo)
	for pname in [webgl.array_buffer_binding, webgl.renderbuffer_binding] {
		value := context.get_parameter(pname)
		first := host.parameter(context, value)
		second := host.parameter(context, value)
		assert first is map[string]json2.Any
		assert second is map[string]json2.Any
		assert wg_handle(first) == wg_handle(second)
		assert wg_handle(first) != ''
		if pname == webgl.array_buffer_binding {
			retained := host.buffers[wg_handle(first)] or { panic('owned buffer wrapper') }
			assert voidptr(retained) == voidptr(buffer)
		} else {
			retained := host.renderbuffers[wg_handle(first)] or { panic('owned renderbuffer wrapper') }
			assert voidptr(retained) == voidptr(rbo)
		}
	}
	assert host.next_handle == 2
	assert context.get_error() == webgl.no_error
}

fn test_actual_deleted_buffers_and_renderbuffers_retain_source_binding_identity() {
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
	result := runtime.evaluate_host(r'
 (function(){for(const [kind,key] of [["webgl","__created_delete_one"],["webgl2","__created_delete_two"]]){
 const gl=__webglContext({bridgeKey:key,width:2,height:2},kind,null),buffer=gl.createBuffer();
 gl.bindBuffer(gl.ARRAY_BUFFER,buffer);gl.bufferData(gl.ARRAY_BUFFER,new Uint8Array([1,2]),gl.STATIC_DRAW);gl.deleteBuffer(buffer);
 if(gl.getParameter(gl.ARRAY_BUFFER_BINDING)!==buffer||gl.isBuffer(buffer)||gl.getBufferParameter(gl.ARRAY_BUFFER,gl.BUFFER_SIZE)!==0||gl.getError()!==gl.INVALID_OPERATION||gl.getError()!==gl.NO_ERROR)return false;
 gl.bindBuffer(gl.ARRAY_BUFFER,buffer);if(gl.getError()!==gl.INVALID_OPERATION)return false;
 gl.bindBuffer(gl.ARRAY_BUFFER,null);if(gl.getParameter(gl.ARRAY_BUFFER_BINDING)!==null)return false;
 if(kind==="webgl2"){const copy=gl.createBuffer();gl.bindBuffer(gl.COPY_WRITE_BUFFER,copy);gl.deleteBuffer(copy);if(gl.getParameter(gl.COPY_WRITE_BUFFER_BINDING)!==copy)return false;gl.bindBuffer(gl.COPY_WRITE_BUFFER,null);if(gl.getParameter(gl.COPY_WRITE_BUFFER_BINDING)!==null)return false;}
 const rbo=gl.createRenderbuffer();gl.bindRenderbuffer(gl.RENDERBUFFER,rbo);gl.deleteRenderbuffer(rbo);
 if(gl.getParameter(gl.RENDERBUFFER_BINDING)!==rbo||gl.isRenderbuffer(rbo))return false;
 gl.bindRenderbuffer(gl.RENDERBUFFER,rbo);if(gl.getError()!==gl.INVALID_OPERATION)return false;
 gl.bindRenderbuffer(gl.RENDERBUFFER,null);if(gl.getParameter(gl.RENDERBUFFER_BINDING)!==null||gl.getError()!==gl.NO_ERROR)return false;
 }return true})()
 ')!
	assert result == 'true'
}
