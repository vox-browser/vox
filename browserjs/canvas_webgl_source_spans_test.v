module browserjs

import html

fn test_public_webgl_buffer_texture_and_uniform_source_element_spans() {
	$if darwin {
		mut document := html.parse_document('<canvas width="2" height="2"></canvas>')
		mut host := CanvasWebGLHost.create(document)
		mut runtime := Runtime.create()
		defer { runtime.close() }
		host.install(mut runtime)!
		key := host.elements.keys().filter(host.elements[it].local_name() == 'canvas')[0]
		runtime.evaluate_host('const __canvases=Object.create(null),state={bridgeKey:"${key}",width:2,height:2};function __canvasFor(s){return __canvases[s.bridgeKey]||(__canvases[s.bridgeKey]={state:s});}function __canvasDimension(s,key){return s[key];}function __element(s){return {__state:s};}')!
		runtime.evaluate_host(webgl_bootstrap())!
		runtime.evaluate_host('const gl=__webglContext(state,"webgl2",{preserveDrawingBuffer:true});const buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);const original=new Uint16Array([0x8888,0x1111,0x2222,0x3333,0x4444,0x5555]);const view=new Uint16Array(original.buffer,2,4);gl.bufferData(gl.ARRAY_BUFFER,view,gl.STATIC_DRAW,1,2);const destination=new Uint16Array(4);destination.fill(0x9999);gl.getBufferSubData(gl.ARRAY_BUFFER,0,destination,1,2);')!
		assert runtime.evaluate_host('destination.join(",")')! == '39321,8738,13107,39321'
		assert runtime.evaluate_host('gl.getBufferParameter(gl.ARRAY_BUFFER,gl.BUFFER_SIZE)')! == '4'
		assert runtime.evaluate_host('gl.bufferSubData(gl.ARRAY_BUFFER,0,view,3,1);gl.getBufferSubData(gl.ARRAY_BUFFER,0,destination,0,2);destination.join(",")')! == '17476,13107,13107,39321'
		assert runtime.evaluate_host('gl.getError()')! == '0'
		assert runtime.evaluate_host('gl.bufferData(gl.ARRAY_BUFFER,null,gl.STATIC_DRAW);gl.getError()')! == '1281'
		assert runtime.evaluate_host('gl.bufferData(gl.ARRAY_BUFFER,view,gl.STATIC_DRAW,5,0);gl.getError()')! == '1281'
		assert runtime.evaluate_host('gl.bufferSubData(gl.ARRAY_BUFFER,0,view,18446744073709549568);gl.getError()')! == '1281'
		assert runtime.evaluate_host('gl.getBufferSubData(gl.ARRAY_BUFFER,0,destination,18446744073709549568,1);gl.getError()')! == '1281'
		runtime.evaluate_host('const texture=gl.createTexture();gl.bindTexture(gl.TEXTURE_2D,texture);gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,1,1,0,gl.RGBA,gl.UNSIGNED_BYTE,new Uint32Array([0xffffffff,0xff0000ff]),1);const fbo=gl.createFramebuffer();gl.bindFramebuffer(gl.FRAMEBUFFER,fbo);gl.framebufferTexture2D(gl.FRAMEBUFFER,gl.COLOR_ATTACHMENT0,gl.TEXTURE_2D,texture,0);const pixels=new Uint8Array(4);gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,pixels);')!
		assert runtime.evaluate_host('pixels.join(",")')! == '255,0,0,255'
		assert runtime.evaluate_host('gl.texSubImage2D(gl.TEXTURE_2D,0,0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,new Uint16Array([0x9999,0xff00,0xff00]),1);gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,pixels);pixels.join(",")')! == '0,255,0,255'
		assert runtime.evaluate_host('gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,1,1,0,gl.RGBA,gl.UNSIGNED_BYTE,new Uint8Array(4),5);gl.getError()')! == '1282'
		runtime.evaluate_host('gl.bindFramebuffer(gl.FRAMEBUFFER,null);const vertex=gl.createShader(gl.VERTEX_SHADER);gl.shaderSource(vertex,"#version 300 es\\nvoid main(){float x=gl_VertexID==1?3.0:-1.0;float y=gl_VertexID==2?3.0:-1.0;gl_Position=vec4(x,y,0,1);}");gl.compileShader(vertex);const fragment=gl.createShader(gl.FRAGMENT_SHADER);gl.shaderSource(fragment,"#version 300 es\\nprecision mediump float;uniform vec4 tint;uniform ivec2 integer;uniform uvec2 unsignedValue;out vec4 color;void main(){color=tint+vec4(float(integer.x+int(unsignedValue.x))*0.0);}");gl.compileShader(fragment);const program=gl.createProgram();gl.attachShader(program,vertex);gl.attachShader(program,fragment);gl.linkProgram(program);gl.useProgram(program);const tint=gl.getUniformLocation(program,"tint");gl.uniform4fv(tint,new Float32Array([9,9,1,0.25,0.5,1,7]),2,4);gl.drawArrays(gl.TRIANGLES,0,3);gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,pixels);')!
		assert runtime.evaluate_host('pixels.join(",")')! == '255,64,128,255'
		assert runtime.evaluate_host('gl.getError()')! == '0'
		assert runtime.evaluate_host('gl.uniform4fv(tint,new Float32Array(4),5,0);gl.getError()')! == '1281'
		assert runtime.evaluate_host('gl.uniform4fv(null,new Float32Array(4),5,0);gl.getError()')! == '0'
		assert runtime.evaluate_host('gl.clearBufferfv(gl.COLOR,0,new Float32Array([99,0,1,0,1,99]),1);gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,pixels);pixels.join(",")')! == '0,255,0,255'
		assert runtime.evaluate_host('gl.getError()')! == '0'
		assert runtime.evaluate_host('gl.compressedTexImage2D(gl.TEXTURE_2D,0,0xbad,4,4,0,new Uint8Array(0),1);gl.getError()')! == '1280'
		resizable_result := runtime.evaluate_host('(()=>{if(typeof ArrayBuffer.prototype.resize!=="function")return "unsupported";const rab=new ArrayBuffer(16,{maxByteLength:32}),view=new Float32Array(rab,8,2);rab.resize(4);const calls=[()=>gl.bufferData(gl.ARRAY_BUFFER,view,gl.STATIC_DRAW),()=>gl.bufferData(gl.ARRAY_BUFFER,view,gl.STATIC_DRAW,1),()=>gl.uniform4fv(tint,view),()=>gl.readPixels(0,0,0,0,gl.RGBA,gl.UNSIGNED_BYTE,view)];return calls.every(call=>{try{call();return false}catch(error){return error instanceof TypeError&&error.message==="Not an object of type fixed-length Float32Array"}})?"pass":"restricted buffer";})()')!
		assert resizable_result in ['pass', 'unsupported']
		detached_result := runtime.evaluate_host('(()=>{if(typeof ArrayBuffer.prototype.transfer!=="function")return "unsupported";gl.uniform4fv(tint,new Float32Array(0));const emptyUniformError=gl.getError();const buffer=new ArrayBuffer(16),view=new Float32Array(buffer),image={width:1,height:1,data:new Uint8ClampedArray(buffer)};buffer.transfer();gl.bufferData(gl.ARRAY_BUFFER,view,gl.STATIC_DRAW);if(gl.getError()!==1281)return "detached buffer";gl.uniform4fv(tint,view);if(gl.getError()!==emptyUniformError)return "detached uniform default";gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,gl.RGBA,gl.UNSIGNED_BYTE,image);if(gl.getError()!==1281)return "detached ImageData";return "pass";})()')!
		assert detached_result in ['pass', 'unsupported']
	}
}
