module main

import browserjs
import dom
import html
import page
import time

fn ui_event_owner_document(address string) !(&page.Page, &dom.Document) {
	mut owner := page.Page.create(1)!
	owner.set_enable_autoscroll(false)
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="video"></video><div id="result">waiting</div>', dom.URL{
		value: address
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	return owner, document
}

fn ui_event_owner_guard(runtime &browserjs.Runtime) !bool {
	return runtime.evaluate_host(r'typeof UIEvent==="function"&&Object.getPrototypeOf(UIEvent.prototype)===Event.prototype&&["view","detail","which"].every(name=>{const descriptor=Object.getOwnPropertyDescriptor(UIEvent.prototype,name);return !!descriptor&&typeof descriptor.get==="function"})&&typeof UIEvent.prototype.initUIEvent==="function"')! == 'true'
}

fn ui_event_owner_app(owner &page.Page, document &dom.Document, runtime &browserjs.Runtime) BrowserApp {
	return BrowserApp{
		page_model:       owner
		document:         document
		js_runtime:       runtime
		layout_tree_only: true
		viewport_width:   320
		viewport_height:  200
	}
}

fn test_trusted_page_ui_events_keep_owner_view_detail_identity_and_dispatch_initialization_guard() {
	$if !darwin { return }
	mut owner, mut document :=
		ui_event_owner_document('https://ui-event-primary-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.uiAudio=document.createElement("audio");uiAudio.id="ui-audio";0',
	], runtime, mut messages)
	assert messages == []
	assert ui_event_owner_guard(runtime)!
	assert document.get_element_by_id('ui-audio') == none
	created_target := runtime.native_event_target(runtime.evaluate_host_value('uiAudio')!)!
	runtime.evaluate_host(r'
globalThis.uiOwnerOrder=[];globalThis.uiOwnerSaved=[];globalThis.uiOwnerChecks=[];
for(const player of [video,uiAudio])for(const type of ["pointerdown","mousedown","pointerup","mouseup","click","dblclick"]){
 const callback=function(event){
  uiOwnerOrder.push(type);uiOwnerSaved.push(event);const detail=type.startsWith("pointer")?0:2;
  uiOwnerChecks.push(this===player&&arguments.length===1&&event instanceof Event&&event instanceof UIEvent&&event instanceof MouseEvent&&Object.getPrototypeOf(event)===(type.startsWith("pointer")?PointerEvent.prototype:MouseEvent.prototype)&&(event instanceof PointerEvent)===type.startsWith("pointer")&&Object.getPrototypeOf(MouseEvent.prototype)===UIEvent.prototype&&event.type===type&&event.isTrusted&&event.view===window&&event.detail===detail&&event.which===1&&event.bubbles&&event.cancelable&&event.target===player&&event.currentTarget===player&&window.event===event);
  const result=event.initUIEvent("changed during dispatch",false,false,null,99);
  uiOwnerChecks.push(result===undefined&&event.type===type&&event.isTrusted&&event.view===window&&event.detail===detail&&event.which===1&&event.bubbles&&event.cancelable&&event.currentTarget===player&&window.event===event);document.getElementById("result").textContent=uiOwnerOrder.join(",");
 };player["on"+type]=callback;uiOwnerChecks.push(player["on"+type]===callback);
}
document.body.appendChild(uiAudio);void uiAudio.paused;
')!
	assert voidptr(document.get_element_by_id('ui-audio')?) == voidptr(created_target)
	mut app := ui_event_owner_app(owner, document, runtime)
	for id in ['video', 'ui-audio'] {
		target := document.get_element_by_id(id)?
		input := page.InputTarget.from_node(target.as_node())
		runtime.evaluate_host('uiOwnerOrder=[];uiOwnerSaved=[];0')!
		assert owner.handle_mousedown(input, page.PixelPoint{10, 10}, 0, 1, 0, 2) == .handled
		assert owner.handle_mouseup(input, page.PixelPoint{10, 10}, 0, 0, 0) == .handled
		assert owner.event_handler.last_click_allowed()
		assert runtime.evaluate_host('uiOwnerOrder.join(",")==="pointerdown,mousedown,pointerup,mouseup,click,dblclick"&&uiOwnerSaved.length===6&&uiOwnerChecks.every(Boolean)&&uiOwnerSaved.every(event=>event.currentTarget===null&&event.eventPhase===Event.NONE&&!event.defaultPrevented&&event.view===window)&&window.event===undefined')! == 'true'
		for index in 0 .. 6 {
			wrapper := runtime.evaluate_host_value('uiOwnerSaved[${index}]')!
			event := runtime.native_event(wrapper)!
			assert runtime.javascript_event(event)! == wrapper
			assert event.is_trusted() && event.current_target() == none
			assert voidptr(event.target()?) == voidptr(target)
			assert dom.event_is_mouse_event(event)
			assert dom.event_is_pointer_event(event) == (index in [0, 2])
			ui := unsafe { &dom.UIEvent(event) }
			assert ui.detail() == if index in [0, 2] {
				0
			} else {
				2
			}
		}
		app.poll_javascript_tasks()
		assert document.get_element_by_id('result')?.as_node().text_content()? == 'pointerdown,mousedown,pointerup,mouseup,click,dblclick'
		assert !app.dispatch_javascript_event('click', target)
		assert owner.event_handler.take_last_click_event() == none
		assert runtime.evaluate_host('uiOwnerOrder.length===6')! == 'true'
	}
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert settings.realm().reported_exceptions.len == 0
	assert app.js_messages == []
	assert !runtime.libjs_vm().has_running_execution_context()
}

