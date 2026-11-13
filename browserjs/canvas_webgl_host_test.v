module browserjs

import html
import css
import dom

fn test_javascript_webgl_host_compiles_shaders_uploads_buffers_and_draws_native_pixels() {
	$if darwin || linux || windows {
		mut document := html.parse_document('<canvas id="canvas" width="4" height="4"></canvas>')
		mut host := CanvasWebGLHost.create(document)
		mut runtime := Runtime.create()
		defer { runtime.close() }
		host.install(mut runtime)!
		key := host.elements.keys().filter(host.elements[it].local_name() == 'canvas')[0]
		runtime.evaluate_host('var key = "${key}"; function call(method,args) { const reply=JSON.parse(__ladybirdWebGL(JSON.stringify({method,key,args,width:4,height:4}))); if(reply&&reply.error)throw new Error(reply.error.message);return reply; }')!
		assert runtime.evaluate_host('JSON.parse(__ladybirdWebGL(JSON.stringify({method:"getContext",key,kind:"webgl2",options:{preserveDrawingBuffer:true}}))).version')! == '2'
		assert runtime.evaluate_host('const vertex=call("createShader",[0x8b31]); call("shaderSource",[vertex,"#version 300 es\\nin vec2 position;void main(){gl_Position=vec4(position,0.0,1.0);}"]);call("compileShader",[vertex]);call("getShaderParameter",[vertex,0x8b81])')! == 'true'
		assert runtime.evaluate_host('const fragment=call("createShader",[0x8b30]);call("shaderSource",[fragment,"#version 300 es\\nprecision mediump float;out vec4 color;uniform vec4 tint;void main(){color=tint;}"]);call("compileShader",[fragment]);call("getShaderParameter",[fragment,0x8b81])')! == 'true'
		assert runtime.evaluate_host('const program=call("createProgram",[]);call("attachShader",[program,vertex]);call("attachShader",[program,fragment]);call("bindAttribLocation",[program,0,"position"]);call("linkProgram",[program]);call("useProgram",[program]);call("getProgramParameter",[program,0x8b82])')! == 'true'
		runtime.evaluate_host('const tint=call("getUniformLocation",[program,"tint"]);call("uniform4fv",[tint,[1,0.25,0.5,1]]);const buffer=call("createBuffer",[]);call("bindBuffer",[0x8892,buffer]);const vertices=new Float32Array([-1,-1,3,-1,-1,3]);call("bufferData",[0x8892,Array.from(new Uint8Array(vertices.buffer)),0x88e4]);call("vertexAttribPointer",[0,2,0x1406,false,0,0]);call("enableVertexAttribArray",[0]);call("drawArrays",[4,0,3]);')!
		assert runtime.evaluate_host('call("readPixels",[0,0,1,1,0x1908,0x1401,[0,0,0,0]])')! == '255,64,128,255'
		assert runtime.evaluate_host('call("getError",[])')! == '0'
		assert runtime.evaluate_host('call("readPixels",[0,0,1,1,0x1908,0x1401,[99]]);call("getError",[])')! == '1282'
		assert runtime.evaluate_host('call("getParameter",[0x8894]).handle===buffer.handle')! == 'true'
		canvas_element := css.query_selector(unsafe { &dom.Node(document) }, '#canvas') or { panic('canvas') }
		canvas := unsafe { &dom.HTMLCanvasElement(canvas_element) }
		assert (html.html_canvas_element_present_existing_surface(canvas) or { panic('surface') }).data[..4] == [
			u8(255),
			64,
			128,
			255,
		]
		assert runtime.evaluate_host('const broken=call("createShader",[0x8b31]);call("shaderSource",[broken,"not GLSL"]);call("compileShader",[broken]);call("getShaderParameter",[broken,0x8b81])')! == 'false'
		assert runtime.evaluate_host('call("getShaderInfoLog",[broken]).length>0')! == 'true'
		assert runtime.evaluate_host('call("getUniformLocation",[program,"missing"])===null')! == 'true'
		assert runtime.evaluate_host('call("drawArrays",[0xbad,0,3]);call("getError",[])')! == '1280'
		assert runtime.evaluate_host('try { call("bindBuffer",[0x8892,program]); "missed"; } catch(e) { e.message.includes("TypeError"); }')! == 'true'
	}
}

fn test_javascript_webgl_context_kinds_and_foreign_resource_ownership() {
	$if darwin || linux || windows {
		mut document := html.parse_document('<canvas id="first"></canvas><canvas id="second"></canvas>')
		mut host := CanvasWebGLHost.create(document)
		mut runtime := Runtime.create()
		defer { runtime.close() }
		host.install(mut runtime)!
		keys := host.elements.keys().filter(host.elements[it].local_name() == 'canvas').sorted()
		runtime.evaluate_host('var a="${keys[0]}",b="${keys[1]}"; function call(key,method,args) { return JSON.parse(__ladybirdWebGL(JSON.stringify({key,method,args}))); } function get(key,kind) { return JSON.parse(__ladybirdWebGL(JSON.stringify({key,method:"getContext",kind}))); }')!
		assert runtime.evaluate_host('get(a,"webgl").version')! == '1'
		assert runtime.evaluate_host('get(a,"webgl2")===null')! == 'true'
		assert runtime.evaluate_host('get(b,"webgl").version')! == '1'
		assert runtime.evaluate_host('const buffer=call(a,"createBuffer",[]);call(b,"bindBuffer",[0x8892,buffer]);call(b,"getError",[])')! == '1282'
		assert runtime.evaluate_host('call(a,"getError",[])')! == '0'
	}
}

