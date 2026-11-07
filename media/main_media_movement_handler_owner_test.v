module main

import browserjs
import dom
import html
import page
import time

fn media_movement_handler_document(address string) !(&page.Page, &dom.Document) {
	mut owner := page.Page.create(1)!
	owner.set_enable_autoscroll(false)
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="video"></video><div id="result">waiting</div>', dom.URL{
		value: address
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	return owner, document
}

fn media_movement_handler_guard(runtime &browserjs.Runtime) !bool {
	return runtime.evaluate_host(r'["onpointermove","onmousemove"].every(name=>{const descriptor=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,name);return !!descriptor&&typeof descriptor.get==="function"&&typeof descriptor.set==="function"&&[video,movementAudio].every(player=>player[name]===null&&!Object.hasOwn(player,name))})')! == 'true'
}

fn media_movement_handler_app(owner &page.Page, document &dom.Document, runtime &browserjs.Runtime) BrowserApp {
	return BrowserApp{
		page_model:       owner
		document:         document
		js_runtime:       runtime
		layout_tree_only: true
		viewport_width:   320
		viewport_height:  200
	}
}

fn test_media_movement_uses_trusted_native_owners_and_returns_compatibility_mouse_cancellation() {
	$if !darwin { return }
	mut owner, mut document :=
		media_movement_handler_document('https://media-movement-order.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.movementAudio=document.createElement("audio");movementAudio.id="movement-audio";0',
	], runtime, mut messages)
	assert messages == []
	assert media_movement_handler_guard(runtime)!
	assert document.get_element_by_id('movement-audio') == none
	created_target := runtime.native_event_target(runtime.evaluate_host_value('movementAudio')!)!
	runtime.evaluate_host(r'
globalThis.moveOwnerOrder=[];globalThis.moveOwnerChecks=[];globalThis.moveOwnerSaved=[];globalThis.cancelPointerMove=true;globalThis.cancelMouseMove=false;
for(const player of [video,movementAudio])for(const type of ["pointermove","mousemove"]){
 player.addEventListener(type,function(event){moveOwnerOrder.push(type+":before");moveOwnerChecks.push(this===player&&event.target===player&&event.currentTarget===player&&event.isTrusted&&!event.defaultPrevented&&window.event===event)});
 player["on"+type]=function(){moveOwnerOrder.push("obsolete")};
 player.addEventListener(type,function(event){moveOwnerOrder.push(type+":after");moveOwnerChecks.push(this===player&&event.target===player&&event.currentTarget===player&&event.isTrusted&&event.defaultPrevented===(type==="pointermove"?cancelPointerMove:cancelMouseMove)&&window.event===event);result.textContent=moveOwnerOrder.join(",")});
 const replacement=function(event){moveOwnerOrder.push(type+":handler");moveOwnerSaved.push(event);moveOwnerChecks.push(this===player&&arguments.length===1&&event.type===type&&event instanceof Event&&event.isTrusted&&event.bubbles&&event.cancelable&&event.target===player&&event.currentTarget===player&&window.event===event);return(type==="pointermove"?cancelPointerMove:cancelMouseMove)?false:0};player["on"+type]=replacement;moveOwnerChecks.push(player["on"+type]===replacement&&!Object.hasOwn(player,"on"+type));
}
document.body.appendChild(movementAudio);void movementAudio.paused;
')!
	assert voidptr(document.get_element_by_id('movement-audio')?) == voidptr(created_target)
	mut app := media_movement_handler_app(owner, document, runtime)
	for id in ['video', 'movement-audio'] {
		target := document.get_element_by_id(id)?
		input := page.InputTarget.from_node(target.as_node())
		runtime.evaluate_host('moveOwnerOrder=[];moveOwnerSaved=[];cancelPointerMove=true;cancelMouseMove=false;0')!
		assert owner.handle_mousemove(input, page.PixelPoint{10, 10}, 0, 0) == .handled
		assert runtime.evaluate_host('moveOwnerOrder.join(",")==="pointermove:before,pointermove:handler,pointermove:after,mousemove:before,mousemove:handler,mousemove:after"&&moveOwnerSaved.length===2&&moveOwnerSaved[0].defaultPrevented&&!moveOwnerSaved[1].defaultPrevented')! == 'true'
		app.poll_javascript_tasks()
		assert document.get_element_by_id('result')?.as_node().text_content()? == runtime.evaluate_host('moveOwnerOrder.join(",")')!
		runtime.evaluate_host('cancelPointerMove=false;cancelMouseMove=true;0')!
		assert owner.event_handler.handle_platform_pointer_event('pointermove', input, page.PixelPoint{12, 11}, page.PixelPoint{112, 111},
			0, 0, dom.modifier_shift, 0) == .cancelled
		assert runtime.evaluate_host('moveOwnerSaved.length===4&&!moveOwnerSaved[2].defaultPrevented&&moveOwnerSaved[3].defaultPrevented')! == 'true'
		app.poll_javascript_tasks()
		runtime.evaluate_host('cancelPointerMove=false;cancelMouseMove=false;0')!
		assert owner.handle_mousemove(input, page.PixelPoint{14, 12}, 0, 0) == .handled
		assert runtime.evaluate_host('moveOwnerOrder.length===18&&moveOwnerSaved.length===6&&!moveOwnerSaved[4].defaultPrevented&&!moveOwnerSaved[5].defaultPrevented&&moveOwnerSaved.every(event=>event.currentTarget===null&&event.eventPhase===Event.NONE)&&moveOwnerChecks.every(Boolean)&&window.event===undefined')! == 'true'
		app.poll_javascript_tasks()
		assert !app.dispatch_javascript_event('pointermove', target)
		assert !app.dispatch_javascript_event('mousemove', target)
		assert runtime.evaluate_host('moveOwnerOrder.length===18')! == 'true'
	}
	assert app.js_messages == []
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_media_cancelled_pointerdown_suppresses_compatibility_moves_until_release_then_restores() {
	$if !darwin { return }
	mut owner, mut document :=
		media_movement_handler_document('https://media-movement-suppression.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.movementAudio=document.createElement("audio");movementAudio.id="movement-audio";0',
	], runtime, mut messages)
	assert messages == []
	assert media_movement_handler_guard(runtime)!
	runtime.evaluate_host(r'
globalThis.suppressedMoveOrder=[];globalThis.suppressedMoveChecks=[];globalThis.suppressedMoveSaved=[];
for(const player of [video,movementAudio])for(const type of ["pointerdown","mousedown","pointermove","mousemove","pointerup","mouseup","click"]){
 player["on"+type]=function(event){suppressedMoveOrder.push(type);suppressedMoveSaved.push(event);suppressedMoveChecks.push(this===player&&arguments.length===1&&event.type===type&&event instanceof Event&&event.isTrusted&&event.target===player&&event.currentTarget===player&&window.event===event);result.textContent=suppressedMoveOrder.join(",");if(type==="pointerdown")return false};
}
document.body.appendChild(movementAudio);void movementAudio.paused;
')!
	mut app := media_movement_handler_app(owner, document, runtime)
	for id in ['video', 'movement-audio'] {
		target := document.get_element_by_id(id)?
		input := page.InputTarget.from_node(target.as_node())
		runtime.evaluate_host('suppressedMoveOrder=[];suppressedMoveSaved=[];0')!
		assert owner.handle_mousedown(input, page.PixelPoint{10, 10}, 0, 1, 0, 1) == .cancelled
		assert owner.handle_mousemove(input, page.PixelPoint{11, 10}, 0, 1) == .cancelled
		assert owner.event_handler.handle_platform_pointer_event('pointermove', input, page.PixelPoint{12, 10}, page.PixelPoint{112, 110},
			0, 1, 0, 1) == .cancelled
		assert runtime.evaluate_host('suppressedMoveOrder.join(",")==="pointerdown,pointermove,pointermove"&&suppressedMoveSaved[0].defaultPrevented&&suppressedMoveSaved.slice(1).every(event=>!event.defaultPrevented)')! == 'true'
		app.poll_javascript_tasks()
		assert document.get_element_by_id('result')?.as_node().text_content()? == 'pointerdown,pointermove,pointermove'
		assert owner.handle_mouseup(input, page.PixelPoint{12, 10}, 0, 0, 0) == .handled
		assert owner.event_handler.last_click_allowed()
		assert runtime.evaluate_host('suppressedMoveOrder.join(",")==="pointerdown,pointermove,pointermove,pointerup,click"')! == 'true'
		app.poll_javascript_tasks()
		assert !app.dispatch_javascript_event('click', target)
		assert owner.event_handler.take_last_click_event() == none
		assert runtime.evaluate_host('suppressedMoveOrder.length===5')! == 'true'
		assert owner.handle_mousemove(input, page.PixelPoint{13, 11}, 0, 0) == .handled
		app.poll_javascript_tasks()
		assert runtime.evaluate_host('suppressedMoveOrder.join(",")==="pointerdown,pointermove,pointermove,pointerup,click,pointermove,mousemove"&&suppressedMoveSaved.length===7&&suppressedMoveSaved.every(event=>event.currentTarget===null&&event.eventPhase===Event.NONE)&&suppressedMoveChecks.every(Boolean)&&window.event===undefined')! == 'true'
		assert document.get_element_by_id('result')?.as_node().text_content()? == 'pointerdown,pointermove,pointermove,pointerup,click,pointermove,mousemove'
	}
	assert app.js_messages == []
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_media_movement_self_replacement_null_and_throw_replay_dom_without_duplicate_native_click() {
	$if !darwin { return }
	mut owner, mut document :=
		media_movement_handler_document('https://media-movement-mutation.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.movementAudio=document.createElement("audio");movementAudio.id="movement-audio";0',
	], runtime, mut messages)
	assert messages == []
	assert media_movement_handler_guard(runtime)!
	runtime.evaluate_host(r'
globalThis.selfMoveOrder=[];globalThis.selfMoveChecks=[];
movementAudio.addEventListener("pointermove",function(event){selfMoveOrder.push("before");selfMoveChecks.push(this===movementAudio&&event.isTrusted&&window.event===event)});
globalThis.nextMoveHandler=function(event){selfMoveOrder.push("replacement");selfMoveChecks.push(this===movementAudio&&event.target===movementAudio&&event.currentTarget===movementAudio&&event.isTrusted&&window.event===event);this.onpointermove=null};
movementAudio.onpointermove=function(event){selfMoveOrder.push("first");selfMoveChecks.push(this===movementAudio&&event.isTrusted&&window.event===event);this.onpointermove=nextMoveHandler};
movementAudio.addEventListener("pointermove",function(event){selfMoveOrder.push("after");selfMoveChecks.push(this===movementAudio&&event.isTrusted&&window.event===event)});
movementAudio.onmousemove=function(event){selfMoveOrder.push("mouse");selfMoveChecks.push(this===movementAudio&&event.type==="mousemove"&&event.target===movementAudio&&event.currentTarget===movementAudio&&event.isTrusted&&window.event===event);result.textContent=selfMoveOrder.join(",")};
document.body.appendChild(movementAudio);void movementAudio.paused;
')!
	mut app := media_movement_handler_app(owner, document, runtime)
	audio := document.get_element_by_id('movement-audio')?
	input := page.InputTarget.from_node(audio.as_node())
	for _ in 0 .. 3 {
		assert owner.handle_mousemove(input, page.PixelPoint{10, 10}, 0, 0) == .handled
		app.poll_javascript_tasks()
	}
	assert runtime.evaluate_host('selfMoveOrder.join(",")==="before,first,after,mouse,before,replacement,after,mouse,before,after,mouse"&&movementAudio.onpointermove===null')! == 'true'
	runtime.evaluate_host(r'globalThis.reactivatedMove=function(event){selfMoveOrder.push("reactivated");selfMoveChecks.push(this===movementAudio&&event.target===movementAudio&&event.currentTarget===movementAudio&&event.isTrusted&&window.event===event)};movementAudio.onpointermove=reactivatedMove;0')!
	assert owner.handle_mousemove(input, page.PixelPoint{11, 10}, 0, 0) == .handled
	app.poll_javascript_tasks()
	assert runtime.evaluate_host('selfMoveOrder.join(",")==="before,first,after,mouse,before,replacement,after,mouse,before,after,mouse,before,after,reactivated,mouse"&&movementAudio.onpointermove===reactivatedMove&&selfMoveChecks.every(Boolean)')! == 'true'
	assert document.get_element_by_id('result')?.as_node().text_content()? == runtime.evaluate_host('selfMoveOrder.join(",")')!
	runtime.evaluate_host(r'
globalThis.throwMoveReason={original:true};globalThis.throwMoveOrder=[];globalThis.throwMoveChecks=[];globalThis.movementPrimaryCalls=0;
video.onpointermove=function(event){throwMoveOrder.push("pointer");throwMoveChecks.push(this===video&&event.type==="pointermove"&&event.target===video&&event.currentTarget===video&&event.isTrusted&&window.event===event);result.textContent="pointer before exception";throw throwMoveReason};
video.addEventListener("pointermove",function(event){throwMoveOrder.push("later");throwMoveChecks.push(this===video&&event.isTrusted&&!event.defaultPrevented&&window.event===event)});
video.onmousemove=function(event){throwMoveOrder.push("mouse");throwMoveChecks.push(this===video&&event.type==="mousemove"&&event.target===video&&event.currentTarget===video&&event.isTrusted&&window.event===event);result.textContent="compatibility after exception";return 0};
video.onclick=function(event){throwMoveOrder.push("click");movementPrimaryCalls++;throwMoveChecks.push(this===video&&event.type==="click"&&event.target===video&&event.currentTarget===video&&event.isTrusted&&window.event===event);this.onpointermove=null;result.textContent="native click after movement"};0
')!
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	before_exceptions := settings.realm().reported_exceptions.len
	video := document.get_element_by_id('video')?
	video_input := page.InputTarget.from_node(video.as_node())
	assert owner.event_handler.handle_platform_pointer_event('pointermove', video_input, page.PixelPoint{14, 12}, page.PixelPoint{114, 112},
		0, 0, 0, 0) == .handled
	assert runtime.evaluate_host('throwMoveOrder.join(",")==="pointer,later,mouse"&&throwMoveChecks.every(Boolean)&&window.event===undefined')! == 'true'
	assert settings.realm().reported_exceptions.len == before_exceptions + 1
	assert runtime.actual_webidl_value(settings.realm().reported_exceptions[before_exceptions].value.as_webidl_value()!)! == runtime.evaluate_host_value('throwMoveReason')!
	app.poll_javascript_tasks()
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'compatibility after exception'
	assert owner.handle_mousedown(video_input, page.PixelPoint{14, 12}, 0, 1, 0, 1) == .handled
	assert owner.handle_mouseup(video_input, page.PixelPoint{14, 12}, 0, 0, 0) == .handled
	assert owner.event_handler.last_click_allowed()
	app.poll_javascript_tasks()
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'native click after movement'
	assert !app.dispatch_javascript_event('click', video)
	assert owner.event_handler.take_last_click_event() == none
	assert !app.dispatch_javascript_event('click', video)
	assert runtime.evaluate_host('movementPrimaryCalls===1&&throwMoveOrder.join(",")==="pointer,later,mouse,click"&&video.onpointermove===null&&throwMoveChecks.every(Boolean)&&window.event===undefined')! == 'true'
	assert settings.realm().reported_exceptions.len == before_exceptions + 1
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert app.js_messages == []
	assert !runtime.libjs_vm().has_running_execution_context()
}
