// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn buffer_slots_fixture() (&Runtime, &CanvasWebGLHost) {
	mut document := html.parse_document('<canvas></canvas>')
	mut host := CanvasWebGLHost.create(document)
	mut runtime := Runtime.create()
	host.install(mut runtime) or { panic(err) }
	key := host.elements.keys().filter(host.elements[it].local_name() == 'canvas')[0]
	runtime.evaluate_host('const __canvases=Object.create(null),state={bridgeKey:"${key}",width:2,height:2};function __canvasFor(s){return __canvases[s.bridgeKey]||(__canvases[s.bridgeKey]={state:s});}function __canvasDimension(s,key){return s[key];}function __element(s){return {__state:s};}') or { panic(err) }
	runtime.evaluate_host(webgl_bootstrap()) or { panic(err) }
	runtime.evaluate_host('const gl=__webglContext(state,"webgl2",{preserveDrawingBuffer:true});const buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);') or { panic(err) }
	return runtime, host
}

fn test_public_webgl_buffer_slots_ignore_author_properties_and_snapshot_after_conversions() {
	$if !darwin {
		return
	}
	mut runtime, _ := buffer_slots_fixture()
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(function(){const data=new Uint16Array([0x1111,0x2222,0x3333]),view=new Uint16Array(data.buffer,2,2);let reads=0;for(const name of ["buffer","byteOffset","byteLength","BYTES_PER_ELEMENT","values"])Object.defineProperty(view,name,{get(){reads++;throw name}});Object.defineProperty(view,Symbol.iterator,{get(){reads++;throw "iterator"}});const offset={valueOf(){view[1]=0x4444;return 1}};gl.bufferData(gl.ARRAY_BUFFER,view,gl.STATIC_DRAW,offset,1);const destination=new Uint16Array(1);for(const name of ["buffer","byteOffset","byteLength","BYTES_PER_ELEMENT"])Object.defineProperty(destination,name,{get(){reads++;throw name}});gl.getBufferSubData(gl.ARRAY_BUFFER,0,destination);return reads===0&&destination[0]===0x4444&&gl.getBufferParameter(gl.ARRAY_BUFFER,gl.BUFFER_SIZE)===2&&gl.getError()===gl.NO_ERROR})()')! == 'true'
	assert runtime.evaluate_host(r'(function(){const view=new DataView(new ArrayBuffer(4));view.setUint32(0,0x12345678);for(const name of ["buffer","byteOffset","byteLength"])Object.defineProperty(view,name,{get(){throw name}});gl.bufferData(gl.ARRAY_BUFFER,view,gl.STATIC_DRAW);const output=new Uint8Array(4);gl.getBufferSubData(gl.ARRAY_BUFFER,0,output);return output.join(",")==="18,52,86,120"&&gl.getError()===gl.NO_ERROR})()')! == 'true'
	assert runtime.evaluate_host(r'(function(){gl.clearColor(1,0,0,1);gl.clear(gl.COLOR_BUFFER_BIT);const destination=new Uint32Array(2);destination[0]=0x55555555;for(const name of ["buffer","byteOffset","byteLength","BYTES_PER_ELEMENT"])Object.defineProperty(destination,name,{get(){throw name}});gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,destination,1);return destination[0]===0x55555555&&destination[1]===0xff0000ff&&gl.getError()===gl.NO_ERROR})()')! == 'true'
}

