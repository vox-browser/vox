// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn test_public_webgl_float16_view_offsets_retain_two_byte_source_element_size() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<canvas></canvas>')
	mut host := CanvasWebGLHost.create(document)
	mut runtime := Runtime.create()
	defer { runtime.close() }
	host.install(mut runtime)!
	key := host.elements.keys().filter(host.elements[it].local_name() == 'canvas')[0]
	runtime.evaluate_host('const __canvases=Object.create(null),state={bridgeKey:"${key}",width:2,height:2};function __canvasFor(s){return __canvases[s.bridgeKey]||(__canvases[s.bridgeKey]={state:s});}function __canvasDimension(s,key){return s[key];}function __element(s){return {__state:s};}')!
	runtime.evaluate_host(webgl_bootstrap())!
	exposure := runtime.evaluate_host('typeof Float16Array==="function"?"supported":"unsupported"')!
	println('Float16Array exposure: ${exposure}')
	if exposure == 'unsupported' { return }
	assert runtime.evaluate_host(r'(function(){const gl=__webglContext(state,"webgl2",{preserveDrawingBuffer:true}),buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);const source=new Float16Array([1,2,3]);Object.defineProperty(source,"BYTES_PER_ELEMENT",{get(){throw "element size"}});gl.bufferData(gl.ARRAY_BUFFER,source,gl.STATIC_DRAW,1,1);const destination=new Uint16Array(1);gl.getBufferSubData(gl.ARRAY_BUFFER,0,destination);return gl.getBufferParameter(gl.ARRAY_BUFFER,gl.BUFFER_SIZE)===2&&destination[0]===0x4000&&gl.getError()===gl.NO_ERROR})()')! == 'true'
	assert runtime.evaluate_host(r'(function(){const gl=__webglContext(state,"webgl2"),destination=new Float16Array(2);gl.getBufferSubData(gl.ARRAY_BUFFER,0,destination,1,1);return destination[0]===0&&destination[1]===2&&gl.getError()===gl.NO_ERROR})()')! == 'true'
}
