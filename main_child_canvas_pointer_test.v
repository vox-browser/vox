module main

import browserjs
import dom
import html
import layout
import page

fn test_child_canvas_pointer_listeners_receive_native_press_release_and_coordinates() {
	$if !darwin {
		return
	}
	mut host, mut document := child_browser_fixture('<!doctype html><style>body{margin:0}iframe{position:absolute;left:40px;top:50px;width:200px;height:120px;border:0}</style><iframe id=frame></iframe>', 'https://canvas-pointer.example/')
	mut frame := document.get_element_by_id('frame')?
	frame.set_attribute_value('srcdoc', r'<!doctype html><style>body{margin:0}canvas{position:absolute;left:10px;top:10px;width:160px;height:80px}</style><script>
 globalThis.drawing=document.createElement("canvas");drawing.id="drawing";drawing.width=160;drawing.height=80;
 globalThis.pointerOrder=[];globalThis.pointerChecks=[];globalThis.pointerSaved=[];
 for(const type of ["pointermove","mousemove","pointerdown","mousedown","pointerup","mouseup","click"]){
  document.addEventListener(type,function(event){pointerOrder.push(type+":capture");pointerChecks.push(event.target===drawing&&event.currentTarget===document&&event.eventPhase===1&&event.isTrusted&&event.view===window);},true);
  drawing.addEventListener(type,function(event){pointerOrder.push(type+":target");pointerSaved.push(event);pointerChecks.push(this===drawing&&event.target===drawing&&event.currentTarget===drawing&&event instanceof MouseEvent&&event.isTrusted&&event.clientX===30&&event.clientY===20&&event.offsetX===20&&event.offsetY===10&&event.pageX===30&&event.pageY===20);});
  document.addEventListener(type,function(event){pointerOrder.push(type+":bubble");pointerChecks.push(event.target===drawing&&event.currentTarget===document&&event.eventPhase===3);});
 }
 const removed=()=>{throw new Error("removed pointer callback")};drawing.addEventListener("mousedown",removed);drawing.removeEventListener("mousedown",removed);
 globalThis.oncePresses=0;drawing.addEventListener("mousedown",()=>oncePresses++,{once:true});
 drawing.addEventListener("mouseup",()=>{drawing.getContext("2d").fillStyle="rgb(17 83 29)";drawing.getContext("2d").fillRect(0,0,160,80)});
 document.body.appendChild(drawing);
 </script>')
	mut runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), ['globalThis.outerPointerCalls=0;document.addEventListener("mousedown",()=>outerPointerCalls++);'], runtime, mut messages)
	child_browser_wait(host, 'drawing', mut messages)
	service := host.children[0].service?
	mut owner := unsafe { &page.Page(document.page()) }
	if !owner.has_local_root_navigable() { owner.set_local_root_navigable(document.navigable()?)! }
	mut app := &BrowserApp{
		document:            document
		page_model:          owner
		js_runtime:          runtime
		child_document_host: host
		layout_tree_only:    true
		viewport_width:      320
		viewport_height:     200
	}
	defer {
		layout.release_paint_tree(app.paint_tree_storage)
		host.close()
		runtime.close()
		document.destroy_a_document_and_its_descendants()
		document.finalize()
		document.release_native_storage()
	}
	app.dispatch_chrome_pointer_event_at_viewport_point('pointermove', 0, 70, 70)
	app.platform_pointer_buttons = 1
	app.dispatch_chrome_pointer_event_at_viewport_point('pointerdown', 0, 70, 70)
	app.platform_pointer_buttons = 0
	app.dispatch_chrome_pointer_event_at_viewport_point('pointerup', 0, 70, 70)
	app.replay_compact_javascript_click()
	expected := ['pointermove', 'mousemove', 'pointerdown', 'mousedown', 'pointerup', 'mouseup',
		'click'].map('${it}:capture,${it}:target,${it}:bubble').join(',')
	actual := service.runtime.evaluate_host('pointerOrder.join(",")')!
	assert actual == expected, actual
	assert service.runtime.evaluate_host('pointerChecks.every(Boolean)&&pointerSaved.length===7&&pointerSaved.every(event=>event.currentTarget===null)&&oncePresses===1')! == 'true'
	assert runtime.evaluate_host('outerPointerCalls===0')! == 'true'
	canvas := unsafe { &dom.HTMLCanvasElement(service.document.get_element_by_id('drawing')?) }
	context := html.html_canvas_element_get_context(canvas, '2d', none)!
	assert (context.get_image_data(0, 0, 1, 1, none)!).data() == [u8(17), 83, 29, 255]
	app.platform_pointer_buttons = 1
	app.dispatch_chrome_pointer_event_at_viewport_point('pointerdown', 0, 70, 70)
	app.platform_pointer_buttons = 0
	app.dispatch_chrome_pointer_event_at_viewport_point('pointerup', 0, 70, 70)
	app.replay_compact_javascript_click()
	assert service.runtime.evaluate_host('oncePresses===1&&pointerSaved.length===12&&pointerChecks.every(Boolean)')! == 'true'
	assert app.js_messages == []string{}, app.js_messages.join('\n')
}

