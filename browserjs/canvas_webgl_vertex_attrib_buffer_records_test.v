// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn test_actual_vertex_attrib_buffer_query_wraps_fresh_native_objects_even_for_zero_handle() {
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
 (function(){for(const [kind,key] of [["webgl","__created_query_buffer_one"],["webgl2","__created_query_buffer_two"]]){
 const gl=__webglContext({bridgeKey:key,width:2,height:2},kind,null),zero=gl.getVertexAttrib(0,gl.VERTEX_ATTRIB_ARRAY_BUFFER_BINDING),nextZero=gl.getVertexAttrib(0,gl.VERTEX_ATTRIB_ARRAY_BUFFER_BINDING);
 if(!(zero instanceof WebGLBuffer)||!(nextZero instanceof WebGLBuffer)||zero===nextZero||gl.isBuffer(zero)||gl.getError()!==gl.NO_ERROR)return false;
 const original=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,original);gl.bufferData(gl.ARRAY_BUFFER,new Uint8Array([1,2,3,4]),gl.STATIC_DRAW);gl.vertexAttribPointer(0,1,gl.UNSIGNED_BYTE,false,0,0);
 const first=gl.getVertexAttrib(0,gl.VERTEX_ATTRIB_ARRAY_BUFFER_BINDING),second=gl.getVertexAttrib(0,gl.VERTEX_ATTRIB_ARRAY_BUFFER_BINDING);
 if(!(first instanceof WebGLBuffer)||!(second instanceof WebGLBuffer)||first===second||first===original||second===original||!gl.isBuffer(first))return false;
 gl.bindBuffer(gl.ARRAY_BUFFER,first);if(gl.getParameter(gl.ARRAY_BUFFER_BINDING)!==first||gl.getBufferParameter(gl.ARRAY_BUFFER,gl.BUFFER_SIZE)!==4)return false;
 gl.bufferSubData(gl.ARRAY_BUFFER,1,new Uint8Array([9]));
 if(kind==="webgl2"){const data=new Uint8Array(4);gl.getBufferSubData(gl.ARRAY_BUFFER,0,data);if(data.join(",")!=="1,9,3,4")return false;}
 if(gl.getError()!==gl.NO_ERROR)return false;
 const invalid=gl.getVertexAttrib(0xffffffff,gl.VERTEX_ATTRIB_ARRAY_BUFFER_BINDING);if(!(invalid instanceof WebGLBuffer)||gl.isBuffer(invalid)||gl.getError()!==gl.INVALID_VALUE||gl.getError()!==gl.NO_ERROR)return false;
 }return true})()
 ')!
	assert result == 'true'
}