fn test_public_webgl_wrapper_uses_idl_conversions_resources_readback_and_resize() {
	$if darwin || linux || windows {
		mut document := html.parse_document('<canvas id="canvas" width="4" height="4"></canvas>')
		mut host := CanvasWebGLHost.create(document)
		mut runtime := Runtime.create()
		defer { runtime.close() }
		host.install(mut runtime)!
		key := host.elements.keys().filter(host.elements[it].local_name() == 'canvas')[0]
		runtime.evaluate_host('const __canvases=Object.create(null);const state={bridgeKey:"${key}",width:4,height:4};const element={};function __canvasFor(s){return __canvases[s.bridgeKey]||(__canvases[s.bridgeKey]={state:s});}function __canvasDimension(s,key){return s[key];}function __element(s){return element;}')!
		runtime.evaluate_host(webgl_bootstrap())!
		assert runtime.evaluate_host('const gl=__webglContext(state,"webgl2",{preserveDrawingBuffer:true});gl instanceof WebGL2RenderingContext && gl.canvas===element && gl.TRIANGLES===4 && __webglContext(state,"webgl2")===gl && __webglContext(state,"webgl")===null')! == 'true'
		assert runtime.evaluate_host('const buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([-1,-1,3,-1,-1,3]),gl.STATIC_DRAW);buffer instanceof WebGLBuffer && gl.getParameter(gl.ARRAY_BUFFER_BINDING)===buffer && gl.getBufferParameter(gl.ARRAY_BUFFER,gl.BUFFER_SIZE)===24')! == 'true'
		assert runtime.evaluate_host('try{gl.bindBuffer(gl.ARRAY_BUFFER,{});false}catch(e){e instanceof TypeError}')! == 'true'
		assert runtime.evaluate_host('try{gl.clearColor(1,0);false}catch(e){e instanceof TypeError}')! == 'true'
		runtime.evaluate_host('const vertex=gl.createShader(gl.VERTEX_SHADER);gl.shaderSource(vertex,"#version 300 es\\nin vec2 position;void main(){gl_Position=vec4(position,0.0,1.0);}");gl.compileShader(vertex);const fragment=gl.createShader(gl.FRAGMENT_SHADER);gl.shaderSource(fragment,"#version 300 es\\nprecision mediump float;out vec4 color;uniform vec4 tint;void main(){color=tint;}");gl.compileShader(fragment);const program=gl.createProgram();gl.attachShader(program,vertex);gl.attachShader(program,fragment);gl.bindAttribLocation(program,0,"position");gl.linkProgram(program);gl.useProgram(program);const location=gl.getUniformLocation(program,"tint");gl.uniform4fv(location,new Float32Array([1,0.25,0.5,1]));gl.vertexAttribPointer(0,2,gl.FLOAT,false,0,0);gl.enableVertexAttribArray(0);gl.drawArrays(gl.TRIANGLES,0,3);')!
		assert runtime.evaluate_host('const destination=new Uint8Array(8);destination.fill(99);gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,destination,4);destination.join(",")')! == '99,99,99,99,255,64,128,255'
		assert runtime.evaluate_host('const destination2=new Uint32Array(2);gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,destination2,1);Array.from(new Uint8Array(destination2.buffer)).join(",")')! == '0,0,0,0,255,64,128,255'
		assert runtime.evaluate_host('gl.getParameter(gl.VIEWPORT) instanceof Int32Array && gl.getParameter(gl.COLOR_CLEAR_VALUE) instanceof Float32Array && gl.getParameter(gl.COMPRESSED_TEXTURE_FORMATS) instanceof Uint32Array')! == 'true'
		assert runtime.evaluate_host('gl.getError()')! == '0'
		assert runtime.evaluate_host('gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,new Uint8Array(1));gl.getError()')! == '1282'
		assert runtime.evaluate_host('state.width=2;__webglCall(state,"resize");gl.drawingBufferWidth')! == '2'
		assert runtime.evaluate_host('gl.getAttachedShaders(program)[0]===vertex')! == 'true'
		assert runtime.evaluate_host('const vertexArray=gl.createVertexArray();gl.bindVertexArray(vertexArray);gl.getParameter(gl.VERTEX_ARRAY_BINDING)===vertexArray')! == 'true'
		assert runtime.evaluate_host('const createdState={bridgeKey:"__created_0",width:2,height:3};const createdContext=__webglContext(createdState,"webgl2",{preserveDrawingBuffer:true});createdContext.clearColor(0,1,0,1);createdContext.clear(createdContext.COLOR_BUFFER_BIT);createdContext.drawingBufferWidth===2&&createdContext.drawingBufferHeight===3')! == 'true'
		created_element := host.elements_for_binding()['__created_0'] or {panic('created canvas identity')}
		created_canvas := unsafe {&dom.HTMLCanvasElement(created_element)}
		created_context := html.html_canvas_element_webgl_context(created_canvas) or {panic('context owner')}
		assert created_context.canvas_for_binding() == voidptr(created_canvas)
		assert (created_element.owner_document() or {panic("owner document")}).unique_id() == document.unique_id()
		assert (html.html_canvas_element_present_existing_surface(created_canvas) or {panic('created canvas frame')}).data[..4] == [u8(0),255,0,255]
	}
}
