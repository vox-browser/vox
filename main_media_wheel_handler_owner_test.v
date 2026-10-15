module main

import browserjs
import dom
import html
import page
import time

fn media_wheel_handler_document(markup string, address string) !(&page.Page, &dom.Document) {
	mut owner := page.Page.create(1)!
	owner.set_enable_autoscroll(false)
	document := parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: address
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	return owner, document
}

fn media_wheel_handler_guard(runtime &browserjs.Runtime) !bool {
	// Inspect the native descriptor without invoking the getter: a parsed raw
	// attribute must remain uncompiled until the test explicitly reads or fires it.
	return runtime.evaluate_host(r'(()=>{const d=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,"onwheel");return !!d&&d.get.name==="get onwheel"&&d.set.name==="set onwheel"&&d.get.length===0&&d.set.length===1&&[d.get,d.set].every(callback=>Function.prototype.toString.call(callback).includes("[native code]"))&&[video,mediaWheelAudio].every(player=>!Object.hasOwn(player,"onwheel"))})()')! == 'true'
}

fn media_wheel_handler_app(owner &page.Page, document &dom.Document, runtime &browserjs.Runtime) BrowserApp {
	return BrowserApp{
		page_model:       owner
		document:         document
		js_runtime:       runtime
		layout_tree_only: true
		viewport_width:   320
		viewport_height:  200
	}
}

fn media_wheel_handler_probe(mut runtime browserjs.Runtime, document &dom.Document) ! {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	owner_handle := voidptr(&runtime)
	actual_true := runtime.evaluate_host_value('true')!
	runtime.define_value_host_function('__mediaWheelHandlerContext', fn [settings, owner_handle, actual_true] (_ voidptr, arguments []voidptr) !voidptr {
		owner := unsafe { &browserjs.Runtime(owner_handle) }
		assert arguments.len == 0
		assert settings.realm().script_execution_depth > 0
		assert settings.realm().callback_execution_depth > 0
		assert owner.libjs_vm().has_running_execution_context()
		assert voidptr(html.current_principal_settings_object()) == voidptr(settings)
		assert voidptr(html.incumbent_settings_object()) == voidptr(settings)
		return actual_true
	})!
}

fn media_wheel_handler_event(document &dom.Document) &dom.Event {
	wheel := dom.WheelEvent.create_from_platform_event(voidptr(document.get_window() or {
		panic('Media wheel owner needs its Window')
	}), 'wheel', dom.CSSPixelPoint_{111.25, 221.75}, dom.CSSPixelPoint_{31.5, 41.125},
		dom.CSSPixelPoint_{11.5, 21.125}, dom.CSSPixelPoint_{1.75, 2.625}, 2.5, -3.6, 2, 2,
		dom.modifier_ctrl | dom.modifier_shift | dom.modifier_alt | dom.modifier_super)
	return unsafe { &dom.Event(wheel) }
}

