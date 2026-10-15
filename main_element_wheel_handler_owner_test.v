module main

import browserjs
import dom
import gg
import html
import page
import time

const element_wheel_handler_owner_markup = '<!doctype html><style>
html,body{margin:0}body{height:1500px}
#eh-scroller{width:240px;height:100px;overflow:auto}
#eh-target{width:180px;height:60px}
#eh-content{height:500px}
#eh-result{position:absolute;top:170px;left:0}
</style><div id="eh-scroller"><div id="eh-target">wheel target</div><div id="eh-content"></div></div><div id="eh-result">waiting</div>'

@[heap]
struct ElementWheelHandlerOwnerObservation {
mut:
	events []&dom.Event
	targets []voidptr
	trusted []bool
	inner_before []f64
}

fn element_wheel_handler_owner_fixture(markup string, source string) !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	owner.set_enable_autoscroll(false)
	document := parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: 'https://element-wheel-handler-owner.example.test/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	runtime := browserjs.Runtime.create()
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [source], runtime, mut messages)
	assert messages == []
	mut app := &BrowserApp{
		page_model: owner
		document: document
		js_runtime: runtime
		viewport_width: 320
		viewport_height: 240
	}
	app.relayout(320, 240 + app.chrome_height())
	assert document.layout_is_up_to_date() && document.paintable_box() != none
	return app, document, runtime
}

fn element_wheel_handler_owner_guard(runtime &browserjs.Runtime, targets string) !bool {
	// Check the public accessor before assignment could mask a missing binding.
	return runtime.evaluate_host('(${targets}).every(target=>{const d=Object.getOwnPropertyDescriptor(target,"onwheel");return !!d&&d.enumerable&&d.configurable&&d.get.name==="get onwheel"&&d.set.name==="set onwheel"&&d.get.length===0&&d.set.length===1&&[d.get,d.set].every(callback=>Function.prototype.toString.call(callback).includes("[native code]"))&&target.onwheel===null})')! == 'true'
}

fn element_wheel_handler_owner_probe(mut runtime browserjs.Runtime, document &dom.Document) ! {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	handle := voidptr(&runtime)
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function('__elementWheelHandlerOwnerContext', fn [settings, handle, actual_true] (_ voidptr, args []voidptr) !voidptr {
		owner := unsafe { &browserjs.Runtime(handle) }
		assert args.len == 0
		assert settings.realm().script_execution_depth > 0 && settings.realm().callback_execution_depth > 0
		assert owner.libjs_vm().has_running_execution_context()
		assert voidptr(html.current_principal_settings_object()) == voidptr(settings)
		assert voidptr(html.incumbent_settings_object()) == voidptr(settings)
		return actual_true
	})!
}

fn element_wheel_handler_owner_observe(element &dom.Element, scroller &dom.Element, observation &ElementWheelHandlerOwnerObservation) {
	handle := voidptr(observation)
	callback := &dom.CallbackType{
		handle_event: fn [handle, scroller] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut saved := unsafe { &ElementWheelHandlerOwnerObservation(handle) }
			assert event.interface_ == .wheel_event
			saved.events << event
			saved.targets << voidptr(event.target() or { panic('Native wheel needs its DOM target') })
			saved.trusted << event.is_trusted()
			saved.inner_before << scroller.el_scroll_offset().y()
			return dom.js_undefined()
		}
	}
	unsafe { &dom.EventTarget(element) }.add_event_listener_without_options('wheel', dom.IDLEventListener.create(callback))
}

fn element_wheel_handler_owner_event(mut runtime browserjs.Runtime, event &dom.Event, expression string, trusted bool) ! {
	wrapper := runtime.evaluate_host_value(expression)!
	assert voidptr(runtime.native_event(wrapper)!) == voidptr(event)
	assert runtime.javascript_event(event)! == wrapper
	assert event.is_trusted() == trusted && event.current_target() == none && event.event_phase() == 0
	assert runtime.evaluate_host('${expression}.currentTarget===null&&${expression}.eventPhase===Event.NONE&&window.event===undefined')! == 'true'
}

