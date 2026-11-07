module main

import browserjs
import dom
import page
import time

fn media_pointer_handler_document(markup string, address string) !(&page.Page, &dom.Document) {
	owner := page.Page.create(1)!
	document := parse_browser_navigation_document_for_page_with_response_time(markup, dom.URL{
		value: address
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	return owner, document
}

fn test_ordinary_media_pointer_handlers_deliver_one_trusted_page_sequence_before_compact_replay() {
	$if !darwin {
		return
	}
	mut owner, mut document := media_pointer_handler_document('<video id="video"></video><div id="result">waiting</div>',
		'https://media-pointer-handlers.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.pointerAudio=document.createElement("audio");pointerAudio.id="pointer-audio";document.body.appendChild(pointerAudio);',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host(r'["onpointerdown","onpointerup","onmousedown","onmouseup"].every(name=>{const descriptor=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,name);return !!descriptor&&typeof descriptor.get==="function"&&typeof descriptor.set==="function"&&video[name]===null&&pointerAudio[name]===null})')! == 'true'
	runtime.evaluate_host(r'
globalThis.pointerHandlerOrder=[];globalThis.pointerHandlerChecks=[];globalThis.pointerHandlerSaved=[];
for(const [name,player] of [["video",video],["audio",pointerAudio]]){
 for(const type of ["pointerdown","mousedown","pointerup","mouseup"])player["on"+type]=function(event){
  pointerHandlerOrder.push(name+":"+event.type);pointerHandlerSaved.push(event);
  pointerHandlerChecks.push(arguments.length===1&&this===player&&event.target===player&&event.currentTarget===player&&event instanceof Event&&event.isTrusted&&event.bubbles&&event.cancelable&&window.event===event);
 };
 player.addEventListener("click",function(event){pointerHandlerOrder.push(name+":click");pointerHandlerSaved.push(event);pointerHandlerChecks.push(this===player&&event.target===player&&event.currentTarget===player&&event instanceof Event&&event.isTrusted&&window.event===event);result.textContent=pointerHandlerOrder.join(",")});
}
')!
	mut app := BrowserApp{
		page_model:       owner
		document:         document
		js_runtime:       runtime
		layout_tree_only: true
		viewport_width:   320
		viewport_height:  200
	}
	for index, id in ['video', 'pointer-audio'] {
		target := document.get_element_by_id(id)?
		input := page.InputTarget.from_node(target.as_node())
		assert owner.handle_mousedown(input, page.PixelPoint{10, 10}, 0, 1, 0, 1) == .handled
		assert owner.handle_mouseup(input, page.PixelPoint{10, 10}, 0, 0, 0) == .handled
		assert owner.event_handler.last_click_allowed()
		assert runtime.evaluate_host('pointerHandlerOrder.length')! == ((index + 1) * 5).str()
		assert !app.dispatch_javascript_event('click', target)
		assert runtime.evaluate_host('pointerHandlerOrder.length')! == ((index + 1) * 5).str()
		assert voidptr(runtime.native_event_target(runtime.evaluate_host_value(if index == 0 {
			'video'
		} else {
			'pointerAudio'
		})!)!) == voidptr(target)
	}
	assert runtime.evaluate_host(r'pointerHandlerOrder.join(",")==="video:pointerdown,video:mousedown,video:pointerup,video:mouseup,video:click,audio:pointerdown,audio:mousedown,audio:pointerup,audio:mouseup,audio:click"&&pointerHandlerChecks.length===10&&pointerHandlerChecks.every(Boolean)&&pointerHandlerSaved.every(event=>event.currentTarget===null)&&window.event===undefined')! == 'true'
	assert document.get_element_by_id('result')?.as_node().text_content()? == runtime.evaluate_host('pointerHandlerOrder.join(",")')!
	assert app.js_messages == []
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_media_pointerdown_false_suppresses_compatibility_until_release_and_null_restores_next_press() {
	$if !darwin {
		return
	}
	mut owner, mut document := media_pointer_handler_document('<video id="video"></video>',
		'https://media-pointer-handler-cancellation.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host(r'["onpointerdown","onpointerup","onmousedown","onmouseup"].every(name=>{const descriptor=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,name);return !!descriptor&&typeof descriptor.get==="function"&&typeof descriptor.set==="function"&&video[name]===null})')! == 'true'
	runtime.evaluate_host(r'
globalThis.cancelledPointerOrder=[];globalThis.cancelledPointerChecks=[];globalThis.cancelledDown=null;globalThis.cancelledClick=null;
video.onpointerdown=function(event){cancelledPointerOrder.push("pointerdown");cancelledPointerChecks.push(this===video&&event.target===video&&event.currentTarget===video&&event.isTrusted&&window.event===event);cancelledDown=event;return false};
for(const type of ["mousedown","pointerup","mouseup"])video["on"+type]=function(event){cancelledPointerOrder.push(type);cancelledPointerChecks.push(this===video&&event.target===video&&event.currentTarget===video&&event.isTrusted&&window.event===event)};
video.addEventListener("click",function(event){cancelledPointerOrder.push("click");cancelledPointerChecks.push(this===video&&event.target===video&&event.currentTarget===video&&event.isTrusted);cancelledClick=event});
')!
	video := document.get_element_by_id('video')?
	input := page.InputTarget.from_node(video.as_node())
	assert owner.handle_mousedown(input, page.PixelPoint{10, 10}, 0, 1, 0, 1) == .cancelled
	assert runtime.evaluate_host('cancelledPointerOrder.join(",")==="pointerdown"&&cancelledDown.defaultPrevented')! == 'true'
	assert owner.handle_mouseup(input, page.PixelPoint{10, 10}, 0, 0, 0) == .handled
	assert owner.event_handler.last_click_allowed()
	assert runtime.evaluate_host('cancelledPointerOrder.join(",")==="pointerdown,pointerup,click"&&!cancelledClick.defaultPrevented&&cancelledDown.currentTarget===null&&cancelledClick.currentTarget===null')! == 'true'
	mut app := BrowserApp{
		page_model:       owner
		document:         document
		js_runtime:       runtime
		layout_tree_only: true
		viewport_width:   320
		viewport_height:  200
	}
	assert !app.dispatch_javascript_event('click', video)
	assert runtime.evaluate_host('cancelledPointerOrder.length===3')! == 'true'
	assert runtime.evaluate_host(r'video.onpointerdown=null;video.onpointerdown===null&&!Object.hasOwn(video,"onpointerdown")')! == 'true'
	runtime.evaluate_host(r'globalThis.restoredPointerDown=function(event){cancelledPointerOrder.push("pointerdown");cancelledPointerChecks.push(this===video&&event.target===video&&event.currentTarget===video&&event.isTrusted&&window.event===event)};video.onpointerdown=restoredPointerDown;0')!
	assert runtime.evaluate_host('video.onpointerdown===restoredPointerDown')! == 'true'
	assert owner.handle_mousedown(input, page.PixelPoint{10, 10}, 0, 1, 0, 1) == .handled
	assert owner.handle_mouseup(input, page.PixelPoint{10, 10}, 0, 0, 0) == .handled
	assert owner.event_handler.last_click_allowed()
	assert !app.dispatch_javascript_event('click', video)
	assert runtime.evaluate_host(r'cancelledPointerOrder.join(",")==="pointerdown,pointerup,click,pointerdown,mousedown,pointerup,mouseup,click"&&cancelledPointerChecks.length===8&&cancelledPointerChecks.every(Boolean)&&window.event===undefined')! == 'true'
	assert app.js_messages == []
}

fn test_created_media_pointer_handlers_keep_slot_owner_and_page_gate_with_raw_content_preserved() {
	$if !darwin {
		return
	}
	raw_source := 'globalThis.rawPointerHandlerRuns++'
	mut owner, mut document := media_pointer_handler_document('<video id="raw" onpointerdown="${raw_source}"></video>',
		'https://media-pointer-handler-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.detachedPointerAudio=document.createElement("audio");detachedPointerAudio.id="detached-pointer-audio";globalThis.rawPointerHandlerRuns=0;',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host(r'["onpointerdown","onpointerup","onmousedown","onmouseup"].every(name=>{const descriptor=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,name);return !!descriptor&&typeof descriptor.get==="function"&&typeof descriptor.set==="function"&&raw[name]===null&&detachedPointerAudio[name]===null})')! == 'true'
	assert document.get_element_by_id('detached-pointer-audio') == none
	created_target := runtime.native_event_target(runtime.evaluate_host_value('detachedPointerAudio')!)!
	created := unsafe { &dom.Element(created_target) }
	assert voidptr(created.document()) == voidptr(document)
	runtime.evaluate_host(r'
globalThis.createdPointerOrder=[];globalThis.createdPointerChecks=[];globalThis.createdPointerEvent=null;
detachedPointerAudio.addEventListener("pointerup",function(event){createdPointerOrder.push("before");createdPointerChecks.push(this===detachedPointerAudio&&event.target===detachedPointerAudio&&event.currentTarget===detachedPointerAudio&&event.isTrusted)});
detachedPointerAudio.onpointerup=function(){createdPointerOrder.push("old")};
detachedPointerAudio.addEventListener("pointerup",function(event){createdPointerOrder.push("after");createdPointerChecks.push(this===detachedPointerAudio&&event.target===detachedPointerAudio&&event.currentTarget===detachedPointerAudio&&event.isTrusted)});
globalThis.createdPointerReplacement=function(event){createdPointerOrder.push("replacement");createdPointerChecks.push(this===detachedPointerAudio&&event.target===detachedPointerAudio&&event.currentTarget===detachedPointerAudio&&event instanceof Event&&event.isTrusted&&window.event===event);createdPointerEvent=event};detachedPointerAudio.onpointerup=createdPointerReplacement;0
')!
	input := page.InputTarget.from_node(created.as_node())
	assert owner.handle_mousedown(input, page.PixelPoint{10, 10}, 0, 1, 0, 1) == .handled
	assert owner.handle_mouseup(input, page.PixelPoint{10, 10}, 0, 0, 0) == .handled
	assert runtime.evaluate_host('createdPointerOrder.join(",")==="before,replacement,after"&&createdPointerEvent.currentTarget===null')! == 'true'
	assert runtime.evaluate_host('document.body.appendChild(detachedPointerAudio);detachedPointerAudio.onpointerup===createdPointerReplacement')! == 'true'
	assert voidptr(document.get_element_by_id('detached-pointer-audio')?) == voidptr(created)
	assert voidptr(runtime.native_event_target(runtime.evaluate_host_value('detachedPointerAudio')!)!) == voidptr(created)
	assert runtime.evaluate_host('detachedPointerAudio.onpointerup=null;detachedPointerAudio.onpointerup===null')! == 'true'
	assert created_target.event_listener_list().len == 2
	assert owner.handle_mousedown(input, page.PixelPoint{10, 10}, 0, 1, 0, 1) == .handled
	assert owner.handle_mouseup(input, page.PixelPoint{10, 10}, 0, 0, 0) == .handled
	assert runtime.evaluate_host('createdPointerOrder.join(",")')! == 'before,replacement,after,before,after'
	runtime.evaluate_host(r'globalThis.reactivatedPointerHandler=function(event){createdPointerOrder.push("reactivated");createdPointerChecks.push(this===detachedPointerAudio&&event.target===detachedPointerAudio&&event.currentTarget===detachedPointerAudio&&event.isTrusted&&window.event===event)};detachedPointerAudio.onpointerup=reactivatedPointerHandler;0')!
	owner.set_is_scripting_enabled(false)
	assert owner.handle_mousedown(input, page.PixelPoint{10, 10}, 0, 1, 0, 1) == .handled
	assert owner.handle_mouseup(input, page.PixelPoint{10, 10}, 0, 0, 0) == .handled
	assert runtime.evaluate_host('createdPointerOrder.length===5')! == 'true'
	owner.set_is_scripting_enabled(true)
	assert owner.handle_mousedown(input, page.PixelPoint{10, 10}, 0, 1, 0, 1) == .handled
	assert owner.handle_mouseup(input, page.PixelPoint{10, 10}, 0, 0, 0) == .handled
	assert runtime.evaluate_host(r'createdPointerOrder.join(",")==="before,replacement,after,before,after,before,after,reactivated"&&createdPointerChecks.length===8&&createdPointerChecks.every(Boolean)&&window.event===undefined')! == 'true'
	// The source release ignores compatibility mouseup cancellation when it
	// determines whether to dispatch click and permit its default action.
	runtime.evaluate_host(r'globalThis.mouseUpHandlerOrder=[];globalThis.mouseUpHandlerChecks=[];globalThis.savedCancelledMouseUp=null;
detachedPointerAudio.onmouseup=function(event){mouseUpHandlerOrder.push("mouseup");mouseUpHandlerChecks.push(this===detachedPointerAudio&&event.target===detachedPointerAudio&&event.currentTarget===detachedPointerAudio&&event.isTrusted&&window.event===event);savedCancelledMouseUp=event;return false};
detachedPointerAudio.addEventListener("click",function(event){mouseUpHandlerOrder.push("click");mouseUpHandlerChecks.push(this===detachedPointerAudio&&event.target===detachedPointerAudio&&event.currentTarget===detachedPointerAudio&&event.isTrusted&&!event.defaultPrevented)});0')!
	assert owner.handle_mousedown(input, page.PixelPoint{10, 10}, 0, 1, 0, 1) == .handled
	assert owner.handle_mouseup(input, page.PixelPoint{10, 10}, 0, 0, 0) == .handled
	assert owner.event_handler.last_click_allowed()
	assert runtime.evaluate_host('mouseUpHandlerOrder.join(",")==="mouseup,click"&&mouseUpHandlerChecks.length===2&&mouseUpHandlerChecks.every(Boolean)&&savedCancelledMouseUp.defaultPrevented&&savedCancelledMouseUp.currentTarget===null&&window.event===undefined')! == 'true'

	// The element compiler remains unavailable. Real pointer delivery preserves
	// the raw slot until an IDL assignment replaces it, without changing the HTML.
	raw := document.get_element_by_id('raw')?
	raw_target := runtime.native_event_target(runtime.evaluate_host_value('raw')!)!
	raw_handler := raw_target.data.event_handler('pointerdown') or {
		assert false, 'missing raw pointer handler'
		return
	}
	assert raw_handler.value.kind == .string && raw_handler.value.string_data == raw_source
	raw_input := page.InputTarget.from_node(raw.as_node())
	assert owner.handle_mousedown(raw_input, page.PixelPoint{10, 10}, 0, 1, 0, 1) == .handled
	assert owner.handle_mouseup(raw_input, page.PixelPoint{10, 10}, 0, 0, 0) == .handled
	assert runtime.evaluate_host('raw.onpointerdown===null&&rawPointerHandlerRuns===0')! == 'true'
	assert raw_handler.value.kind == .string && raw_handler.value.string_data == raw_source
	runtime.evaluate_host(r'globalThis.assignedRawPointerCalls=0;raw.onpointerdown=function(event){assignedRawPointerCalls++;globalThis.assignedRawPointerValid=this===raw&&event.target===raw&&event.currentTarget===raw&&event.isTrusted};0')!
	assigned := raw_target.data.event_handler('pointerdown') or {
		assert false, 'missing assigned pointer handler'
		return
	}
	assert voidptr(assigned) == voidptr(raw_handler) && assigned.value.kind == .object
	assert owner.handle_mousedown(raw_input, page.PixelPoint{10, 10}, 0, 1, 0, 1) == .handled
	assert owner.handle_mouseup(raw_input, page.PixelPoint{10, 10}, 0, 0, 0) == .handled
	assert runtime.evaluate_host('assignedRawPointerCalls===1&&assignedRawPointerValid&&rawPointerHandlerRuns===0')! == 'true'
	assert raw.get_attribute('onpointerdown')? == raw_source
	assert runtime.evaluate_host('raw.onpointerdown=null;raw.onpointerdown===null')! == 'true'
	assert !raw_target.data.has_event_handler('pointerdown')
	assert raw_target.event_listener_list().len == 0
	assert raw.get_attribute('onpointerdown')? == raw_source
	assert !runtime.libjs_vm().has_running_execution_context()
}
