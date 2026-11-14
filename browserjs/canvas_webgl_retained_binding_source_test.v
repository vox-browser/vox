// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn test_actual_indexed_binds_keep_source_generic_wrapper_identity() {
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
 (function(){const gl=__webglContext({bridgeKey:"__created_indexed_source",width:2,height:2},"webgl2",null);
 for(const target of [gl.UNIFORM_BUFFER,gl.TRANSFORM_FEEDBACK_BUFFER]){const pname=target===gl.UNIFORM_BUFFER?gl.UNIFORM_BUFFER_BINDING:gl.TRANSFORM_FEEDBACK_BUFFER_BINDING,original=gl.createBuffer(),indexed=gl.createBuffer();
 gl.bindBufferBase(target,0,indexed);if(gl.getParameter(pname)!==null)return "initial retained";
 gl.bindBuffer(target,original);gl.bufferData(target,32,gl.STATIC_DRAW);
 gl.bindBufferBase(target,0,indexed);if(gl.getParameter(pname)!==original)return "base retained";
 gl.bufferData(target,32,gl.STATIC_DRAW);gl.bindBufferRange(target,0,indexed,0,16);if(gl.getParameter(pname)!==original)return "range retained";
 gl.bindBufferBase(target,0,null);if(gl.getParameter(pname)!==original)return "clear base retained";
 gl.bindBufferRange(target,0,null,0,16);if(gl.getParameter(pname)!==original||gl.getError()!==gl.NO_ERROR)return "clear range retained";
 }return true})()
 ')!
	assert result == 'true'
	mut actual := i32(-1)
	C.vox_gl_int_parameter(0x8c8f, &actual)
	assert actual == 0
}

fn test_actual_vao_changes_keep_source_element_wrapper_identity() {
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
 (function(){for(const kind of ["webgl","webgl2"]){const gl=__webglContext({bridgeKey:"__created_vao_source_"+kind,width:2,height:2},kind,null),ext=kind==="webgl"?gl.getExtension("OES_vertex_array_object"):null;
 const create=()=>ext?ext.createVertexArrayOES():gl.createVertexArray(),bind=value=>ext?ext.bindVertexArrayOES(value):gl.bindVertexArray(value),remove=value=>ext?ext.deleteVertexArrayOES(value):gl.deleteVertexArray(value);
 const initial=gl.createBuffer(),retained=gl.createBuffer(),array=create();gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER,initial);
 bind(array);if(gl.getParameter(gl.ELEMENT_ARRAY_BUFFER_BINDING)!==initial)return "bind retained";
 gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER,retained);bind(null);if(gl.getParameter(gl.ELEMENT_ARRAY_BUFFER_BINDING)!==retained)return "clear retained";
 bind(array);remove(array);if(gl.getParameter(gl.ELEMENT_ARRAY_BUFFER_BINDING)!==retained||gl.getError()!==gl.NO_ERROR)return "delete retained";
 }return true})()
 ')!
	assert result == 'true'
}
