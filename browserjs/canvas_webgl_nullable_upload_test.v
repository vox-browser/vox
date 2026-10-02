module browserjs

import html

fn test_public_nullable_texture_uploads_keep_source_webgl1_and_webgl2_rules() {
	$if darwin {
		mut document := html.parse_document('<canvas></canvas><canvas></canvas>')
		mut host := CanvasWebGLHost.create(document)
		mut runtime := Runtime.create()
		defer { runtime.close() }
		host.install(mut runtime)!
		keys := host.elements.keys().filter(host.elements[it].local_name() == 'canvas').sorted()
		runtime.evaluate_host('const __canvases=Object.create(null),first={bridgeKey:"${keys[0]}",width:2,height:2},second={bridgeKey:"${keys[1]}",width:2,height:2};function __canvasFor(s){return __canvases[s.bridgeKey]||(__canvases[s.bridgeKey]={state:s});}function __canvasDimension(s,key){return s[key];}function __element(s){return {__state:s};}')!
		runtime.evaluate_host(webgl_bootstrap())!
		runtime.evaluate_host('const a=__webglContext(first,"webgl"),b=__webglContext(second,"webgl2");const ta=a.createTexture();a.bindTexture(a.TEXTURE_2D,ta);a.texImage2D(a.TEXTURE_2D,0,a.RGBA,1,1,0,a.RGBA,a.UNSIGNED_BYTE,null);const fa=a.createFramebuffer();a.bindFramebuffer(a.FRAMEBUFFER,fa);a.framebufferTexture2D(a.FRAMEBUFFER,a.COLOR_ATTACHMENT0,a.TEXTURE_2D,ta,0);const pixels=new Uint8Array(4);a.readPixels(0,0,1,1,a.RGBA,a.UNSIGNED_BYTE,pixels);')!
		assert runtime.evaluate_host('pixels.join(",")')! == '0,0,0,0'
		assert runtime.evaluate_host('a.getError()')! == '0'
		assert runtime.evaluate_host('a.texSubImage2D(a.TEXTURE_2D,0,0,0,0,0,a.RGBA,a.UNSIGNED_BYTE,null);a.getError()')! == '1281'
		assert runtime.evaluate_host('a.texSubImage2D(a.TEXTURE_2D,0,0,0,0,0,a.RGBA,a.UNSIGNED_BYTE,new Uint8Array(0));a.getError()')! == '0'
		assert runtime.evaluate_host('a.texImage2D(a.TEXTURE_2D,0,a.RGBA,1,1,0,a.RGBA,a.UNSIGNED_SHORT_5_6_5,null);a.getError()')! == '1282'
		runtime.evaluate_host('const tb=b.createTexture();b.bindTexture(b.TEXTURE_2D,tb);b.pixelStorei(b.UNPACK_ROW_LENGTH,1);b.pixelStorei(b.UNPACK_SKIP_PIXELS,1);b.texImage2D(b.TEXTURE_2D,0,b.RGBA,1,1,0,b.RGBA,b.UNSIGNED_BYTE,null);')!
		assert runtime.evaluate_host('b.getError()')! == '0'
		assert runtime.evaluate_host('b.texImage2D(b.TEXTURE_2D,0,b.RGBA,1,1,0,b.RGBA,b.UNSIGNED_BYTE,new Uint8Array(0));b.getError()')! == '1282'
		assert runtime.evaluate_host('b.texSubImage2D(b.TEXTURE_2D,0,0,0,1,1,b.RGBA,b.UNSIGNED_BYTE,null);b.getError()')! == '1282'
		assert runtime.evaluate_host('a.getError()')! == '0'
	}
}
