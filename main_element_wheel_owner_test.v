module main

import browserjs
import dom
import gg
import html
import page
import time

const element_wheel_owner_markup = '<!doctype html><style>
html,body { margin:0 }
body { height:1500px }
#ew-scroller { width:240px; height:100px; overflow:auto }
#ew-parent { width:220px; height:80px }
#ew-button { display:block; width:180px; height:50px; margin:0; padding:0; border:0 }
#ew-inline { display:inline-block; width:160px; height:40px }
#ew-content { height:500px }
#ew-anonymous img,#ew-anonymous video { display:block; width:80px; height:30px }
#ew-result { position:absolute; left:0; top:180px }
</style><div id="ew-scroller"><div id="ew-parent"><button id="ew-button"><span id="ew-inline">wheel hit</span></button></div><div id="ew-content"></div></div>
<div id="ew-anonymous"><img src="data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw=="><video></video></div>
<img id="ew-image" style="display:none" src="data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw=="><audio id="ew-audio" style="display:none"></audio><div id="ew-result">waiting</div>'

fn element_wheel_owner_fixture(markup string, source string) !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	owner.set_enable_autoscroll(false)
	document := parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: 'https://ordinary-wheel-owner.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [source], runtime, mut messages)
	assert messages == []
	mut app := &BrowserApp{
		page_model:      owner
		document:        document
		js_runtime:      runtime
		viewport_width:  320
		viewport_height: 240
	}
	app.relayout(320, 240 + app.chrome_height())
	assert document.layout_is_up_to_date() && document.paintable_box() != none
	return app, document, runtime
}

fn element_wheel_owner_event(mut runtime browserjs.Runtime, expression string, trusted bool) !&dom.Event {
	wrapper := runtime.evaluate_host_value(expression)!
	event := runtime.native_event(wrapper)!
	assert event.interface_ == .wheel_event && event.is_trusted() == trusted
	assert runtime.javascript_event(event)! == wrapper
	assert event.current_target() == none && event.event_phase() == 0
	assert runtime.evaluate_host('${expression}.currentTarget===null&&${expression}.eventPhase===Event.NONE&&window.event===undefined')! == 'true'
	return event
}

fn element_wheel_owner_balance(runtime &browserjs.Runtime, document &dom.Document) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
}