fn test_public_webgl_typed_list_retains_actual_slots_and_later_argument_mutations() {
	$if !darwin {
		return
	}
	mut runtime, _ := buffer_slots_fixture()
	defer { runtime.close() }
	runtime.evaluate_host(r'const vertex=gl.createShader(gl.VERTEX_SHADER),fragment=gl.createShader(gl.FRAGMENT_SHADER);gl.shaderSource(vertex,"#version 300 es\nvoid main(){float x=gl_VertexID==1?3.0:-1.0;float y=gl_VertexID==2?3.0:-1.0;gl_Position=vec4(x,y,0,1);}");gl.shaderSource(fragment,"#version 300 es\nprecision mediump float;uniform vec4 tint;out vec4 color;void main(){color=tint;}");gl.compileShader(vertex);gl.compileShader(fragment);const program=gl.createProgram();gl.attachShader(program,vertex);gl.attachShader(program,fragment);gl.linkProgram(program);gl.useProgram(program);const tint=gl.getUniformLocation(program,"tint");')!
	assert runtime.evaluate_host(r'(function(){const color=new Float32Array([1,0,0,1]);for(const name of ["buffer","byteOffset","byteLength","BYTES_PER_ELEMENT","values"])Object.defineProperty(color,name,{get(){throw name}});Object.defineProperty(color,Symbol.iterator,{get(){throw "iterator"}});gl.uniform4fv(tint,color,{valueOf(){color[0]=0;color[1]=1;return 0}},4);gl.drawArrays(gl.TRIANGLES,0,3);const output=new Uint8Array(4);gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,output);return output.join(",")==="0,255,0,255"&&gl.getError()===gl.NO_ERROR})()')! == 'true'
	// Sequence conversion remains eager, before the optional offset conversion.
	assert runtime.evaluate_host(r'(function(){const color=[1,0,0,1];gl.uniform4fv(tint,color,{valueOf(){color[0]=0;color[2]=1;return 0}},4);gl.drawArrays(gl.TRIANGLES,0,3);const output=new Uint8Array(4);gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,output);return output.join(",")==="255,0,0,255"&&gl.getError()===gl.NO_ERROR})()')! == 'true'
	assert runtime.evaluate_host(r'(function(){if(typeof ArrayBuffer.prototype.transfer!=="function")return "unsupported";const data=new Uint8Array([1,2,3,4]);gl.bufferData(gl.ARRAY_BUFFER,data,{valueOf(){data.buffer.transfer();return gl.STATIC_DRAW}});return gl.getError()===gl.INVALID_VALUE?"pass":"early copy"})()')! in [
		'pass',
		'unsupported',
	]
}

fn test_public_webgl_generated_buffer_brands_fixed_length_and_allow_shared_rules() {
	$if !darwin {
		return
	}
	mut runtime, _ := buffer_slots_fixture()
	defer { runtime.close() }
	assert runtime.evaluate_host(r'(function(){const raw=new ArrayBuffer(4);const calls=[()=>gl.getBufferSubData(gl.ARRAY_BUFFER,0,raw),()=>gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,raw),()=>gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,1,1,0,gl.RGBA,gl.UNSIGNED_BYTE,raw)];return calls.every(call=>{try{call();return false}catch(error){return error instanceof TypeError}})&&gl.getError()===gl.NO_ERROR})()')! == 'true'
	assert runtime.evaluate_host(r'(function(){if(typeof ArrayBuffer.prototype.resize!=="function")return "unsupported";const buffer=new ArrayBuffer(4,{maxByteLength:8}),view=new Uint8Array(buffer);let later=0;try{gl.bufferData(gl.ARRAY_BUFFER,view,{valueOf(){later++;return gl.STATIC_DRAW}},0);return "accepted"}catch(error){return error instanceof TypeError&&error.message==="Not an object of type fixed-length Uint8Array"&&later===0?"pass":"wrong conversion"}})()')! in [
		'pass',
		'unsupported',
	]
	assert runtime.evaluate_host(r'(function(){if(typeof SharedArrayBuffer!=="function")return "unsupported";const backing=new SharedArrayBuffer(4),view=new Uint8Array(backing);view.set([1,2,3,4]);try{gl.bufferData(gl.ARRAY_BUFFER,view,gl.STATIC_DRAW);return "shared BufferSource accepted"}catch(error){if(!(error instanceof TypeError)||error.message!=="The array buffer object cannot be a SharedArrayBuffer")return "shared error"}gl.bufferData(gl.ARRAY_BUFFER,view,gl.STATIC_DRAW,0);const destination=new Uint8Array(4);gl.getBufferSubData(gl.ARRAY_BUFFER,0,destination);let later=0;try{gl.uniform1fv(null,new Float32Array(backing),{valueOf(){later++;return 0}});return "shared typed list accepted"}catch(error){return error instanceof TypeError&&error.message==="The array buffer object cannot be a SharedArrayBuffer"&&later===0&&destination.join(",")==="1,2,3,4"&&gl.getError()===gl.NO_ERROR?"pass":"shared typed list error"}})()')! in [
		'pass',
		'unsupported',
	]
}