fn element_wheel_handler_owner_balance(runtime &browserjs.Runtime, document &dom.Document, exceptions int) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == exceptions
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_element_onwheel_real_gg_false_cancellation_native_slot_order_and_raw_attribute_replay() {
	$if !darwin { return }
	mut app, mut document, mut runtime := element_wheel_handler_owner_fixture(element_wheel_handler_owner_markup,
		r'globalThis.ehTarget=document.getElementById("eh-target");globalThis.ehRawRuns=0;0')!
	defer {
		runtime.close()
		document.finalize()
	}
	assert element_wheel_handler_owner_guard(runtime, '[ehTarget]')!
	element_wheel_handler_owner_probe(mut runtime, document)!
	target := document.get_element_by_id('eh-target')?
	scroller := document.get_element_by_id('eh-scroller')?
	native_target := runtime.native_event_target(runtime.evaluate_host_value('ehTarget')!)!
	assert voidptr(native_target) == voidptr(target)
	observation := &ElementWheelHandlerOwnerObservation{}
	element_wheel_handler_owner_observe(target, scroller, observation)
	runtime.evaluate_host(r'
globalThis.ehOrder=[];globalThis.ehSaved=[];globalThis.ehChecks=[];globalThis.ehAfterStates=[];globalThis.ehReturn=false;
ehTarget.addEventListener("wheel",function(e){ehOrder.push("before");ehChecks.push(this===ehTarget&&e.currentTarget===ehTarget&&!e.defaultPrevented)});
ehTarget.onwheel=function(){ehOrder.push("obsolete")};
ehTarget.addEventListener("wheel",function(e){ehOrder.push("after");ehAfterStates.push(e.defaultPrevented);ehChecks.push(this===ehTarget&&e.currentTarget===ehTarget&&window.event===e)});
ehTarget.removeAttribute("onwheel");ehTarget.setAttribute("onwheel","globalThis.ehRawRuns++");
globalThis.ehAbsentRawGetter=typeof ehTarget.onwheel==="function";
globalThis.ehReplacement=function(e){ehOrder.push("handler");ehSaved.push(e);ehChecks.push(arguments.length===1&&this===ehTarget&&e.target===ehTarget&&e.currentTarget===ehTarget&&e instanceof WheelEvent&&Object.getPrototypeOf(e)===WheelEvent.prototype&&e.isTrusted&&e.bubbles&&e.cancelable&&e.composed&&e.view===window&&e.deltaMode===WheelEvent.DOM_DELTA_PIXEL&&window.event===e&&__elementWheelHandlerOwnerContext());document.getElementById("eh-result").textContent="handler painted";ehTarget.style.color="rgb(0,128,0)";return ehReturn};
ehTarget.onwheel=ehReplacement;
ehTarget.setAttribute("onwheel","globalThis.ehRawRuns++");ehTarget.onwheel=ehReplacement;0
')!
	assert runtime.javascript_event_handler(native_target, 'wheel')! == runtime.evaluate_host_value('ehReplacement')!
	assert runtime.evaluate_host('ehAbsentRawGetter&&ehTarget.onwheel===ehReplacement&&ehRawRuns===0')! == 'true'
	slot := native_target.data.event_handler('wheel') or { panic('Native wheel handler slot missing') }
	assert slot.value.kind == .object && target.get_attribute('onwheel')? == 'globalThis.ehRawRuns++'
	app.handle_event(&gg.Event{
		typ: .mouse_scroll
		mouse_x: 12.5
		mouse_y: 12.25 + app.page_top()
		scroll_y: -1
		window_height: 240 + app.chrome_height()
	})
	assert observation.events.len == 1 && observation.targets[0] == voidptr(target)
	assert observation.inner_before == [f64(0)] && app.scroll_y == 0 && scroller.el_scroll_offset().y() == 0
	assert runtime.evaluate_host('ehOrder.join(",")==="before,handler,after"&&ehAfterStates[0]&&ehSaved[0].deltaY===42&&ehSaved[0].defaultPrevented&&ehRawRuns===0&&ehChecks.every(Boolean)')! == 'true'
	assert document.get_element_by_id('eh-result')?.text_content()? == 'handler painted'
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'handler painted').len > 0
	element_wheel_handler_owner_event(mut runtime, observation.events[0], 'ehSaved[0]', true)!
	for index, value in ['new Boolean(false)', '0'] {
		runtime.evaluate_host('ehOrder=[];ehReturn=${value};ehTarget.onwheel=ehReplacement;0')!
		assert app.handle_wheel_at_viewport_point(page.PixelPoint{12.5, 12.25}, page.PixelPoint{101.25, 202.5},
			0, 0, 0, 0, 2.5, false) == .handled
		assert scroller.el_scroll_offset().y() == f64(index + 1) * 2.5 && app.scroll_y == 0
		assert runtime.evaluate_host('ehOrder.join(",")==="before,handler,after"&&!ehSaved[${index + 1}].defaultPrevented&&ehChecks.every(Boolean)')! == 'true'
		assert voidptr(native_target.data.event_handler('wheel') or { panic('Replaced slot missing') }) == voidptr(slot)
		element_wheel_handler_owner_event(mut runtime, observation.events[index + 1], 'ehSaved[${index + 1}]', true)!
	}
	// Repeating the same raw text after IDL assignment wins on getter replay.
	// Reading lazily compiles the replacement without moving its listener slot.
	assert runtime.evaluate_host('ehOrder=[];ehTarget.setAttribute("onwheel","globalThis.ehRawRuns++");typeof ehTarget.onwheel==="function"')! == 'true'
	raw := native_target.data.event_handler('wheel') or { panic('Raw native slot missing') }
	assert voidptr(raw) == voidptr(slot) && raw.value.kind == .object
	raw_callback := unsafe { &dom.CallbackType(raw.value.object_data) }
	assert raw_callback.compiled_source_text_ == 'function onwheel(event) {\n' + 'globalThis.ehRawRuns++' + '\n}'
	assert target.get_attribute('onwheel')? == 'globalThis.ehRawRuns++'
	assert app.handle_wheel_at_viewport_point(page.PixelPoint{12.5, 12.25}, page.PixelPoint{}, 0, 0, 0, 0, 2.5, false) == .handled
	assert scroller.el_scroll_offset().y() == 7.5 && app.scroll_y == 0
	assert runtime.evaluate_host('ehOrder.join(",")==="before,after"&&ehSaved.length===3&&ehRawRuns===1')! == 'true'
	assert raw.value.kind == .object
	// Null removes the slot; reinstalling adds it after the existing listeners.
	assert runtime.evaluate_host('ehTarget.onwheel=null;ehTarget.onwheel===null')! == 'true'
	assert !native_target.data.has_event_handler('wheel')
	runtime.evaluate_host('ehOrder=[];ehReturn=false;ehTarget.onwheel=ehReplacement;0')!
	assert app.handle_wheel_at_viewport_point(page.PixelPoint{12.5, 12.25}, page.PixelPoint{}, 0, 0, 0, 0, 3.75, false) == .cancelled
	assert scroller.el_scroll_offset().y() == 7.5 && app.scroll_y == 0
	restarted := native_target.data.event_handler('wheel') or { panic('Reinstalled slot missing') }
	assert voidptr(restarted) != voidptr(slot)
	assert runtime.evaluate_host('ehOrder.join(",")==="before,after,handler"&&!ehAfterStates[4]&&ehSaved[3].defaultPrevented&&ehRawRuns===1&&ehChecks.every(Boolean)')! == 'true'
	element_wheel_handler_owner_event(mut runtime, observation.events[4], 'ehSaved[3]', true)!
	// Removing an existing raw attribute clears the later IDL handler. Removing
	// that now-absent attribute must leave a subsequently installed handler alone.
	assert runtime.evaluate_host('ehTarget.removeAttribute("onwheel");ehTarget.onwheel===null')! == 'true'
	assert target.get_attribute('onwheel') == none && !native_target.data.has_event_handler('wheel')
	assert runtime.evaluate_host('ehTarget.onwheel=ehReplacement;ehTarget.removeAttribute("onwheel");ehTarget.onwheel===ehReplacement')! == 'true'
	assert target.get_attribute('onwheel') == none
	assert runtime.javascript_event_handler(native_target, 'wheel')! == runtime.evaluate_host_value('ehReplacement')!
	assert app.handle_wheel_at_viewport_point(page.PixelPoint{12.5, 12.25}, page.PixelPoint{}, 0, 0, 0, 0, 2.5, false) == .cancelled
	assert scroller.el_scroll_offset().y() == 7.5 && app.scroll_y == 0
	element_wheel_handler_owner_event(mut runtime, observation.events[5], 'ehSaved[4]', true)!
	assert observation.trusted == [true, true, true, true, true, true] && app.js_messages == []
	element_wheel_handler_owner_balance(runtime, document, 0)
}