fn test_ordinary_wheel_native_gg_capture_bubble_once_remove_and_anonymous_specialized_target_identity() {
	$if !darwin { return }
	mut app, mut document, mut runtime := element_wheel_owner_fixture(element_wheel_owner_markup, r'
globalThis.ewParent=document.getElementById("ew-parent");globalThis.ewButton=document.getElementById("ew-button");globalThis.ewInline=document.getElementById("ew-inline");
globalThis.ewOrder=[];globalThis.ewSaved=[];globalThis.ewChecks=[];globalThis.ewAnonymousMode=false;globalThis.ewRemoved=0;globalThis.ewClicks=0;globalThis.ewLoads=0;
function watch(label,target,capture){const callback=function(e){if(ewAnonymousMode)return;ewOrder.push(label);if(label==="wc")ewSaved.push(e);ewChecks.push(this===target&&e.currentTarget===target&&e.target===ewInline&&e instanceof WheelEvent&&Object.getPrototypeOf(e)===WheelEvent.prototype&&e.isTrusted&&e.bubbles&&e.cancelable&&e.composed&&e.view===window&&window.event===e&&e.deltaMode===WheelEvent.DOM_DELTA_PIXEL&&e.composedPath()[0]===ewInline);};target.addEventListener("wheel",callback,{capture,passive:false});return callback;}
watch("wc",window,true);watch("dc",document,true);watch("rc",document.documentElement,true);watch("pc",ewParent,true);watch("bc",ewButton,true);
function removed(){ewRemoved++}ewInline.addEventListener("wheel",removed);ewInline.removeEventListener("wheel",removed);
ewInline.addEventListener("wheel",function(e){ewOrder.push("target");ewChecks.push(this===ewInline&&e.currentTarget===ewInline&&e.eventPhase===Event.AT_TARGET);e.preventDefault();document.getElementById("ew-result").textContent="ordinary cancelled";ewParent.style.backgroundColor="rgb(0,128,0)";},{once:true});
const duplicate=watch("bb",ewButton,false);ewButton.addEventListener("wheel",duplicate);watch("pb",ewParent,false);watch("rb",document.documentElement,false);watch("db",document,false);watch("wb",window,false);
ewButton.addEventListener("click",function(e){ewClicks++;ewChecks.push(this===ewButton&&e.target===ewButton&&e.type==="click")});
document.getElementById("ew-image").addEventListener("load",function(e){ewLoads++;ewChecks.push(e.target===this&&e.type==="load")});
ewChecks.push(Object.getPrototypeOf(document.getElementById("ew-image"))===HTMLImageElement.prototype&&Object.getPrototypeOf(document.getElementById("ew-audio"))===HTMLAudioElement.prototype);
globalThis.ewAnonymousSaved=[];globalThis.ewAnonymousTag="img";
document.getElementById("ew-anonymous").addEventListener("wheel",function(e){ewAnonymousSaved.push(e);const target=e.target;ewChecks.push(this===document.getElementById("ew-anonymous")&&e.currentTarget===this&&target===document.querySelector(ewAnonymousTag)&&Object.getPrototypeOf(target)===(ewAnonymousTag==="img"?HTMLImageElement.prototype:HTMLVideoElement.prototype));e.preventDefault();},{passive:false});0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	scroller := document.get_element_by_id('ew-scroller')?
	inline := document.get_element_by_id('ew-inline')?
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('ewInline')!)!) == voidptr(inline)
	app.handle_event(&gg.Event{
		typ:           .mouse_scroll
		mouse_x:       12.5
		mouse_y:       12.25 + app.page_top()
		scroll_y:      -1
		window_height: 240 + app.chrome_height()
	})
	assert runtime.evaluate_host('ewOrder.join(",")==="wc,dc,rc,pc,bc,target,bb,pb,rb,db,wb"&&ewRemoved===0&&ewLoads===1&&ewChecks.every(Boolean)&&ewSaved.length===1&&ewSaved[0].deltaY===42&&ewSaved[0].defaultPrevented')! == 'true'
	assert app.scroll_y == 0 && scroller.el_scroll_offset().y() == 0
	assert document.get_element_by_id('ew-result')?.text_content()? == 'ordinary cancelled'
	assert document.get_element_by_id('ew-parent')?.get_attribute_value('style').contains('background-color')
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'ordinary cancelled').len > 0
	event := element_wheel_owner_event(mut runtime, 'ewSaved[0]', true)!
	assert voidptr(event.target()?) == voidptr(inline)
	wheel := unsafe { &dom.WheelEvent(event) }
	assert wheel.delta_y() == 42
	runtime.evaluate_host('ewOrder=[];0')!
	assert app.handle_wheel_at_viewport_point(page.PixelPoint{12.5, 12.25}, page.PixelPoint{111.5, -222.25},
		0, 0, 0, 0, 3.25, false) == .handled
	assert runtime.evaluate_host('ewOrder.join(",")==="wc,dc,rc,pc,bc,bb,pb,rb,db,wb"&&ewSaved.length===2&&!ewSaved[1].defaultPrevented&&ewChecks.every(Boolean)')! == 'true'
	assert scroller.el_scroll_offset().y() == 3.25 && app.scroll_y == 0
	element_wheel_owner_event(mut runtime, 'ewSaved[1]', true)!
	assert !app.dispatch_javascript_event('click', document.get_element_by_id('ew-button')?)
	assert runtime.evaluate_host('ewClicks===1&&ewLoads===1&&ewChecks.every(Boolean)')! == 'true'
	// Neither anonymous specialized descendant was looked up before delivery.
	// Its first event.target lookup must resolve the existing compact facade.
	runtime.evaluate_host('ewAnonymousMode=true;0')!
	for index, tag in ['img', 'video'] {
		runtime.evaluate_host('ewAnonymousTag="${tag}";0')!
		assert app.handle_wheel_at_viewport_point(page.PixelPoint{12.5, 112.25 + f64(index) * 30.0}, page.PixelPoint{},
			0, 0, 0, 0, 2.5, false) == .cancelled
		assert runtime.evaluate_host('ewAnonymousSaved.length===${index + 1}&&ewChecks.every(Boolean)&&ewAnonymousSaved[${index}].target===document.querySelector("${tag}")')! == 'true'
		anonymous := element_wheel_owner_event(mut runtime, 'ewAnonymousSaved[${index}]', true)!
		assert voidptr(anonymous.target()?) == voidptr(runtime.native_event_target(runtime.evaluate_host_value('document.querySelector("${tag}")')!)!)
		assert app.scroll_y == 0 && scroller.el_scroll_offset().y() == 3.25
	}
	assert app.js_messages == []
	element_wheel_owner_balance(runtime, document)
}

