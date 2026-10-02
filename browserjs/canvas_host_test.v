module browserjs

import dom
import html

fn canvas_host_test_runtime() (&Runtime, &CanvasHost) {
	document := dom.Document.create(dom.url_about_blank())
	mut host := CanvasHost.create(document)
	mut runtime := Runtime.create_with_engine(.javascriptcore)
	host.install(mut runtime) or { panic(err) }
	runtime.evaluate_host(r'
 const __canvases=Object.create(null);
 function __canvasDimension(s,name){return +s[name];}
 function __element(s){return {__state:s};}
 ' + canvas_bootstrap() + r'
 const state={bridgeKey:"created",width:16,height:16,tagName:"canvas"};
 const canvas=__element(state);
 const context=__canvasContext(state);
 ') or { panic(err) }
	return runtime, host
}

fn test_canvas_host_runs_native_paths_and_readback_during_script_execution() {
	$if !darwin {
		return
	}
	mut runtime, mut host := canvas_host_test_runtime()
	defer { runtime.close() }
	assert runtime.evaluate(r'
 context.fillStyle="red";
 context.beginPath();context.moveTo(1,1);context.lineTo(12,1);context.lineTo(1,12);context.closePath();context.fill();
 JSON.stringify(Array.from(context.getImageData(2,2,1,1).data));
 ')! == '[255,0,0,255]'
	assert runtime.evaluate('JSON.stringify(Array.from(context.getImageData(12,12,1,1).data));')! == '[0,0,0,0]'
	assert runtime.evaluate(r'
 context.save();context.filter="invert(100%)";context.fillRect(0,0,2,2);context.restore();
 JSON.stringify(Array.from(context.getImageData(0,0,1,1).data));
 ')! == '[0,255,255,255]'
	assert runtime.evaluate(r'context.filter;')! == 'none'
	mut record := host.contexts['created'] or { panic('missing canvas') }
	mut context := record.context
	assert (context.get_image_data(0, 0, 1, 1, none)!).data() == [u8(0), 255, 255, 255]
}

fn test_canvas_host_keeps_live_gradient_identity_validates_state_and_resets() {
	$if !darwin {
		return
	}
	mut runtime, _ := canvas_host_test_runtime()
	defer { runtime.close() }
	assert runtime.evaluate(r'
 const gradient=context.createLinearGradient(0,0,16,0);
 context.fillStyle=gradient;gradient.addColorStop(1,"blue");gradient.addColorStop(0,"red");
 context.fillRect(0,0,16,16);
 context.fillStyle===gradient;
 ')! == 'true'
	assert runtime.evaluate(r'const left=context.getImageData(0,8,1,1).data;left[0]>240 && left[2]<15;')! == 'true'
	assert runtime.evaluate(r'context.lineWidth=-2;context.lineWidth;')! == '1'
	assert runtime.evaluate(r'context.globalAlpha=0.5;context.fillStyle="rgba(255,0,0,0.5)";context.clearRect(0,0,16,16);context.fillRect(0,0,16,16);context.getImageData(0,0,1,1).data[3];')! == '64'
	assert runtime.evaluate(r'state.width=16;__canvasResize(state);context.globalAlpha;')! == '1'
	assert runtime.evaluate(r'context.getImageData(0,0,1,1).data[3];')! == '0'
	assert runtime.evaluate(r'let threw=false;try{gradient.addColorStop(2,"red");}catch(error){threw=error.name==="IndexSizeError";}threw;')! == 'true'
}

fn test_canvas_host_image_data_bypasses_transform_and_draw_image_snapshots_source() {
	$if !darwin {
		return
	}
	mut runtime, _ := canvas_host_test_runtime()
	defer { runtime.close() }
	assert runtime.evaluate(r'
 const image=context.createImageData(1,1);image.data.set([0,0,255,128]);
 context.translate(5,5);context.putImageData(image,0,0);
 JSON.stringify(Array.from(context.getImageData(0,0,1,1).data));
 ')! == '[0,0,255,128]'
	assert runtime.evaluate(r'
 context.resetTransform();context.drawImage(canvas,0,0,1,1,2,2,1,1);
 JSON.stringify(Array.from(context.getImageData(2,2,1,1).data));
 ')! == '[0,0,255,128]'
}

fn test_canvas_host_existing_element_uses_live_dom_surface_and_repaint_invalidation() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'canvas')!
	paintable := &dom.Paintable{}
	mut node := element.as_node()
	node.set_layout_node(&dom.LayoutNode{ paintables_: [paintable] })
	mut host := CanvasHost.create(document)
	host.elements['canvas'] = element
	host.call(r'{"key":"canvas","method":"set","property":"fillStyle","value":"red"}')!
	host.call(r'{"key":"canvas","method":"fillRect","args":[0,0,2,2]}')!
	canvas := unsafe { &dom.HTMLCanvasElement(element) }
	context := html.html_canvas_element_get_context(canvas, '2d', none)!
	assert (context.get_image_data(0, 0, 1, 1, none)!).data() == [u8(255), 0, 0, 255]
	assert paintable.needs_repaint
	assert html.html_canvas_element_is_dirty(canvas)
}

fn test_canvas_host_context_options_and_case_sensitive_getter() {
	$if !darwin {
		return
	}
	mut runtime, _ := canvas_host_test_runtime()
	defer { runtime.close() }
	assert runtime.evaluate(r'__canvasGetContext(state,"2D")===null;')! == 'true'
	assert runtime.evaluate(r'__canvasGetContext(state,"2d")===context;')! == 'true'
	assert runtime.evaluate(r'
 const opaqueState={bridgeKey:"opaque",tagName:"canvas",width:2,height:2};
 const opaque=__canvasGetContext(opaqueState,"2d",{alpha:false});
 opaque.getContextAttributes().alpha===false && opaque.getImageData(0,0,1,1).data[3]===255;
 ')! == 'true'
	assert runtime.evaluate(r'context.translate(3,4);context.setTransform(NaN,0,0,1,0,0);context.getTransform().e;')! == '3'
}

fn test_canvas_host_draws_shaped_text_immediately() {
	$if !darwin {
		return
	}
	mut runtime, _ := canvas_host_test_runtime()
	defer { runtime.close() }
	assert runtime.evaluate(r'context.font="12px serif";context.fillText("O",1,12);context.getImageData(0,0,16,16).data.some(function(value,index){return index%4===3&&value>0;});')! == 'true'
}

fn test_canvas_host_keeps_created_canvas_dom_identity_for_replay() {
	$if !darwin {
		return
	}
	mut runtime, host := canvas_host_test_runtime()
	defer { runtime.close() }
	runtime.evaluate('context.fillStyle="red";context.fillRect(0,0,2,2);')!
	elements := runtime.canvas_elements_for_binding()
	element := elements['created'] or { panic('created native canvas missing') }
	if actual := host.contexts['created'].element_context {
		if voidptr(actual.element) != voidptr(element) {
			panic('canvas DOM binding identity changed')
		}
	} else {
		panic('created canvas is missing its element context')
	}
	canvas := unsafe { &dom.HTMLCanvasElement(element) }
	context := html.html_canvas_element_get_context(canvas, '2d', none)!
	if (context.get_image_data(0, 0, 1, 1, none)!).data() != [u8(255), 0, 0, 255] {
		panic('created canvas surface is missing')
	}
}
