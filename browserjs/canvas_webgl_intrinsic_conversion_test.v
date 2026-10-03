// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn test_actual_webgl_uses_captured_numeric_and_result_intrinsics() {
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
	runtime.evaluate_host(r'
 const gl=__webglContext({bridgeKey:"__created_intrinsic_source",width:2,height:2},"webgl2",null);
 const vertex=gl.createShader(gl.VERTEX_SHADER),fragment=gl.createShader(gl.FRAGMENT_SHADER),program=gl.createProgram();
 gl.shaderSource(vertex,"#version 300 es\nlayout(std140) uniform Block {vec4 position;};void main(){gl_Position=position;}");gl.shaderSource(fragment,"#version 300 es\nprecision mediump float;out vec4 color;void main(){color=vec4(1);}");
 gl.compileShader(vertex);gl.compileShader(fragment);gl.attachShader(program,vertex);gl.attachShader(program,fragment);gl.linkProgram(program);
 gl.drawBuffers([gl.BACK]);const expectedDrawError=gl.getError();
 const NativeF=Float32Array,NativeI=Int32Array,NativeU=Uint32Array,nativeNumber=Number;let intercepted=0;
 Object.defineProperty(nativeNumber,"isFinite",{get(){intercepted++;throw "author isFinite"},configurable:true});
 globalThis.String=function(){intercepted++;throw "author String"};
 for(const name of ["Float32Array","Int32Array","Uint32Array"])globalThis[name]=function(){intercepted++;throw "author constructor"};
 ')!
	assert runtime.evaluate_host(r'(function(){const order=[];gl.viewport({valueOf(){order.push("x");return NaN}},{valueOf(){order.push("y");return Infinity}},2,2);const viewport=gl.getParameter(gl.VIEWPORT);return intercepted===0&&order.join(",")==="x,y"&&viewport instanceof NativeI&&viewport.join(",")==="0,0,2,2"&&gl.getError()===gl.NO_ERROR})()')! == 'true'
	assert runtime.evaluate_host(r'(function(){const line=gl.getParameter(gl.ALIASED_LINE_WIDTH_RANGE),point=gl.getParameter(gl.ALIASED_POINT_SIZE_RANGE),viewport=gl.getParameter(gl.VIEWPORT),formats=gl.getParameter(gl.COMPRESSED_TEXTURE_FORMATS),samples=gl.getInternalformatParameter(gl.RENDERBUFFER,gl.RGBA8,gl.SAMPLES),index=gl.getUniformBlockIndex(program,"Block"),indices=gl.getActiveUniformBlockParameter(program,index,gl.UNIFORM_BLOCK_ACTIVE_UNIFORM_INDICES),attrib=gl.getVertexAttrib(0,gl.CURRENT_VERTEX_ATTRIB);return intercepted===0&&line instanceof NativeF&&line.length===2&&point instanceof NativeF&&viewport instanceof NativeI&&formats instanceof NativeU&&samples instanceof NativeI&&indices instanceof NativeU&&indices.length===1&&attrib instanceof NativeF&&attrib.length===4&&gl.getError()===gl.NO_ERROR})()')! == 'true'
	// Author conversion and iterator hooks still run in source WebIDL order.
	// The pinned sequence conversion propagates item errors without IteratorClose.
	assert runtime.evaluate_host(r'(function(){const order=[],iterable={[Symbol.iterator](){order.push("iterator");let step=0;return {next(){order.push("next");return step++?{done:true}:{done:false,value:{valueOf(){order.push("number");return gl.BACK}}}}}}};gl.drawBuffers(iterable);const result=gl.getUniformLocation(program,{[Symbol.toPrimitive](hint){order.push(hint);return "missing"}});return [result===null,intercepted,order.join(","),gl.getError()===expectedDrawError].join("|")})()')! == 'true|0|iterator,next,number,next,string|true'
	assert runtime.evaluate_host(r'(function(){const sentinel={},order=[],iterable={[Symbol.iterator](){return {next(){return {done:false,value:{valueOf(){order.push("number");throw sentinel}}}},return(){order.push("close");return {}}}}};try{gl.drawBuffers(iterable);return false}catch(error){return error===sentinel&&order.join(",")==="number"&&intercepted===0}})()')! == 'true'
}