fn test_ordinary_wheel_passive_defaults_explicit_cancellation_and_mutations_before_fresh_default_action() {
	$if !darwin { return }
	mut app, mut document, mut runtime := element_wheel_owner_fixture(element_wheel_owner_markup, r'
globalThis.ewMode="passive";globalThis.ewSaved=[];globalThis.ewChecks=[];globalThis.ewPassiveRuns=0;globalThis.ewFalseRuns=0;
globalThis.ewScroller=document.getElementById("ew-scroller");globalThis.ewInline=document.getElementById("ew-inline");
window.addEventListener("wheel",function(e){ewSaved.push(e);e.preventDefault();ewPassiveRuns++;ewChecks.push(!e.defaultPrevented);},{capture:true});
document.addEventListener("wheel",function(e){e.preventDefault();ewPassiveRuns++;ewChecks.push(!e.defaultPrevented);},{capture:true});
document.documentElement.addEventListener("wheel",function(e){e.preventDefault();ewPassiveRuns++;ewChecks.push(!e.defaultPrevented);},{capture:true});
document.body.addEventListener("wheel",function(e){e.preventDefault();ewPassiveRuns++;ewChecks.push(!e.defaultPrevented);},{capture:true});
ewInline.addEventListener("wheel",function(e){e.preventDefault();ewPassiveRuns++;ewChecks.push(!e.defaultPrevented);},{passive:true});
ewInline.addEventListener("wheel",function(e){ewFalseRuns++;ewChecks.push(e.target===ewInline&&this===ewInline);return false;});
document.body.addEventListener("wheel",function(e){if(ewMode==="cancel"){e.preventDefault();document.getElementById("ew-result").textContent="passive override cancelled";document.getElementById("ew-parent").style.color="rgb(0,128,0)";}else if(ewMode==="fresh"){ewScroller.style.overflow="visible";document.getElementById("ew-button").remove();document.getElementById("ew-result").textContent="fresh ordinary default";}},{passive:false});0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	scroller := document.get_element_by_id('ew-scroller')?
	assert app.handle_wheel_at_viewport_point(page.PixelPoint{12.5, 12.25}, page.PixelPoint{}, 0,
		0, 0, 0, 2.5, false) == .handled
	assert scroller.el_scroll_offset().y() == 2.5 && app.scroll_y == 0
	assert runtime.evaluate_host('ewSaved.length===1&&!ewSaved[0].defaultPrevented&&ewPassiveRuns===5&&ewFalseRuns===1&&ewChecks.every(Boolean)')! == 'true'
	element_wheel_owner_event(mut runtime, 'ewSaved[0]', true)!
	runtime.evaluate_host('ewMode="cancel";0')!
	assert app.handle_wheel_at_viewport_point(page.PixelPoint{12.5, 12.25}, page.PixelPoint{}, 0,
		0, 0, 0, 7.5, false) == .cancelled
	assert scroller.el_scroll_offset().y() == 2.5 && app.scroll_y == 0
	assert document.get_element_by_id('ew-result')?.text_content()? == 'passive override cancelled'
	assert document.get_element_by_id('ew-parent')?.get_attribute_value('style').contains('color')
	assert app.paint_commands.filter(it.kind == 'draw_text'
		&& it.text == 'passive override cancelled').len > 0
	assert runtime.evaluate_host('ewSaved.length===2&&ewSaved[1].defaultPrevented&&ewPassiveRuns===10&&ewFalseRuns===2&&ewChecks.every(Boolean)')! == 'true'
	element_wheel_owner_event(mut runtime, 'ewSaved[1]', true)!
	runtime.evaluate_host('ewMode="fresh";0')!
	assert app.handle_wheel_at_viewport_point(page.PixelPoint{12.5, 12.25}, page.PixelPoint{}, 0,
		0, 0, 0, 3.75, false) == .handled
	assert app.scroll_y == 3.75
	assert document.get_element_by_id('ew-button') == none
	assert scroller.get_attribute_value('style').contains('overflow: visible')
	assert document.get_element_by_id('ew-result')?.text_content()? == 'fresh ordinary default'
	assert runtime.evaluate_host('ewSaved.length===3&&!ewSaved[2].defaultPrevented&&ewPassiveRuns===15&&ewFalseRuns===3&&ewChecks.every(Boolean)')! == 'true'
	element_wheel_owner_event(mut runtime, 'ewSaved[2]', true)!
	assert app.js_messages == []
	element_wheel_owner_balance(runtime, document)
}

fn test_created_div_and_svg_wheel_listeners_keep_the_native_owner_through_append_move_rename_and_duplicate_ids() {
	$if !darwin { return }
	markup := '<!doctype html><style>html,body{margin:0}body{height:1500px}#ew-dock-a,#ew-dock-b{position:absolute;left:0;width:240px;height:90px}#ew-dock-a{top:0}#ew-dock-b{top:100px}</style><div id="ew-dock-a"></div><div id="ew-dock-b"></div>'
	mut app, mut document, mut runtime := element_wheel_owner_fixture(markup, r'
globalThis.ewDockA=document.getElementById("ew-dock-a");globalThis.ewDockB=document.getElementById("ew-dock-b");globalThis.ewCreatedSaved=[];globalThis.ewCreatedChecks=[];
globalThis.ewCreatedDiv=document.createElement("div");ewCreatedDiv.id="created-wheel";ewCreatedDiv.style.display="block";ewCreatedDiv.style.width="120px";ewCreatedDiv.style.height="40px";ewCreatedDiv.textContent="created wheel";
globalThis.ewCreatedSvg=document.createElementNS("http://www.w3.org/2000/svg","svg");ewCreatedSvg.id="created-wheel-svg";ewCreatedSvg.setAttribute("width","120");ewCreatedSvg.setAttribute("height","40");ewCreatedSvg.style.display="block";
globalThis.ewCreatedRect=document.createElementNS("http://www.w3.org/2000/svg","rect");ewCreatedRect.setAttribute("width","120");ewCreatedRect.setAttribute("height","40");ewCreatedRect.setAttribute("fill","green");ewCreatedSvg.appendChild(ewCreatedRect);
for(const target of [ewCreatedDiv,ewCreatedSvg])target.addEventListener("wheel",function(e){ewCreatedSaved.push(e);ewCreatedChecks.push(this===target&&e.currentTarget===target&&e.target===(target===ewCreatedSvg?ewCreatedRect:ewCreatedDiv)&&window.event===e&&e instanceof WheelEvent);e.preventDefault();});0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	div := runtime.native_event_target(runtime.evaluate_host_value('ewCreatedDiv')!)!
	svg := runtime.native_event_target(runtime.evaluate_host_value('ewCreatedSvg')!)!
	rect := runtime.native_event_target(runtime.evaluate_host_value('ewCreatedRect')!)!
	assert document.get_element_by_id('created-wheel') == none
	runtime.evaluate_host('ewDockA.appendChild(ewCreatedDiv);ewDockB.appendChild(ewCreatedSvg);0')!
	runtime.mark_document_state_dirty()
	app.poll_javascript_tasks()
	assert voidptr(document.get_element_by_id('created-wheel')?) == voidptr(div)
	assert voidptr(document.get_element_by_id('created-wheel-svg')?) == voidptr(svg)
	rect_node := unsafe { &dom.Node(rect) }
	assert voidptr(rect_node.parent()?) == voidptr(svg)
	for index, point in [page.PixelPoint{12.5, 12.25}, page.PixelPoint{12.5, 112.25}] {
		assert app.handle_wheel_at_viewport_point(point, page.PixelPoint{}, 0, 0, 0, 0, 2.5, false) == .cancelled
		event := element_wheel_owner_event(mut runtime, 'ewCreatedSaved[${index}]', true)!
		mut expected_target := voidptr(div)
		if index != 0 {
			expected_target = voidptr(rect)
		}
		assert voidptr(event.target()?) == expected_target
		assert app.scroll_y == 0
	}
	runtime.evaluate_host(r'ewCreatedDiv.id="collision";globalThis.ewDuplicate=document.createElement("div");ewDuplicate.id="collision";ewDuplicate.style.height="40px";ewDockA.insertBefore(ewDuplicate,ewDockA.firstChild);ewDockB.moveBefore(ewCreatedDiv,null);0')!
	runtime.mark_document_state_dirty()
	app.poll_javascript_tasks()
	duplicate := runtime.native_event_target(runtime.evaluate_host_value('ewDuplicate')!)!
	assert voidptr(duplicate) != voidptr(div)
	assert voidptr(document.get_element_by_id('collision')?) == voidptr(duplicate)
	div_element := unsafe { &dom.Element(div) }
	assert div_element.get_attribute_value('id') == 'collision'
	assert voidptr(div_element.as_node().parent()?) == voidptr(document.get_element_by_id('ew-dock-b')?)
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('ewCreatedDiv')!)!) == voidptr(div)
	assert runtime.javascript_event_target(div, none)! == runtime.evaluate_host_value('ewCreatedDiv')!
	assert app.handle_wheel_at_viewport_point(page.PixelPoint{12.5, 152.25}, page.PixelPoint{}, 0,
		0, 0, 0, 4.25, false) == .cancelled
	element_wheel_owner_event(mut runtime, 'ewCreatedSaved[2]', true)!
	assert runtime.evaluate_host('ewCreatedSaved.length===3&&ewCreatedChecks.every(Boolean)&&ewCreatedSaved[2].target===ewCreatedDiv')! == 'true'
	// Redispatch the retained real platform event through the public bridge.
	assert runtime.evaluate_host('(()=>{const e=ewCreatedSaved[0],stamp=e.timeStamp;return ewCreatedDiv.dispatchEvent(e)===false&&ewCreatedSaved.length===4&&ewCreatedSaved[3]===e&&!e.isTrusted&&e.timeStamp===stamp&&ewCreatedChecks.every(Boolean)})()')! == 'true'
	element_wheel_owner_event(mut runtime, 'ewCreatedSaved[0]', false)!
	assert app.scroll_y == 0 && app.js_messages == []
	element_wheel_owner_balance(runtime, document)
}