fn test_element_onwheel_created_svg_and_anonymous_image_keep_owners_and_media_keeps_its_prototype() {
	$if !darwin { return }
	markup := '<!doctype html><style>html,body{margin:0}body{height:1500px}#eh-dock-a,#eh-dock-b{position:absolute;top:0;width:120px;height:40px}#eh-dock-a{left:0}#eh-dock-b{left:150px}#eh-svg{position:absolute;left:0;top:60px}#eh-anonymous{position:absolute;left:0;top:120px}#eh-anonymous img{display:block;width:120px;height:40px}#eh-video{position:absolute;left:0;top:180px;width:120px;height:40px}</style><div id="eh-dock-a"></div><div id="eh-dock-b"></div><svg id="eh-svg" width="120" height="40"><rect id="eh-rect" width="120" height="40" fill="green"></rect></svg><div id="eh-anonymous"><img src="data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw=="></div><video id="eh-video" controls></video>'
	mut app, mut document, mut runtime := element_wheel_handler_owner_fixture(markup, r'
globalThis.ehDockA=document.getElementById("eh-dock-a");globalThis.ehDockB=document.getElementById("eh-dock-b");globalThis.ehSvg=document.getElementById("eh-svg");globalThis.ehRect=document.getElementById("eh-rect");globalThis.ehAnonymous=document.getElementById("eh-anonymous");globalThis.ehVideo=document.getElementById("eh-video");
globalThis.ehCreated=document.createElement("div");ehCreated.id="eh-created";ehCreated.style.width="120px";ehCreated.style.height="40px";ehCreated.textContent="created handler";ehDockA.appendChild(ehCreated);
globalThis.ehMath=document.createElementNS("http://www.w3.org/1998/Math/MathML","math");globalThis.ehForeign=document.createElementNS("urn:element-wheel","foreign");globalThis.ehNull=document.createElementNS(null,"null-wheel");globalThis.ehEmpty=document.createElementNS("","empty-wheel");0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	assert element_wheel_handler_owner_guard(runtime, '[ehCreated,ehSvg,ehRect,ehAnonymous,ehMath]')!
	assert runtime.evaluate_host('[ehForeign,ehNull,ehEmpty].every(target=>!("onwheel" in target)&&!Object.hasOwn(target,"onwheel"))&&Object.getPrototypeOf(ehVideo)===HTMLVideoElement.prototype&&!Object.hasOwn(ehVideo,"onwheel")&&ehVideo.onwheel===null')! == 'true'
	for expression in ['ehNull', 'ehEmpty'] {
		foreign := unsafe { &dom.Element(runtime.native_event_target(runtime.evaluate_host_value(expression)!)!) }
		assert foreign.namespace_uri() == none
	}
	unknown := unsafe { &dom.Element(runtime.native_event_target(runtime.evaluate_host_value('ehForeign')!)!) }
	assert unknown.namespace_uri()? == 'urn:element-wheel'
	assert runtime.evaluate_host('(()=>{let calls=0;const checks=[];for(const target of [ehForeign,ehNull,ehEmpty]){target.addEventListener("wheel",function(e){calls++;checks.push(this===target&&e.target===target&&!e.isTrusted)});if(!target.dispatchEvent(new WheelEvent("wheel")))return false;}return calls===3&&checks.every(Boolean)&&[ehForeign,ehNull,ehEmpty].every(target=>!("onwheel" in target))})()')! == 'true'
	element_wheel_handler_owner_probe(mut runtime, document)!
	created := document.get_element_by_id('eh-created')?
	svg := document.get_element_by_id('eh-svg')?
	rect := document.get_element_by_id('eh-rect')?
	anonymous := document.get_element_by_id('eh-anonymous')?
	image_node := anonymous.as_node().first_child()?
	video := document.get_element_by_id('eh-video')?
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('ehCreated')!)!) == voidptr(created)
	runtime.evaluate_host(r'
globalThis.ehOwnedSaved=[];globalThis.ehOwnedChecks=[];globalThis.ehOwnedTrusted=true;
for(const target of [ehCreated,ehSvg,ehAnonymous,ehVideo])target.onwheel=function(e){ehOwnedSaved.push(e);const expected=target===ehSvg?ehRect:target===ehAnonymous?document.querySelector("img"):target;ehOwnedChecks.push(this===target&&arguments.length===1&&e.target===expected&&e.currentTarget===target&&e instanceof WheelEvent&&e.isTrusted===ehOwnedTrusted&&window.event===e&&__elementWheelHandlerOwnerContext());if(target===ehAnonymous)ehOwnedChecks.push(Object.getPrototypeOf(e.target)===HTMLImageElement.prototype&&Object.hasOwn(e.target,"onwheel")&&e.target.onwheel===null);return false};0
')!
	for index, point in [page.PixelPoint{12.5, 12.25}, page.PixelPoint{12.5, 72.25}, page.PixelPoint{12.5, 132.25}, page.PixelPoint{12.5, 192.25}] {
		assert app.handle_wheel_at_viewport_point(point, page.PixelPoint{}, 0, 0, 0, 0, 2.5, false) == .cancelled
		event := runtime.native_event(runtime.evaluate_host_value('ehOwnedSaved[${index}]')!)!
		expected := [voidptr(created), voidptr(rect), voidptr(image_node), voidptr(video)]
		assert voidptr(event.target()?) == expected[index]
		element_wheel_handler_owner_event(mut runtime, event, 'ehOwnedSaved[${index}]', true)!
		assert app.scroll_y == 0
	}
	assert runtime.evaluate_host('ehOwnedSaved.length===4&&ehOwnedChecks.every(Boolean)')! == 'true'
	runtime.evaluate_host('ehCreated.id="moved-handler";ehDockB.appendChild(ehCreated);0')!
	runtime.mark_document_state_dirty()
	app.poll_javascript_tasks()
	assert voidptr(document.get_element_by_id('moved-handler')?) == voidptr(created)
	assert voidptr(created.as_node().parent()?) == voidptr(document.get_element_by_id('eh-dock-b')?)
	assert app.handle_wheel_at_viewport_point(page.PixelPoint{162.5, 12.25}, page.PixelPoint{}, 0, 0, 0, 0, 4.25, false) == .cancelled
	moved_event := runtime.native_event(runtime.evaluate_host_value('ehOwnedSaved[4]')!)!
	assert voidptr(moved_event.target()?) == voidptr(created)
	// Public redispatch reuses the same native event and wrapper, removing trust.
	assert runtime.evaluate_host('(()=>{ehOwnedTrusted=false;const e=ehOwnedSaved[0],stamp=e.timeStamp;return ehCreated.dispatchEvent(e)===false&&ehOwnedSaved.length===6&&ehOwnedSaved[5]===e&&!e.isTrusted&&e.timeStamp===stamp&&ehOwnedChecks.every(Boolean)})()')! == 'true'
	event := runtime.native_event(runtime.evaluate_host_value('ehOwnedSaved[0]')!)!
	element_wheel_handler_owner_event(mut runtime, event, 'ehOwnedSaved[0]', false)!
	assert app.scroll_y == 0 && app.js_messages == []
	element_wheel_handler_owner_balance(runtime, document, 0)
}

