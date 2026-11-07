module main

import browserjs
import dom
import html
import page
import time

fn test_created_wheel_canvas_first_context_uses_pending_dimensions_and_cached_context_preserves_corner_pixels() {
	$if !darwin { return }
	mut owner := page.Page.create(1)!
	owner.set_enable_autoscroll(false)
	mut document := parse_browser_navigation_document_for_page_with_response_time(
		'<!doctype html><style>html,body{margin:0}body{height:600px}</style>',
		dom.URL{ value: 'https://created-wheel-canvas.example.test/' }, none, none,
		unsafe { &dom.Page(owner) }, time.sys_mono_now())
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
globalThis.wheelCanvas=document.createElement("canvas");wheelCanvas.id="created-wheel-canvas";
globalThis.wheelCanvasEvents=[];globalThis.wheelCanvasChecks=[];
wheelCanvas.addEventListener("wheel",function(event){wheelCanvasEvents.push(event);wheelCanvasChecks.push(this===wheelCanvas&&event.target===wheelCanvas&&event.currentTarget===wheelCanvas&&event instanceof WheelEvent&&event.isTrusted&&event.view===window&&window.event===event);event.preventDefault();},{passive:false});
// The facade owns its native node before these writes reach compact replay.
wheelCanvas.width=600;wheelCanvas.height=280;document.body.appendChild(wheelCanvas);
globalThis.wheelCanvasContext=wheelCanvas.getContext("2d");
wheelCanvasContext.fillStyle="red";wheelCanvasContext.lineWidth=7;
wheelCanvasContext.fillRect(599,279,1,1);
wheelCanvasChecks.push(JSON.stringify(Array.from(wheelCanvasContext.getImageData(599,279,1,1).data))==="[255,0,0,255]");
const again=wheelCanvas.getContext("2d");
wheelCanvasChecks.push(again===wheelCanvasContext&&again.lineWidth===7&&again.fillStyle==="rgb(255 0 0)"&&JSON.stringify(Array.from(again.getImageData(599,279,1,1).data))==="[255,0,0,255]");0
'], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('wheelCanvasChecks.length===2&&wheelCanvasChecks.every(Boolean)')! == 'true'
	element := document.get_element_by_id('created-wheel-canvas')?
	wrapper := runtime.evaluate_host_value('wheelCanvas')!
	assert voidptr(runtime.native_event_target(wrapper)!) == voidptr(element)
	assert runtime.javascript_event_target(unsafe { &dom.EventTarget(element) }, none)! == wrapper
	key := runtime.evaluate_host('wheelCanvas.__state.bridgeKey')!
	provided := runtime.canvas_elements_for_binding()[key] or { panic('created canvas provider missing') }
	assert voidptr(provided) == voidptr(element)
	canvas := unsafe { &dom.HTMLCanvasElement(element) }
	assert html.html_canvas_element_width(canvas) == 600
	assert html.html_canvas_element_height(canvas) == 280
	context := html.html_canvas_element_get_context(canvas, '2d', none)!
	bitmap := context.surface() or { panic('created canvas surface missing') }
	assert bitmap.width == 600 && bitmap.height == 280
	assert (context.get_image_data(599, 279, 1, 1, none)!).data() == [u8(255), 0, 0, 255]
	assert (context.get_image_data(0, 0, 1, 1, none)!).data() == [u8(0), 0, 0, 0]
	mut app := &BrowserApp{
		page_model: owner
		document: document
		js_runtime: runtime
		viewport_width: 640
		viewport_height: 320
	}
	app.relayout(640, 320 + app.chrome_height())
	assert app.handle_wheel_at_viewport_point(page.PixelPoint{12.5, 12.25}, page.PixelPoint{},
		0, 0, 0, 0, 3.5, false) == .cancelled
	assert app.scroll_y == 0 && app.js_messages == []
	assert runtime.evaluate_host('wheelCanvasEvents.length===1&&wheelCanvasChecks.every(Boolean)&&wheelCanvasEvents[0].defaultPrevented&&wheelCanvasEvents[0].currentTarget===null&&window.event===undefined')! == 'true'
	event_wrapper := runtime.evaluate_host_value('wheelCanvasEvents[0]')!
	event := runtime.native_event(event_wrapper)!
	assert event.interface_ == .wheel_event && event.is_trusted()
	assert voidptr(event.target()?) == voidptr(element)
	assert runtime.javascript_event(event)! == event_wrapper
	// Layout and callback replay keep both the first native context and bitmap.
	again := html.html_canvas_element_get_context(canvas, '2d', none)!
	assert voidptr(again) == voidptr(context)
	assert html.html_canvas_element_width(canvas) == 600 && html.html_canvas_element_height(canvas) == 280
	assert (again.get_image_data(599, 279, 1, 1, none)!).data() == [u8(255), 0, 0, 255]
	assert runtime.evaluate_host('wheelCanvas.getContext("2d")===wheelCanvasContext&&wheelCanvasContext.lineWidth===7&&JSON.stringify(Array.from(wheelCanvasContext.getImageData(599,279,1,1).data))==="[255,0,0,255]"')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
}
