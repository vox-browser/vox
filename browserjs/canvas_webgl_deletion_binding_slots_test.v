// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

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