fn test_trusted_page_movement_and_auxiliary_ui_events_use_dynamic_which_and_keep_live_dom() {
	$if !darwin { return }
	mut owner, mut document :=
		ui_event_owner_document('https://ui-event-nonprimary-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.uiAudio=document.createElement("audio");uiAudio.id="ui-audio";0',
	], runtime, mut messages)
	assert messages == []
	assert ui_event_owner_guard(runtime)!
	runtime.evaluate_host(r'
globalThis.uiMotionOrder=[];globalThis.uiMotionSaved=[];globalThis.uiMotionChecks=[];globalThis.uiMotionWhich=0;
for(const player of [video,uiAudio])for(const type of ["pointermove","mousemove","auxclick"]){
 player["on"+type]=function(event){
  uiMotionOrder.push(type);uiMotionSaved.push(event);const detail=type==="pointermove"?0:3;
  uiMotionChecks.push(this===player&&arguments.length===1&&event instanceof UIEvent&&event instanceof Event&&event instanceof MouseEvent&&Object.getPrototypeOf(event)===(type.startsWith("pointer")?PointerEvent.prototype:MouseEvent.prototype)&&(event instanceof PointerEvent)===type.startsWith("pointer")&&Object.getPrototypeOf(MouseEvent.prototype)===UIEvent.prototype&&event.type===type&&event.isTrusted&&event.view===window&&event.detail===detail&&event.which===uiMotionWhich&&event.target===player&&event.currentTarget===player&&window.event===event);
  event.initUIEvent("ignored during dispatch",false,false,null,-1);uiMotionChecks.push(event.type===type&&event.detail===detail&&event.view===window&&event.which===uiMotionWhich&&event.isTrusted&&event.bubbles&&event.cancelable&&window.event===event);document.getElementById("result").textContent=uiMotionOrder.join(",");if(type==="auxclick")return false;
 };
}
document.body.appendChild(uiAudio);void uiAudio.paused;
')!
	mut app := ui_event_owner_app(owner, document, runtime)
	for id in ['video', 'ui-audio'] {
		target := document.get_element_by_id(id)?
		input := page.InputTarget.from_node(target.as_node())
		for button in [u32(1), u32(2)] {
			runtime.evaluate_host('uiMotionOrder=[];uiMotionSaved=[];uiMotionWhich=${button + 1};0')!
			assert owner.handle_mousedown(input, page.PixelPoint{10, 10}, button,
				browser_pointer_button_mask(int(button)), 0, 3) == .handled
			assert owner.event_handler.handle_platform_pointer_event('pointermove', input, page.PixelPoint{11, 10}, page.PixelPoint{111, 110},
				button, browser_pointer_button_mask(int(button)), dom.modifier_shift, 3) == .handled
			app.poll_javascript_tasks()
			assert document.get_element_by_id('result')?.as_node().text_content()? == 'pointermove,mousemove'
			assert owner.handle_mouseup(input, page.PixelPoint{11, 10}, button, 0, 0) == .handled
			assert !owner.event_handler.last_click_allowed()
			assert owner.event_handler.take_last_click_event() == none
			assert runtime.evaluate_host('uiMotionOrder.join(",")==="pointermove,mousemove,auxclick"&&uiMotionSaved.length===3&&uiMotionChecks.every(Boolean)&&!uiMotionSaved[0].defaultPrevented&&!uiMotionSaved[1].defaultPrevented&&uiMotionSaved[2].defaultPrevented&&uiMotionSaved.every(event=>event.currentTarget===null&&event.eventPhase===Event.NONE&&event.isTrusted&&event.view===window)&&window.event===undefined')! == 'true'
			for index in 0 .. 3 {
				wrapper := runtime.evaluate_host_value('uiMotionSaved[${index}]')!
				event := runtime.native_event(wrapper)!
				assert runtime.javascript_event(event)! == wrapper
				assert voidptr(event.target()?) == voidptr(target)
				assert dom.event_is_pointer_event(event) == (index == 0)
				mouse := unsafe { &dom.MouseEvent(event) }
				assert mouse.which() == button + 1
			}
			app.poll_javascript_tasks()
			assert document.get_element_by_id('result')?.as_node().text_content()? == 'pointermove,mousemove,auxclick'
			assert !app.dispatch_javascript_event('auxclick', target)
			assert runtime.evaluate_host('uiMotionOrder.length===3')! == 'true'
		}
	}
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert settings.realm().reported_exceptions.len == 0
	assert app.js_messages == []
	assert !runtime.libjs_vm().has_running_execution_context()
}