fn media_wheel_handler_balance(runtime &browserjs.Runtime, document &dom.Document, exceptions int) {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == exceptions
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 0
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

// Page's current wheel route retains routing metadata without delivering a DOM
// WheelEvent. Use the existing platform factory and actual owner dispatcher;
// this does not claim Cocoa/Page wheel production or default scrolling.
fn test_media_wheel_handler_receives_actual_platform_deltas_and_same_wrapper_redispatch() {
	$if !darwin { return }
	mut owner, mut document := media_wheel_handler_document('<video id="video"></video><div id="result">waiting</div>',
		'https://media-wheel-handler-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.mediaWheelAudio=document.createElement("audio");mediaWheelAudio.id="media-wheel-audio";0',
	], runtime, mut messages)
	assert messages == []
	assert media_wheel_handler_guard(runtime)!
	media_wheel_handler_probe(mut runtime, document)!
	assert document.get_element_by_id('media-wheel-audio') == none
	created := runtime.native_event_target(runtime.evaluate_host_value('mediaWheelAudio')!)!
	runtime.evaluate_host(r'
globalThis.mediaWheelOrder=[];globalThis.mediaWheelChecks=[];globalThis.mediaWheelSaved=[];globalThis.mediaWheelTrusted=true;globalThis.mediaWheelReturn=0;
for(const player of [video,mediaWheelAudio]){
 player.addEventListener("wheel",function(event){mediaWheelOrder.push(player.id+":before");mediaWheelChecks.push(this===player&&event.target===player&&event.currentTarget===player&&!event.defaultPrevented&&window.event===event)});
 player.onwheel=function(){mediaWheelOrder.push("obsolete")};
 player.addEventListener("wheel",function(event){mediaWheelOrder.push(player.id+":after");mediaWheelChecks.push(this===player&&event.currentTarget===player&&event.defaultPrevented===(mediaWheelReturn===false)&&window.event===event);result.textContent=mediaWheelOrder.join(",")});
 const replacement=function(event){mediaWheelOrder.push(player.id+":handler");mediaWheelSaved.push(event);mediaWheelChecks.push(arguments.length===1&&this===player&&event.type==="wheel"&&event instanceof WheelEvent&&event instanceof MouseEvent&&event instanceof UIEvent&&event instanceof Event&&!(event instanceof PointerEvent)&&Object.getPrototypeOf(event)===WheelEvent.prototype&&event.isTrusted===mediaWheelTrusted&&event.bubbles&&event.cancelable&&event.composed&&event.view===window&&event.detail===0&&event.button===2&&event.buttons===2&&event.which===3&&event.relatedTarget===null&&event.target===player&&event.currentTarget===player&&window.event===event&&event.deltaX===2.5&&event.deltaY===-3.6&&event.deltaZ===0&&event.deltaMode===WheelEvent.DOM_DELTA_PIXEL&&event.wheelDeltaX===-2&&event.wheelDeltaY===4&&event.wheelDelta===4&&event.ctrlKey&&event.shiftKey&&event.altKey&&event.metaKey&&__mediaWheelHandlerContext());return mediaWheelReturn};player.onwheel=replacement;mediaWheelChecks.push(player.onwheel===replacement&&!Object.hasOwn(player,"onwheel"));
}
document.body.appendChild(mediaWheelAudio);void mediaWheelAudio.paused;0
')!
	assert voidptr(document.get_element_by_id('media-wheel-audio')?) == voidptr(created)
	mut app := media_wheel_handler_app(owner, document, runtime)
	mut deliveries := 0
	for id in ['video', 'media-wheel-audio'] {
		target := document.get_element_by_id(id)?
		other := if id == 'video' { 'mediaWheelAudio' } else { 'video' }
		runtime.evaluate_host('mediaWheelOrder=[];mediaWheelTrusted=true;mediaWheelReturn=0;0')!
		event := media_wheel_handler_event(document)
		stamp := event.time_stamp()
		assert dom.event_target_dispatch_event(unsafe { &dom.EventTarget(target) }, event)
		wrapper := runtime.evaluate_host_value('mediaWheelSaved[${deliveries}]')!
		assert voidptr(runtime.native_event(wrapper)!) == voidptr(event)
		assert runtime.javascript_event(event)! == wrapper
		assert event.interface_ == .wheel_event && event.is_trusted() && !event.default_prevented()
		assert voidptr(event.target()?) == voidptr(target)
		wheel := unsafe { &dom.WheelEvent(event) }
		assert wheel.delta_x() == 2.5 && wheel.delta_y() == -3.6 && wheel.delta_mode() == 0
		assert wheel.wheel_delta_x() == -2 && wheel.wheel_delta_y() == 4 && wheel.wheel_delta() == 4
		assert runtime.evaluate_host('mediaWheelOrder.join(",")==="${id}:before,${id}:handler,${id}:after"&&mediaWheelChecks.every(Boolean)&&mediaWheelSaved[${deliveries}].clientX===11.5&&mediaWheelSaved[${deliveries}].pageX===31.5&&mediaWheelSaved[${deliveries}].currentTarget===null&&window.event===undefined')! == 'true'
		app.poll_javascript_tasks()
		assert document.get_element_by_id('result')?.text_content()? == '${id}:before,${id}:handler,${id}:after'
		assert !app.dispatch_javascript_event('wheel', target)
		deliveries++
		assert runtime.evaluate_host('(()=>{mediaWheelTrusted=false;mediaWheelReturn=false;const event=mediaWheelSaved[${deliveries - 1}],stamp=event.timeStamp;return ${other}.dispatchEvent(event)===false&&mediaWheelSaved[${deliveries}]===event&&!event.isTrusted&&event.defaultPrevented&&event.timeStamp===stamp&&event.clientX===11&&event.pageX===31&&event.offsetX===1&&event.currentTarget===null&&event.eventPhase===Event.NONE&&window.event===undefined&&mediaWheelChecks.every(Boolean)})()')! == 'true'
		assert voidptr(runtime.native_event(runtime.evaluate_host_value('mediaWheelSaved[${deliveries}]')!)!) == voidptr(event)
		assert event.time_stamp() == stamp && !event.is_trusted() && event.default_prevented()
		other_target := document.get_element_by_id(if id == 'video' { 'media-wheel-audio' } else { 'video' })?
		assert voidptr(event.target()?) == voidptr(other_target)
		assert wheel.delta_x() == 2.5 && wheel.delta_y() == -3.6 && wheel.wheel_delta() == 4
		app.poll_javascript_tasks()
		assert !app.dispatch_javascript_event('wheel', other_target)
		deliveries++
	}
	assert deliveries == 4
	assert runtime.evaluate_host('mediaWheelSaved.length===4&&mediaWheelChecks.every(Boolean)&&mediaWheelSaved.every(event=>event.currentTarget===null&&event.eventPhase===Event.NONE)&&window.event===undefined')! == 'true'
	assert app.js_messages == []
	media_wheel_handler_balance(runtime, document, 0)
}

fn test_media_wheel_raw_source_and_self_replacement_preserve_native_slot_order() {
	$if !darwin { return }
	raw_source := 'globalThis.rawMediaWheelRuns++'
	mut owner, mut document := media_wheel_handler_document('<video id="video" onwheel="${raw_source}"></video><div id="result">waiting</div>',
		'https://media-wheel-slot-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.mediaWheelAudio=document.createElement("audio");mediaWheelAudio.id="media-wheel-audio";globalThis.rawMediaWheelRuns=0;0',
	], runtime, mut messages)
	assert messages == []
	assert media_wheel_handler_guard(runtime)!
	media_wheel_handler_probe(mut runtime, document)!
	video := document.get_element_by_id('video')?
	video_target := runtime.native_event_target(runtime.evaluate_host_value('video')!)!
	raw_handler := video_target.data.event_handler('wheel') or {
		assert false, 'Missing raw media wheel handler'
		return
	}
	assert raw_handler.value.kind == .string && raw_handler.value.string_data == raw_source
	assert dom.event_target_dispatch_event(video_target, media_wheel_handler_event(document))
	assert runtime.evaluate_host('globalThis.mediaWheelCompiled=video.onwheel;typeof mediaWheelCompiled==="function"&&mediaWheelCompiled.name==="onwheel"&&mediaWheelCompiled.length===1&&video.onwheel===mediaWheelCompiled&&rawMediaWheelRuns===1')! == 'true'
	assert raw_handler.value.kind == .object
	compiled := video_target.get_current_value_of_event_handler('wheel') or { panic('Raw media wheel callback missing') }
	assert compiled.compiled_source_text_ == 'function onwheel(event) {\n${raw_source}\n}'
	runtime.evaluate_host(r'
globalThis.mediaWheelSlotOrder=[];globalThis.mediaWheelSlotChecks=[];globalThis.mediaWheelRawCalls=0;globalThis.mediaWheelObjectReads=0;
video.onwheel=function(event){mediaWheelRawCalls++;mediaWheelSlotChecks.push(this===video&&event instanceof WheelEvent&&event.isTrusted&&event.target===video&&event.currentTarget===video&&window.event===event&&__mediaWheelHandlerContext());return false};
mediaWheelAudio.addEventListener("wheel",function(event){mediaWheelSlotOrder.push("before");mediaWheelSlotChecks.push(this===mediaWheelAudio&&event.isTrusted&&window.event===event)});
globalThis.mediaWheelNext=function(event){mediaWheelSlotOrder.push("next");mediaWheelSlotChecks.push(this===mediaWheelAudio&&event.target===mediaWheelAudio&&event.currentTarget===mediaWheelAudio&&event.isTrusted&&window.event===event&&__mediaWheelHandlerContext());this.onwheel=null};
mediaWheelAudio.onwheel=function(event){mediaWheelSlotOrder.push("first");mediaWheelSlotChecks.push(this===mediaWheelAudio&&event.isTrusted&&window.event===event&&__mediaWheelHandlerContext());this.onwheel=mediaWheelNext};
mediaWheelAudio.addEventListener("wheel",function(event){mediaWheelSlotOrder.push("after");mediaWheelSlotChecks.push(this===mediaWheelAudio&&event.isTrusted&&window.event===event);result.textContent=mediaWheelSlotOrder.join(",")});
document.body.appendChild(mediaWheelAudio);void mediaWheelAudio.paused;0
')!
	assigned := video_target.data.event_handler('wheel') or {
		assert false, 'Missing assigned media wheel handler'
		return
	}
	assert voidptr(assigned) == voidptr(raw_handler) && assigned.value.kind == .object
	assert !dom.event_target_dispatch_event(video_target, media_wheel_handler_event(document))
	assert video.get_attribute('onwheel')? == raw_source
	assert runtime.evaluate_host('video.onwheel=null;video.onwheel===null&&mediaWheelRawCalls===1&&rawMediaWheelRuns===1')! == 'true'
	assert !video_target.data.has_event_handler('wheel') && video_target.event_listener_list().len == 0
	assert video.get_attribute('onwheel')? == raw_source
	audio_target := runtime.native_event_target(runtime.evaluate_host_value('mediaWheelAudio')!)!
	assert voidptr(audio_target) == voidptr(document.get_element_by_id('media-wheel-audio')?)
	for _ in 0 .. 3 {
		assert dom.event_target_dispatch_event(audio_target, media_wheel_handler_event(document))
	}
	assert runtime.evaluate_host('mediaWheelSlotOrder.join(",")==="before,first,after,before,next,after,before,after"&&mediaWheelAudio.onwheel===null&&mediaWheelSlotChecks.every(Boolean)')! == 'true'
	assert audio_target.event_listener_list().len == 2
	runtime.evaluate_host(r'globalThis.mediaWheelReactivated=function(event){mediaWheelSlotOrder.push("reactivated");mediaWheelSlotChecks.push(this===mediaWheelAudio&&event.isTrusted&&window.event===event&&__mediaWheelHandlerContext());result.textContent=mediaWheelSlotOrder.join(",");return 0};mediaWheelAudio.onwheel=mediaWheelReactivated;0')!
	assert dom.event_target_dispatch_event(audio_target, media_wheel_handler_event(document))
	assert runtime.evaluate_host('mediaWheelSlotOrder.join(",")==="before,first,after,before,next,after,before,after,before,after,reactivated"&&mediaWheelAudio.onwheel===mediaWheelReactivated&&!Object.hasOwn(mediaWheelAudio,"onwheel")')! == 'true'
	runtime.evaluate_host(r'globalThis.mediaWheelLegacyObject={get handleEvent(){mediaWheelObjectReads++;throw "handleEvent"},[Symbol.toPrimitive](){mediaWheelObjectReads++;throw "conversion"}};mediaWheelAudio.onwheel=mediaWheelLegacyObject;0')!
	assert dom.event_target_dispatch_event(audio_target, media_wheel_handler_event(document))
	assert runtime.evaluate_host('mediaWheelAudio.onwheel===mediaWheelLegacyObject&&mediaWheelObjectReads===0&&mediaWheelSlotOrder.slice(-2).join(",")==="before,after"&&mediaWheelSlotChecks.every(Boolean)&&window.event===undefined')! == 'true'
	for value in ['null', 'undefined', 'false', '0', '"return false"', 'Symbol("handler")', '1n'] {
		assert runtime.evaluate_host('mediaWheelAudio.onwheel=${value};mediaWheelAudio.onwheel===null')! == 'true'
	}
	assert audio_target.event_listener_list().len == 2
	mut app := media_wheel_handler_app(owner, document, runtime)
	app.poll_javascript_tasks()
	assert video.get_attribute('onwheel')? == raw_source
	assert document.get_element_by_id('result')?.text_content()? == runtime.evaluate_host('mediaWheelSlotOrder.join(",")')!
	assert app.js_messages == []
	media_wheel_handler_balance(runtime, document, 0)
}

fn test_media_wheel_handler_page_gate_exception_and_close_preserve_owner_lifecycle() {
	$if !darwin { return }
	mut owner, mut document := media_wheel_handler_document('<video id="video"></video><div id="result">waiting</div>',
		'https://media-wheel-lifecycle-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.mediaWheelAudio=document.createElement("audio");mediaWheelAudio.id="media-wheel-audio";0',
	], runtime, mut messages)
	assert messages == []
	assert media_wheel_handler_guard(runtime)!
	media_wheel_handler_probe(mut runtime, document)!
	runtime.evaluate_host(r'
globalThis.mediaWheelLifecycleOrder=[];globalThis.mediaWheelLifecycleChecks=[];globalThis.mediaWheelLifecycleSaved=[];globalThis.mediaWheelThrowReason={original:true};
for(const player of [video,mediaWheelAudio]){
 player.onwheel=function(event){mediaWheelLifecycleOrder.push(player.id+":handler");mediaWheelLifecycleSaved.push(event);mediaWheelLifecycleChecks.push(arguments.length===1&&this===player&&event instanceof WheelEvent&&event.isTrusted&&event.deltaX===2.5&&event.deltaY===-3.6&&event.deltaMode===0&&event.target===player&&event.currentTarget===player&&window.event===event&&__mediaWheelHandlerContext());result.textContent=player.id+":before completion";if(player===video)throw mediaWheelThrowReason;return false};
 player.addEventListener("wheel",function(event){mediaWheelLifecycleOrder.push(player.id+":later");mediaWheelLifecycleChecks.push(this===player&&event.target===player&&event.currentTarget===player&&event.defaultPrevented===(player===mediaWheelAudio)&&window.event===event&&__mediaWheelHandlerContext());result.textContent=player.id+":later listener"});
}
document.body.appendChild(mediaWheelAudio);void mediaWheelAudio.paused;0
')!
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	owner.set_is_scripting_enabled(false)
	for id in ['video', 'media-wheel-audio'] {
		event := media_wheel_handler_event(document)
		assert dom.event_target_dispatch_event(unsafe { &dom.EventTarget(document.get_element_by_id(id)?) }, event)
		assert !event.default_prevented()
	}
	assert runtime.evaluate_host('mediaWheelLifecycleOrder.length===0&&mediaWheelLifecycleSaved.length===0&&window.event===undefined')! == 'true'
	media_wheel_handler_balance(runtime, document, 0)
	owner.set_is_scripting_enabled(true)
	mut app := media_wheel_handler_app(owner, document, runtime)
	for index, id in ['video', 'media-wheel-audio'] {
		target := document.get_element_by_id(id)?
		event := media_wheel_handler_event(document)
		assert dom.event_target_dispatch_event(unsafe { &dom.EventTarget(target) }, event) == (index == 0)
		assert event.default_prevented() == (index == 1)
		wrapper := runtime.evaluate_host_value('mediaWheelLifecycleSaved[${index}]')!
		assert voidptr(runtime.native_event(wrapper)!) == voidptr(event)
		assert runtime.javascript_event(event)! == wrapper
		assert voidptr(event.target()?) == voidptr(target)
		assert settings.realm().reported_exceptions.len == 1
		assert runtime.actual_webidl_value(settings.realm().reported_exceptions[0].value.as_webidl_value()!)! == runtime.evaluate_host_value('mediaWheelThrowReason')!
		assert runtime.evaluate_host('mediaWheelLifecycleChecks.every(Boolean)&&mediaWheelLifecycleSaved[${index}].currentTarget===null&&window.event===undefined')! == 'true'
		app.poll_javascript_tasks()
		assert document.get_element_by_id('result')?.text_content()? == '${id}:later listener'
		assert !app.dispatch_javascript_event('wheel', target)
		media_wheel_handler_balance(runtime, document, 1)
	}
	assert runtime.evaluate_host('mediaWheelLifecycleOrder.join(",")==="video:handler,video:later,media-wheel-audio:handler,media-wheel-audio:later"&&mediaWheelLifecycleSaved.length===2&&mediaWheelLifecycleChecks.every(Boolean)&&window.event===undefined')! == 'true'
	assert app.js_messages == []
	runtime.close()
	for id in ['video', 'media-wheel-audio'] {
		event := media_wheel_handler_event(document)
		assert dom.event_target_dispatch_event(unsafe { &dom.EventTarget(document.get_element_by_id(id)?) }, event)
		assert !event.default_prevented()
		assert event.current_target() == none
	}
	media_wheel_handler_balance(runtime, document, 1)
}
