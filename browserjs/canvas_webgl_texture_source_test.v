module browserjs

import css
import dom
import html
import webgl

fn test_public_bitmap_texture_overloads_use_real_frames_and_native_conversion() {
	$if darwin {
		mut document := html.parse_document('<canvas id="target" width="2" height="2"></canvas><img id="pending">')
		mut host := CanvasWebGLHost.create(document)
		mut runtime := Runtime.create()
		defer { runtime.close() }
		host.install(mut runtime)!
		target := css.query_selector(unsafe { &dom.Node(document) }, '#target') or { panic('target') }
		key := host.elements.keys().filter(host.elements[it] == target)[0]
		source_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'canvas')!
		mut source_canvas := unsafe { &dom.HTMLCanvasElement(source_element) }
		html.html_canvas_element_set_width(mut source_canvas, 1)!
		html.html_canvas_element_set_height(mut source_canvas, 2)!
		mut source_context := html.html_canvas_element_create_webgl2_context(source_canvas, none)!
		source_context.clear_color(0, 0, 1, 1)
		source_context.clear(webgl.GLenum(0x4000))
		source_context.enable(webgl.scissor_test)
		source_context.scissor(0, 0, 1, 1)
		source_context.clear_color(1, 0, 0, 1)
		source_context.clear(webgl.GLenum(0x4000))
		runtime.add_canvas_element_provider(fn [source_element] () map[string]&dom.Element {
			return {
				'__created_source': source_element
			}
		})
		runtime.evaluate_host('const __canvases=Object.create(null);const state={bridgeKey:"${key}",width:2,height:2};function __canvasFor(s){return __canvases[s.bridgeKey]||(__canvases[s.bridgeKey]={state:s});}function __canvasDimension(s,key){return s[key];}function __element(s){return {__state:s};}')!
		runtime.evaluate_host(webgl_bootstrap())!
		runtime.evaluate_host('const gl=__webglContext(state,"webgl2",{preserveDrawingBuffer:true});const texture=gl.createTexture();gl.bindTexture(gl.TEXTURE_2D,texture);const source={__state:{tagName:"canvas",bridgeKey:"__created_source"}};gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,gl.RGBA,gl.UNSIGNED_BYTE,source);const fbo=gl.createFramebuffer();gl.bindFramebuffer(gl.FRAMEBUFFER,fbo);gl.framebufferTexture2D(gl.FRAMEBUFFER,gl.COLOR_ATTACHMENT0,gl.TEXTURE_2D,texture,0);const pixels=new Uint8Array(8);gl.readPixels(0,0,1,2,gl.RGBA,gl.UNSIGNED_BYTE,pixels);')!
		assert runtime.evaluate_host('pixels.join(",")')! == '0,0,255,255,255,0,0,255'
		assert runtime.evaluate_host('gl.getError()')! == '0'
		assert host.elements_for_binding()['__created_source'] == source_element
		runtime.evaluate_host('gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL,true);gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,2,2,0,gl.RGBA,gl.UNSIGNED_BYTE,source);gl.readPixels(0,0,1,2,gl.RGBA,gl.UNSIGNED_BYTE,pixels);')!
		assert runtime.evaluate_host('pixels.join(",")')! == '255,0,0,255,0,0,255,255'
		assert runtime.evaluate_host('gl.getError()')! == '0'
		runtime.evaluate_host('gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL,false);gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL,true);const image={width:1,height:1,data:new Uint8ClampedArray([200,100,50,128]),colorSpace:"srgb"};gl.texSubImage2D(gl.TEXTURE_2D,0,0,0,gl.RGBA,gl.UNSIGNED_BYTE,image);const one=new Uint8Array(4);gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,one);')!
		assert runtime.evaluate_host('one.join(",")')! == '100,50,25,128'
		assert runtime.evaluate_host('try{gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,gl.RGBA,gl.UNSIGNED_BYTE,{});false}catch(e){e instanceof TypeError}')! == 'true'
		assert runtime.evaluate_host('gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,-1,2,0,gl.RGBA,gl.UNSIGNED_BYTE,image);gl.getError()')! == '1281'
		assert runtime.evaluate_host('gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,1,1,1,gl.RGBA,gl.UNSIGNED_BYTE,image);gl.getError()')! == '1281'
		runtime.evaluate_host('const arrayTexture=gl.createTexture();gl.bindTexture(gl.TEXTURE_2D_ARRAY,arrayTexture);gl.texImage3D(gl.TEXTURE_2D_ARRAY,0,gl.RGBA8,1,1,1,0,gl.RGBA,gl.UNSIGNED_BYTE,new Uint8Array([0,255,0,255]));gl.framebufferTextureLayer(gl.FRAMEBUFFER,gl.COLOR_ATTACHMENT0,arrayTexture,0,0);gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,one);')!
		assert runtime.evaluate_host('one.join(",")')! == '0,255,0,255'
		runtime.evaluate_host('gl.texSubImage3D(gl.TEXTURE_2D_ARRAY,0,0,0,0,1,1,1,gl.RGBA,gl.UNSIGNED_BYTE,image);gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,one);')!
		assert runtime.evaluate_host('one.join(",")')! == '100,50,25,128'
		runtime.evaluate_host('gl.texImage3D(gl.TEXTURE_2D_ARRAY,0,gl.RGBA8,1,1,1,0,gl.RGBA,gl.UNSIGNED_BYTE,image);gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,one);')!
		assert runtime.evaluate_host('one.join(",")')! == '100,50,25,128'
		assert runtime.evaluate_host('gl.getError()')! == '0'
		assert source_context.get_error() == webgl.no_error
	}
}
