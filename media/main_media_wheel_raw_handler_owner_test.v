module main

import browserjs
import dom
import gg
import html
import page
import time

const media_wheel_raw_handler_owner_markup = '<!doctype html><style>
html,body{margin:0}body{height:1500px}
#mr-scroller{width:240px;height:100px;overflow:auto}
#mr-video{display:block;width:180px;height:60px}
#mr-content{height:500px}
#mr-result{position:absolute;top:170px;left:0}
</style><form id="mr-form"><div id="mr-scroller"><video id="mr-video"></video><div id="mr-content"></div></div></form><div id="mr-result">waiting</div>'

@[heap]
struct MediaWheelRawHandlerOwnerObservation {
mut:
	events []&dom.Event
	targets []voidptr
	trusted []bool
	inner_before []f64
}

fn media_wheel_raw_handler_owner_fixture(markup string, source string) !(&BrowserApp, &dom.Document, &browserjs.Runtime) {
	mut owner := page.Page.create(1)!
	owner.set_enable_autoscroll(false)
	document := parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: 'https://media-wheel-raw-handler-owner.example.test/'
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

fn media_wheel_raw_handler_owner_probe(mut runtime browserjs.Runtime, document &dom.Document) ! {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	handle := voidptr(&runtime)
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function('__mediaWheelRawHandlerOwnerContext', fn [settings, handle, actual_true] (_ voidptr, args []voidptr) !voidptr {
		owner := unsafe { &browserjs.Runtime(handle) }
		assert args.len == 0
		assert settings.realm().script_execution_depth > 0 && settings.realm().callback_execution_depth > 0
		assert owner.libjs_vm().has_running_execution_context()
		assert voidptr(html.current_principal_settings_object()) == voidptr(settings)
		assert voidptr(html.incumbent_settings_object()) == voidptr(settings)
		return actual_true
	})!
}

fn media_wheel_raw_handler_owner_observe(element &dom.Element, scroller &dom.Element, observation &MediaWheelRawHandlerOwnerObservation) {
	handle := voidptr(observation)
	callback := &dom.CallbackType{
		handle_event: fn [handle, scroller] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut saved := unsafe { &MediaWheelRawHandlerOwnerObservation(handle) }
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

fn media_wheel_raw_handler_owner_event(mut runtime browserjs.Runtime, event &dom.Event, expression string, trusted bool) ! {
	wrapper := runtime.evaluate_host_value(expression)!
	assert voidptr(runtime.native_event(wrapper)!) == voidptr(event)
	assert runtime.javascript_event(event)! == wrapper
	assert event.is_trusted() == trusted && event.current_target() == none && event.event_phase() == 0
	assert runtime.evaluate_host('${expression}.currentTarget===null&&${expression}.eventPhase===Event.NONE&&window.event===undefined')! == 'true'
}

fn media_wheel_raw_handler_owner_balance(runtime &browserjs.Runtime, document &dom.Document, exceptions int) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == exceptions
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn media_wheel_raw_handler_owner_platform_event(document &dom.Document) &dom.Event {
	wheel := dom.WheelEvent.create_from_platform_event(voidptr(document.get_window() or {
		panic('Raw media wheel owner needs its Window')
	}), 'wheel', dom.CSSPixelPoint_{111.25, 221.75}, dom.CSSPixelPoint_{31.5, 41.125},
		dom.CSSPixelPoint_{11.5, 21.125}, dom.CSSPixelPoint_{1.75, 2.625}, 2.5, -3.6, 2, 2,
		dom.modifier_ctrl | dom.modifier_shift | dom.modifier_alt | dom.modifier_super)
	return unsafe { &dom.Event(wheel) }
}

fn test_media_raw_onwheel_parsed_and_created_owner_scopes_cache_real_gg_cancellation_and_paint() {
	$if !darwin { return }
	body := r'globalThis.mrRuns++;mrScopeValues.push(scopeKey);delete this.scopeKey;mrScopeValues.push(scopeKey);delete document.scopeKey;mrScopeValues.push(scopeKey);mrSaved.push(event);mrChecks.push(arguments.length===1&&event===arguments[0]&&this===mrCurrent&&event.target===mrCurrent&&event.currentTarget===mrCurrent&&event instanceof WheelEvent&&event.isTrusted===mrTrusted&&event.view===window&&window.event===event&&document===mrDocument&&getElementById("mr-result")===mrResult&&__mediaWheelRawHandlerOwnerContext());getElementById("mr-result").textContent="raw media wheel painted";this.style.color="rgb(0,128,0)";return false;'
	markup := media_wheel_raw_handler_owner_markup.replace('<video id="mr-video">',
		'<video id="mr-video" onwheel="${body.replace('"', '&quot;')}">')
	mut app, mut document, mut runtime := media_wheel_raw_handler_owner_fixture(markup, r'
globalThis.mrVideo=document.getElementById("mr-video");globalThis.mrDocument=document;globalThis.mrResult=document.getElementById("mr-result");globalThis.mrForm=document.getElementById("mr-form");
globalThis.mrRuns=0;globalThis.mrScopeValues=[];globalThis.mrSaved=[];globalThis.mrChecks=[];globalThis.mrAfterStates=[];globalThis.scopeKey="global";
document.scopeKey="document";mrForm.scopeKey="nearest form";mrVideo.scopeKey="parsed element";mrVideo.event={sentinel:true};globalThis.mrCurrent=mrVideo;globalThis.mrTrusted=true;
globalThis.mrAudio=document.createElement("audio");mrAudio.id="mr-audio";mrAudio.setAttribute("onwheel",mrVideo.getAttribute("onwheel"));document.body.appendChild(mrAudio);void mrAudio.paused;
mrVideo.addEventListener("wheel",function(event){mrAfterStates.push(event.defaultPrevented);mrChecks.push(this===mrVideo&&event.currentTarget===mrVideo)});0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_wheel_raw_handler_owner_probe(mut runtime, document)!
	video := document.get_element_by_id('mr-video')?
	audio := document.get_element_by_id('mr-audio')?
	scroller := document.get_element_by_id('mr-scroller')?
	native_video := unsafe { &dom.EventTarget(video) }
	native_audio := unsafe { &dom.EventTarget(audio) }
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('mrVideo')!)!) == voidptr(video)
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('mrAudio')!)!) == voidptr(audio)
	video_slot := native_video.data.event_handler('wheel') or { panic('Parsed raw media slot missing') }
	audio_slot := native_audio.data.event_handler('wheel') or { panic('Created raw media slot missing') }
	video_listener := video_slot.listener or { panic('Parsed raw media listener missing') }
	assert video_slot.value.kind == .string && video_slot.value.string_data == body
	assert audio_slot.value.kind == .string && audio_slot.value.string_data == body
	assert runtime.evaluate_host('globalThis.mrFirst=mrVideo.onwheel;globalThis.mrCreated=mrAudio.onwheel;typeof mrFirst==="function"&&typeof mrCreated==="function"&&mrFirst!==mrCreated&&mrFirst.name==="onwheel"&&mrFirst.length===1&&mrCreated.name==="onwheel"&&mrCreated.length===1&&mrVideo.onwheel===mrFirst&&mrAudio.onwheel===mrCreated&&mrRuns===0&&!Object.hasOwn(mrVideo,"onwheel")&&!Object.hasOwn(mrAudio,"onwheel")')! == 'true'
	callback := native_video.get_current_value_of_event_handler('wheel') or { panic('Parsed media callback missing') }
	created_callback := native_audio.get_current_value_of_event_handler('wheel') or { panic('Created media callback missing') }
	assert callback.compiled_source_text_ == 'function onwheel(event) {\n${body}\n}'
	assert created_callback.compiled_source_text_ == callback.compiled_source_text_
	assert runtime.javascript_event_handler(native_video, 'wheel')! == runtime.evaluate_host_value('mrFirst')!
	assert runtime.javascript_event_handler(native_audio, 'wheel')! == runtime.evaluate_host_value('mrCreated')!
	assert voidptr(video_slot.listener or { panic('Cached raw listener missing') }) == voidptr(video_listener)
	observation := &MediaWheelRawHandlerOwnerObservation{}
	media_wheel_raw_handler_owner_observe(video, scroller, observation)
	app.handle_event(&gg.Event{
		typ: .mouse_scroll
		mouse_x: 12.5
		mouse_y: 12.25 + app.page_top()
		scroll_y: -1
		window_height: 240 + app.chrome_height()
	})
	assert observation.events.len == 1 && observation.targets[0] == voidptr(video)
	assert scroller.el_scroll_offset().y() == 0 && app.scroll_y == 0
	assert runtime.evaluate_host('mrRuns===1&&mrScopeValues.join(",")==="parsed element,document,global"&&mrForm.scopeKey==="nearest form"&&mrAfterStates[0]&&mrSaved[0].deltaY===42&&mrSaved[0].defaultPrevented&&mrChecks.every(Boolean)&&mrVideo.onwheel===mrFirst')! == 'true'
	assert document.get_element_by_id('mr-result')?.text_content()? == 'raw media wheel painted'
	assert video.get_attribute_value('style').contains('color')
	assert app.paint_commands.filter(it.kind == 'draw_text' && it.text == 'raw media wheel painted').len > 0
	media_wheel_raw_handler_owner_event(mut runtime, observation.events[0], 'mrSaved[0]', true)!
	// A cached function retains the actual object environments while reading
	// their current properties. Media has no form environment, even in a form.
	assert runtime.evaluate_host('mrScopeValues=[];mrCurrent=mrAudio;mrTrusted=false;mrAudio.scopeKey="created element";document.scopeKey="live document";globalThis.scopeKey="live global";mrAudio.dispatchEvent(new WheelEvent("wheel",{cancelable:true,view:window}))===false&&mrRuns===2&&mrScopeValues.join(",")==="created element,live document,live global"&&mrChecks.every(Boolean)&&mrAudio.onwheel===mrCreated&&mrForm.scopeKey==="nearest form"')! == 'true'
	created_event := runtime.native_event(runtime.evaluate_host_value('mrSaved[1]')!)!
	media_wheel_raw_handler_owner_event(mut runtime, created_event, 'mrSaved[1]', false)!
	app.poll_javascript_tasks()
	assert audio.get_attribute_value('style').contains('color')
	// Deactivation lets the same software route perform its normal inner scroll.
	assert runtime.evaluate_host('mrVideo.onwheel=null;mrVideo.onwheel===null')! == 'true'
	assert app.handle_wheel_at_viewport_point(page.PixelPoint{12.5, 12.25}, page.PixelPoint{},
		0, 0, 0, 0, 2.5, false) == .handled
	assert scroller.el_scroll_offset().y() == 2.5 && app.scroll_y == 0
	assert observation.events.len == 2 && !observation.events[1].default_prevented()
	assert runtime.evaluate_host('mrRuns===2&&!mrAfterStates[1]&&mrChecks.every(Boolean)&&window.event===undefined')! == 'true'
	assert app.js_messages == []
	media_wheel_raw_handler_owner_balance(runtime, document, 0)
}

fn test_media_raw_onwheel_equal_attribute_idl_and_mutation_removal_keep_native_listener_order() {
	$if !darwin { return }
	body := r'globalThis.mrRuns++;mrOrder.push("raw");mrSaved.push(event);return false;'
	markup := media_wheel_raw_handler_owner_markup.replace('<video id="mr-video">',
		'<video id="mr-video" onwheel="${body.replace('"', '&quot;')}">')
	mut app, mut document, mut runtime := media_wheel_raw_handler_owner_fixture(markup, r'
globalThis.mrVideo=document.getElementById("mr-video");globalThis.mrRuns=0;globalThis.mrOrder=[];globalThis.mrSaved=[];globalThis.mrAfterStates=[];globalThis.mrSource=mrVideo.getAttribute("onwheel");globalThis.mrFirst=mrVideo.onwheel;
mrVideo.addEventListener("wheel",function(event){mrOrder.push("after");mrAfterStates.push(event.defaultPrevented);document.getElementById("mr-result").textContent=mrOrder.join(",")});0
')!
	defer {
		runtime.close()
		document.finalize()
	}
	video := document.get_element_by_id('mr-video')?
	native_video := unsafe { &dom.EventTarget(video) }
	slot := native_video.data.event_handler('wheel') or { panic('Raw media slot missing') }
	listener := slot.listener or { panic('Raw media listener missing') }
	first := native_video.get_current_value_of_event_handler('wheel') or { panic('First raw callback missing') }
	assert first.compiled_source_text_ == 'function onwheel(event) {\n${body}\n}'
	assert runtime.evaluate_host(r'
globalThis.mrIDL=function(event){mrOrder.push("idl");mrSaved.push(event);return false};mrVideo.onwheel=mrIDL;mrVideo.setAttribute("onwheel",mrSource);globalThis.mrSecond=mrVideo.onwheel;
typeof mrSecond==="function"&&mrSecond!==mrFirst&&mrSecond!==mrIDL&&mrSecond.name==="onwheel"&&mrSecond.length===1&&mrVideo.onwheel===mrSecond&&mrRuns===0
')! == 'true'
	assert voidptr(native_video.data.event_handler('wheel') or { panic('Replacement slot missing') }) == voidptr(slot)
	assert voidptr(slot.listener or { panic('Replacement listener missing') }) == voidptr(listener)
	second := native_video.get_current_value_of_event_handler('wheel') or { panic('Second raw callback missing') }
	assert voidptr(second) != voidptr(first) && second.compiled_source_text_ == first.compiled_source_text_
	assert runtime.javascript_event_handler(native_video, 'wheel')! == runtime.evaluate_host_value('mrSecond')!
	event := media_wheel_raw_handler_owner_platform_event(document)
	assert !dom.event_target_dispatch_event(native_video, event)
	assert runtime.evaluate_host('mrRuns===1&&mrOrder.join(",")==="raw,after"&&mrAfterStates[0]&&mrSaved[0].defaultPrevented')! == 'true'
	media_wheel_raw_handler_owner_event(mut runtime, event, 'mrSaved[0]', true)!
	assert runtime.evaluate_host('mrVideo.onwheel=mrIDL;mrVideo.removeAttribute("onwheel");mrVideo.onwheel===null')! == 'true'
	assert !native_video.data.has_event_handler('wheel') && video.get_attribute('onwheel') == none
	assert runtime.evaluate_host('mrVideo.onwheel=mrIDL;mrVideo.removeAttribute("onwheel");mrOrder=[];mrVideo.onwheel===mrIDL')! == 'true'
	event2 := media_wheel_raw_handler_owner_platform_event(document)
	assert !dom.event_target_dispatch_event(native_video, event2)
	assert runtime.evaluate_host('mrRuns===1&&mrOrder.join(",")==="after,idl"&&!mrAfterStates[1]&&mrSaved[1].defaultPrevented')! == 'true'
	media_wheel_raw_handler_owner_event(mut runtime, event2, 'mrSaved[1]', true)!
	// Replacing itself during dispatch affects the next event and retains its
	// existing position after the later listener, rather than adding a listener.
	self_body := r'mrOrder.push("self");this.onwheel=mrIDL;return false;'
	mut mutable_video := unsafe { &dom.Element(video) }
	mutable_video.set_attribute_value('onwheel', self_body)
	assert !dom.event_target_dispatch_event(native_video, media_wheel_raw_handler_owner_platform_event(document))
	assert runtime.evaluate_host('mrOrder.slice(-2).join(",")==="after,self"&&mrVideo.onwheel===mrIDL')! == 'true'
	assert !dom.event_target_dispatch_event(native_video, media_wheel_raw_handler_owner_platform_event(document))
	assert runtime.evaluate_host('mrOrder.slice(-2).join(",")==="after,idl"&&mrRuns===1')! == 'true'
	assert native_video.event_listener_list().len == 2
	app.poll_javascript_tasks()
	assert document.get_element_by_id('mr-result')?.text_content()? == runtime.evaluate_host('mrOrder.slice(0,-1).join(",")')!
	assert app.js_messages == []
	media_wheel_raw_handler_owner_balance(runtime, document, 0)
}

fn test_media_raw_onwheel_body_gate_csp_strict_exception_and_page_scripting_gate() {
	$if !darwin { return }
	mut app, mut document, mut runtime := media_wheel_raw_handler_owner_fixture(media_wheel_raw_handler_owner_markup,
		r'globalThis.mrVideo=document.getElementById("mr-video");globalThis.mrRuns=0;globalThis.mrInjectionRuns=0;globalThis.mrChecks=[];globalThis.mrSaved=[];globalThis.mrThrowReason={original:true};mrVideo.event={elementSentinel:true};document.event={documentSentinel:true};0')!
	defer {
		runtime.close()
		document.finalize()
	}
	media_wheel_raw_handler_owner_probe(mut runtime, document)!
	mut video := document.get_element_by_id('mr-video')?
	native_video := unsafe { &dom.EventTarget(video) }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	for body in ['return (', '"use strict";let event;', '"use strict";with({}){};',
		'}},globalThis.mrInjectionRuns++,{onwheel:function(event){'] {
		video.set_attribute_value('onwheel', body)
		slot := native_video.data.event_handler('wheel') or { panic('Invalid raw media slot missing') }
		listener := slot.listener or { panic('Invalid raw media listener missing') }
		assert slot.value.kind == .string && slot.value.string_data == body
		assert runtime.evaluate_host('mrVideo.onwheel===null&&mrVideo.onwheel===null&&mrRuns===0&&mrInjectionRuns===0')! == 'true'
		assert slot.value.kind == .null_
		assert voidptr(slot.listener or { panic('Invalid raw media listener removed') }) == voidptr(listener)
		assert video.get_attribute_value('onwheel') == body
		media_wheel_raw_handler_owner_balance(runtime, document, 0)
	}
	video.set_attribute_value('onwheel', 'return false;')
	valid := native_video.get_current_value_of_event_handler('wheel') or { panic('Valid raw media callback missing') }
	actual_valid := runtime.javascript_event_handler(native_video, 'wheel')!
	document.set_csp_hook(dom.DocumentCSPHook{
		inline_check: fn (_ voidptr, _ &dom.Element, type_ string, _ string) bool { return type_ == 'script-attribute' }
	})
	video.set_attribute_value('onwheel', 'return (')
	assert video.get_attribute_value('onwheel') == 'return ('
	assert voidptr(native_video.get_current_value_of_event_handler('wheel') or { panic('CSP replaced media callback') }) == voidptr(valid)
	assert runtime.javascript_event_handler(native_video, 'wheel')! == actual_valid
	document.set_csp_hook(dom.DocumentCSPHook{
		inline_check: fn (_ voidptr, _ &dom.Element, _ string, _ string) bool { return false }
	})
	body := r'"use strict";mrRuns++;mrSaved.push(event);mrChecks.push(arguments.length===1&&event===arguments[0]&&this===mrVideo&&event.target===mrVideo&&event.currentTarget===mrVideo&&event instanceof WheelEvent&&event.isTrusted&&window.event===event&&__mediaWheelRawHandlerOwnerContext());try{void arguments.callee;mrChecks.push(false)}catch(error){mrChecks.push(error instanceof TypeError)}this.onwheel=null;globalThis.mrLiveName=onwheel;throw mrThrowReason;'
	video.set_attribute_value('onwheel', body)
	slot := native_video.data.event_handler('wheel') or { panic('Strict raw media slot missing') }
	mut owner := app.page_model
	owner.set_is_scripting_enabled(false)
	assert runtime.evaluate_host('mrVideo.onwheel===null&&mrRuns===0')! == 'true'
	assert slot.value.kind == .string && slot.value.string_data == body
	assert dom.event_target_dispatch_event(native_video, media_wheel_raw_handler_owner_platform_event(document))
	assert slot.value.kind == .string && runtime.evaluate_host('mrRuns===0&&mrSaved.length===0')! == 'true'
	owner.set_is_scripting_enabled(true)
	assert runtime.evaluate_host('globalThis.mrStrict=mrVideo.onwheel;typeof mrStrict==="function"&&mrStrict.name==="onwheel"&&mrStrict.length===1&&mrVideo.onwheel===mrStrict&&mrRuns===0')! == 'true'
	strict_callback := native_video.get_current_value_of_event_handler('wheel') or { panic('Strict media callback missing') }
	assert strict_callback.compiled_source_text_ == 'function onwheel(event) {\n${body}\n}'
	assert runtime.javascript_event_handler(native_video, 'wheel')! == runtime.evaluate_host_value('mrStrict')!
	assert runtime.evaluate_host('mrVideo.addEventListener("wheel",function(event){globalThis.mrLaterRan=this===mrVideo&&event.currentTarget===mrVideo&&!event.defaultPrevented&&window.event===event;document.getElementById("mr-result").textContent="later media listener"});true')! == 'true'
	event := media_wheel_raw_handler_owner_platform_event(document)
	assert dom.event_target_dispatch_event(native_video, event)
	assert runtime.evaluate_host('mrRuns===1&&mrChecks.every(Boolean)&&mrLiveName===null&&mrVideo.onwheel===null&&mrLaterRan&&mrInjectionRuns===0')! == 'true'
	assert !native_video.data.has_event_handler('wheel') && !event.default_prevented()
	assert video.get_attribute_value('onwheel') == body
	assert settings.realm().reported_exceptions.len == 1
	reported := settings.realm().reported_exceptions[0].value.as_webidl_value()!
	assert runtime.actual_webidl_value(reported)! == runtime.evaluate_host_value('mrThrowReason')!
	media_wheel_raw_handler_owner_event(mut runtime, event, 'mrSaved[0]', true)!
	app.poll_javascript_tasks()
	assert document.get_element_by_id('mr-result')?.text_content()? == 'later media listener'
	assert app.js_messages == []
	media_wheel_raw_handler_owner_balance(runtime, document, 1)
}

