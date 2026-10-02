module browserjs

import html

fn test_public_read_pixels_numeric_offset_writes_the_actual_bound_pack_buffer() {
	$if darwin {
		mut document := html.parse_document('<canvas width="2" height="2"></canvas>')
		mut host := CanvasWebGLHost.create(document)
		mut runtime := Runtime.create()
		defer { runtime.close() }
		host.install(mut runtime)!
		key := host.elements.keys().filter(host.elements[it].local_name() == 'canvas')[0]
		runtime.evaluate_host('const __canvases=Object.create(null),state={bridgeKey:"${key}",width:2,height:2};function __canvasFor(s){return __canvases[s.bridgeKey]||(__canvases[s.bridgeKey]={state:s});}function __canvasDimension(s,key){return s[key];}function __element(s){return {__state:s};}')!
		runtime.evaluate_host(webgl_bootstrap())!
		runtime.evaluate_host('const gl=__webglContext(state,"webgl2",{preserveDrawingBuffer:true});gl.clearColor(1,0.25,0.5,1);gl.clear(gl.COLOR_BUFFER_BIT);const buffer=gl.createBuffer();gl.bindBuffer(gl.PIXEL_PACK_BUFFER,buffer);const initial=new Uint8Array(12);initial.fill(99);gl.bufferData(gl.PIXEL_PACK_BUFFER,initial,gl.STATIC_DRAW);')!
		assert runtime.evaluate_host('gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,4)===undefined')! == 'true'
		assert runtime.evaluate_host('const destination=new Uint8Array(12);gl.getBufferSubData(gl.PIXEL_PACK_BUFFER,0,destination);destination.join(",")')! == '99,99,99,99,255,64,128,255,99,99,99,99'
		assert runtime.evaluate_host('gl.getError()')! == '0'
		assert runtime.evaluate_host('gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,new Uint8Array(4));gl.getError()')! == '1282'
		assert runtime.evaluate_host('gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,10);gl.getError()')! == '1282'
		assert runtime.evaluate_host('gl.bindBuffer(gl.PIXEL_PACK_BUFFER,null);gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,0);gl.getError()')! == '1282'
	}
}
