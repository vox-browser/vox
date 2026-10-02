module browserjs

import dom
import html

fn test_canvas_public_context_getters_share_native_dom_owners_and_preserve_pixels() {
	$if !darwin {
		return
	}
	document := dom.Document.create(dom.url_about_blank())
	mut runtime := Runtime.create_with_engine(.javascriptcore)
	defer { runtime.close() }
	mut host := CanvasHost.create(document)
	mut webgl_host := CanvasWebGLHost.create(document)
	host.install(mut runtime)!
	webgl_host.install(mut runtime)!
	runtime.evaluate_host(r'
 const __canvases=Object.create(null);
 function __canvasDimension(s,name){return +s[name];}
 function __element(s){return s.element||(s.element={__state:s});}
 ' + canvas_bootstrap() + webgl_bootstrap() + r'
 const flat={bridgeKey:"__created_0",tagName:"canvas",width:2,height:3};
 const gpu={bridgeKey:"__created_1",tagName:"canvas",width:2,height:3};
 const context=__canvasGetContext(flat,"2d");
 const gl=__canvasGetContext(gpu,"webgl2",{preserveDrawingBuffer:true});
 context.fillStyle="red";context.fillRect(0,0,2,1);
 gl.clearColor(0,1,0,1);gl.clear(gl.COLOR_BUFFER_BIT);
 ')!
	assert runtime.evaluate_host('context.canvas===__element(flat)&&gl.canvas===__element(gpu)&&__canvasGetContext(flat,"webgl")===null&&__canvasGetContext(gpu,"2d")===null')! == 'true'
	elements := runtime.canvas_elements_for_binding()
	flat_element := elements['__created_0'] or { panic('2D owner missing') }
	gpu_element := elements['__created_1'] or { panic('WebGL owner missing') }
	assert (flat_element.owner_document() or { panic('2D owning document missing') }).unique_id() == document.unique_id()
	assert (gpu_element.owner_document() or { panic('WebGL owning document missing') }).unique_id() == document.unique_id()
	flat_canvas := unsafe { &dom.HTMLCanvasElement(flat_element) }
	gpu_canvas := unsafe { &dom.HTMLCanvasElement(gpu_element) }
	flat_context := html.html_canvas_element_get_context(flat_canvas, '2d', none)!
	assert (flat_context.get_image_data(0, 0, 1, 1, none)!).data() == [u8(255), 0, 0, 255]
	gpu_context := html.html_canvas_element_webgl_context(gpu_canvas) or { panic('WebGL context missing') }
	assert gpu_context.canvas_for_binding() == voidptr(gpu_canvas)
	assert (html.html_canvas_element_present_existing_surface(gpu_canvas) or { panic('WebGL surface missing') }).data[..4] == [u8(0), 255, 0, 255]
	assert runtime.evaluate_host('context.drawImage(__element(gpu),0,0);JSON.stringify(Array.from(context.getImageData(0,0,1,1).data))')! == '[0,255,0,255]'
}