fn test_canvas_cancelled_pointer_press_suppresses_mouse_events_until_release() {
	$if !darwin {
		return
	}
	mut owner := page.Page.create(1)!
	mut app := &BrowserApp{
		page_model:      owner
		script_policy:   .enabled
		viewport_width:  240
		viewport_height: 140
	}
	app.install_loaded_page(LoadedPage{
		url:          'https://cancelled-canvas-pointer.example/'
		content_type: 'text/html'
		markup:       r'<!doctype html><style>body{margin:0}canvas{display:block;width:160px;height:80px}</style><canvas id="drawing"></canvas><script>
 globalThis.canvasPointerOrder=[];globalThis.canvasPointerChecks=[];
 document.addEventListener("pointerdown",event=>{canvasPointerOrder.push("cancel");event.preventDefault()},{capture:true,once:true});
 const removed=()=>{throw new Error("removed document pointer listener")};document.addEventListener("pointerup",removed);document.removeEventListener("pointerup",removed);
 for(const type of ["pointerdown","mousedown","pointermove","mousemove","pointerup","mouseup","click"]){
  drawing.addEventListener(type,event=>{canvasPointerOrder.push(type);canvasPointerChecks.push(event.target===drawing&&event.currentTarget===drawing&&event.isTrusted&&event.view===window&&window.event===event);});
 }
 </script>'
	}, false)
	mut document := app.document
	runtime := app.js_runtime
	defer {
		layout.release_paint_tree(app.paint_tree_storage)
		runtime.close()
		document.finalize()
	}
	app.platform_pointer_buttons = 1
	app.dispatch_chrome_pointer_event_at_viewport_point('pointerdown', 0, 20, 20)
	app.dispatch_chrome_pointer_event_at_viewport_point('pointermove', 0, 21, 20)
	app.platform_pointer_buttons = 0
	app.dispatch_chrome_pointer_event_at_viewport_point('pointerup', 0, 21, 20)
	app.replay_compact_javascript_click()
	assert runtime.evaluate_host('canvasPointerOrder.join(",")')! == 'cancel,pointerdown,pointermove,pointerup,click'
	app.platform_pointer_buttons = 1
	app.dispatch_chrome_pointer_event_at_viewport_point('pointerdown', 0, 20, 20)
	app.platform_pointer_buttons = 0
	app.dispatch_chrome_pointer_event_at_viewport_point('pointerup', 0, 20, 20)
	app.replay_compact_javascript_click()
	assert runtime.evaluate_host('canvasPointerOrder.join(",")')! == 'cancel,pointerdown,pointermove,pointerup,click,pointerdown,mousedown,pointerup,mouseup,click'
	assert runtime.evaluate_host('canvasPointerChecks.every(Boolean)&&window.event===undefined')! == 'true'
	assert app.js_messages == []string{}, app.js_messages.join('\n')
}