fn test_element_onwheel_async_passive_page_gate_exception_and_close_balance_owner_lifecycle() {
	$if !darwin { return }
	mut app, mut document, mut runtime := element_wheel_handler_owner_fixture(element_wheel_handler_owner_markup,
		r'globalThis.ehTarget=document.getElementById("eh-target");0')!
	defer {
		runtime.close()
		document.finalize()
	}
	assert element_wheel_handler_owner_guard(runtime, '[ehTarget]')!
	element_wheel_handler_owner_probe(mut runtime, document)!
	target := document.get_element_by_id('eh-target')?
	scroller := document.get_element_by_id('eh-scroller')?
	observation := &ElementWheelHandlerOwnerObservation{}
	element_wheel_handler_owner_observe(target, scroller, observation)
	runtime.evaluate_host(r'
globalThis.ehMode="prevent";globalThis.ehLifecycleSaved=[];globalThis.ehLifecycleOrder=[];globalThis.ehLifecycleChecks=[];globalThis.ehThrown={message:"element wheel original exception"};
ehTarget.addEventListener("wheel",function(e){ehLifecycleOrder.push("passive");e.preventDefault();ehLifecycleChecks.push(!e.defaultPrevented)},{passive:true});
ehTarget.onwheel=function(e){ehLifecycleSaved.push(e);ehLifecycleOrder.push("handler");ehLifecycleChecks.push(this===ehTarget&&e.target===ehTarget&&e.currentTarget===ehTarget&&e instanceof WheelEvent&&e.isTrusted&&window.event===e&&__elementWheelHandlerOwnerContext());if(ehMode==="throw")throw ehThrown;if(ehMode==="false")return false;e.preventDefault();return 0};
ehTarget.addEventListener("wheel",function(e){ehLifecycleOrder.push("after");ehLifecycleChecks.push(this===ehTarget&&e.currentTarget===ehTarget&&window.event===e);if(ehMode==="throw")e.preventDefault()});0
')!
	for index, mode in ['prevent', 'false'] {
		runtime.evaluate_host('ehMode="${mode}";0')!
		assert app.handle_wheel_at_viewport_point(page.PixelPoint{12.5, 12.25}, page.PixelPoint{}, 0, 0, 0, 1.5, 2.5, true) == .handled
		assert scroller.el_scroll_offset().y() == 0 && app.scroll_y == 0
		assert !observation.events[index].cancelable()
		assert observation.events[index].default_prevented() == (mode == 'false')
		element_wheel_handler_owner_event(mut runtime, observation.events[index], 'ehLifecycleSaved[${index}]', true)!
	}
	assert runtime.evaluate_host('ehLifecycleSaved.length===2&&ehLifecycleChecks.every(Boolean)&&!ehLifecycleSaved[0].defaultPrevented&&ehLifecycleSaved[1].defaultPrevented')! == 'true'
	mut owner := app.page_model
	owner.set_is_scripting_enabled(false)
	assert app.handle_wheel_at_viewport_point(page.PixelPoint{12.5, 12.25}, page.PixelPoint{}, 0, 0, 0, 0, 2.5, false) == .handled
	assert scroller.el_scroll_offset().y() == 2.5 && app.scroll_y == 0
	assert observation.events.len == 3 && !observation.events[2].default_prevented()
	assert runtime.evaluate_host('ehLifecycleSaved.length===2&&ehLifecycleOrder.join(",")==="passive,handler,after,passive,handler,after"&&window.event===undefined')! == 'true'
	element_wheel_handler_owner_balance(runtime, document, 0)
	owner.set_is_scripting_enabled(true)
	runtime.evaluate_host('ehMode="throw";0')!
	assert app.handle_wheel_at_viewport_point(page.PixelPoint{12.5, 12.25}, page.PixelPoint{}, 0, 0, 0, 0, 7.5, false) == .cancelled
	assert scroller.el_scroll_offset().y() == 2.5 && app.scroll_y == 0
	assert runtime.evaluate_host('ehLifecycleSaved.length===3&&ehLifecycleOrder.join(",")==="passive,handler,after,passive,handler,after,passive,handler,after"&&ehLifecycleChecks.every(Boolean)&&window.event===undefined')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 1
	assert runtime.actual_webidl_value(settings.realm().reported_exceptions[0].value.as_webidl_value()!)! == runtime.evaluate_host_value('ehThrown')!
	element_wheel_handler_owner_event(mut runtime, observation.events[3], 'ehLifecycleSaved[2]', true)!
	element_wheel_handler_owner_balance(runtime, document, 1)
	runtime.close()
	assert app.handle_wheel_at_viewport_point(page.PixelPoint{12.5, 12.25}, page.PixelPoint{}, 0, 0, 0, 0, 2.5, false) == .handled
	assert scroller.el_scroll_offset().y() == 5 && app.scroll_y == 0
	assert observation.events.len == 5 && observation.trusted == [true, true, true, true, true]
	assert !observation.events[4].default_prevented() && observation.events[4].current_target() == none
	assert app.js_messages == []
	element_wheel_handler_owner_balance(runtime, document, 1)
}
