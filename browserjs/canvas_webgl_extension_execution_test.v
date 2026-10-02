module browserjs

import html

fn test_public_angle_instanced_draws_use_native_per_instance_attributes() {
	$if darwin {
		mut document := html.parse_document('<canvas width="2" height="2"></canvas>')
		mut host := CanvasWebGLHost.create(document)
		mut runtime := Runtime.create()
		defer { runtime.close() }
		host.install(mut runtime)!
		key := host.elements.keys().filter(host.elements[it].local_name() == 'canvas')[0]
		runtime.evaluate_host('const __canvases=Object.create(null),state={bridgeKey:"${key}",width:2,height:2};function __canvasFor(s){return __canvases[s.bridgeKey]||(__canvases[s.bridgeKey]={state:s});}function __canvasDimension(s,key){return s[key];}function __element(s){return {__state:s};}')!
		runtime.evaluate_host(webgl_bootstrap())!
		assert runtime.evaluate_host('const gl=__webglContext(state,"webgl",{preserveDrawingBuffer:true}),ext=gl.getExtension("ANGLE_instanced_arrays");ext!==null&&ext===gl.getExtension("angle_instanced_arrays")&&typeof ext.drawArraysInstancedANGLE==="function"')! == 'true'
		runtime.evaluate_host('const vertex=gl.createShader(gl.VERTEX_SHADER);gl.shaderSource(vertex,"attribute vec2 position;attribute vec4 tint;varying vec4 color;void main(){gl_Position=vec4(position,0,1);color=tint;}");gl.compileShader(vertex);const fragment=gl.createShader(gl.FRAGMENT_SHADER);gl.shaderSource(fragment,"precision mediump float;varying vec4 color;void main(){gl_FragColor=color;}");gl.compileShader(fragment);const program=gl.createProgram();gl.attachShader(program,vertex);gl.attachShader(program,fragment);gl.bindAttribLocation(program,0,"position");gl.bindAttribLocation(program,1,"tint");gl.linkProgram(program);gl.useProgram(program);const positions=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,positions);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([-1,-1,3,-1,-1,3]),gl.STATIC_DRAW);gl.vertexAttribPointer(0,2,gl.FLOAT,false,0,0);gl.enableVertexAttribArray(0);const tints=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,tints);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([1,0,0,1,0,1,0,1]),gl.STATIC_DRAW);gl.vertexAttribPointer(1,4,gl.FLOAT,false,0,0);gl.enableVertexAttribArray(1);ext.vertexAttribDivisorANGLE(1,1);const pixels=new Uint8Array(4);')!
		assert runtime.evaluate_host('gl.getVertexAttrib(1,ext.VERTEX_ATTRIB_ARRAY_DIVISOR_ANGLE)')! == '1'
		assert runtime.evaluate_host('ext.drawArraysInstancedANGLE(gl.TRIANGLES,0,3,1);gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,pixels);pixels.join(",")')! == '255,0,0,255'
		assert runtime.evaluate_host('ext.drawArraysInstancedANGLE(gl.TRIANGLES,0,3,2);gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,pixels);pixels.join(",")')! == '0,255,0,255'
		assert runtime.evaluate_host('const indices=gl.createBuffer();gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER,indices);gl.bufferData(gl.ELEMENT_ARRAY_BUFFER,new Uint16Array([0,1,2]),gl.STATIC_DRAW);ext.drawElementsInstancedANGLE(gl.TRIANGLES,3,gl.UNSIGNED_SHORT,0,1);gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,pixels);pixels.join(",")')! == '255,0,0,255'
		assert runtime.evaluate_host('gl.getError()')! == '0'
		assert runtime.evaluate_host('ext.drawElementsInstancedANGLE(gl.TRIANGLES,3,gl.UNSIGNED_SHORT,0,-1);gl.getError()')! == '1281'
		assert runtime.evaluate_host('try{ext.vertexAttribDivisorANGLE(1);false}catch(e){e instanceof TypeError}')! == 'true'
	}
}

fn test_public_webgl_draw_buffers_writes_actual_separate_color_attachments() {
	$if darwin {
		mut document := html.parse_document('<canvas width="2" height="2"></canvas>')
		mut host := CanvasWebGLHost.create(document)
		mut runtime := Runtime.create()
		defer { runtime.close() }
		host.install(mut runtime)!
		key := host.elements.keys().filter(host.elements[it].local_name() == 'canvas')[0]
		runtime.evaluate_host('const __canvases=Object.create(null),state={bridgeKey:"${key}",width:2,height:2};function __canvasFor(s){return __canvases[s.bridgeKey]||(__canvases[s.bridgeKey]={state:s});}function __canvasDimension(s,key){return s[key];}function __element(s){return {__state:s};}')!
		runtime.evaluate_host(webgl_bootstrap())!
		assert runtime.evaluate_host('const gl=__webglContext(state,"webgl"),ext=gl.getExtension("WEBGL_draw_buffers");ext!==null&&typeof ext.drawBuffersWEBGL==="function"')! == 'true'
		runtime.evaluate_host('const a=gl.createTexture(),b=gl.createTexture();for(const texture of [a,b]){gl.bindTexture(gl.TEXTURE_2D,texture);gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,2,2,0,gl.RGBA,gl.UNSIGNED_BYTE,null);}const fbo=gl.createFramebuffer();gl.bindFramebuffer(gl.FRAMEBUFFER,fbo);gl.framebufferTexture2D(gl.FRAMEBUFFER,ext.COLOR_ATTACHMENT0_WEBGL,gl.TEXTURE_2D,a,0);gl.framebufferTexture2D(gl.FRAMEBUFFER,ext.COLOR_ATTACHMENT1_WEBGL,gl.TEXTURE_2D,b,0);ext.drawBuffersWEBGL([ext.COLOR_ATTACHMENT0_WEBGL,ext.COLOR_ATTACHMENT1_WEBGL]);const vertex=gl.createShader(gl.VERTEX_SHADER);gl.shaderSource(vertex,"attribute vec2 position;void main(){gl_Position=vec4(position,0,1);}");gl.compileShader(vertex);const fragment=gl.createShader(gl.FRAGMENT_SHADER);gl.shaderSource(fragment,"#extension GL_EXT_draw_buffers : require\\nprecision mediump float;void main(){gl_FragData[0]=vec4(1,0,0,1);gl_FragData[1]=vec4(0,1,0,1);}");gl.compileShader(fragment);const program=gl.createProgram();gl.attachShader(program,vertex);gl.attachShader(program,fragment);gl.bindAttribLocation(program,0,"position");gl.linkProgram(program);gl.useProgram(program);const buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([-1,-1,3,-1,-1,3]),gl.STATIC_DRAW);gl.vertexAttribPointer(0,2,gl.FLOAT,false,0,0);gl.enableVertexAttribArray(0);gl.drawArrays(gl.TRIANGLES,0,3);const pixels=new Uint8Array(4);gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,pixels);')!
		assert runtime.evaluate_host('gl.getProgramParameter(program,gl.LINK_STATUS)')! == 'true'
		assert runtime.evaluate_host('pixels.join(",")')! == '255,0,0,255'
		assert runtime.evaluate_host('const readFbo=gl.createFramebuffer();gl.bindFramebuffer(gl.FRAMEBUFFER,readFbo);gl.framebufferTexture2D(gl.FRAMEBUFFER,gl.COLOR_ATTACHMENT0,gl.TEXTURE_2D,b,0);gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,pixels);pixels.join(",")')! == '0,255,0,255'
		assert runtime.evaluate_host('gl.getError()')! == '0'
	}
}
