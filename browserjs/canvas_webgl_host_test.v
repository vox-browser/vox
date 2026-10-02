module browserjs

import html
import css
import dom

fn test_javascript_webgl_host_compiles_shaders_uploads_buffers_and_draws_native_pixels() {
	$if darwin {
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
		assert runtime.evaluate_host('call("readPixels",[0,0,1,1,0x1908,0x1401])')! == '255,64,128,255'
		assert runtime.evaluate_host('call("getError",[])')! == '0'
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
	$if darwin {
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
