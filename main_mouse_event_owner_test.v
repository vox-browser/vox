module main

import browserjs
import dom
import html
import page
import time

fn mouse_event_owner_document(address string) !(&page.Page, &dom.Document) {
	mut owner := page.Page.create(1)!
	owner.set_enable_autoscroll(false)
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="video"></video><div id="result">waiting</div>', dom.URL{
		value: address
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	return owner, document
}

fn mouse_event_owner_guard(runtime &browserjs.Runtime) !bool {
	return runtime.evaluate_host(r'typeof MouseEvent==="function"&&Object.getPrototypeOf(MouseEvent.prototype)===UIEvent.prototype&&typeof MouseEvent.prototype.getModifierState==="function"&&typeof MouseEvent.prototype.initMouseEvent==="function"')! == 'true'
}

fn mouse_event_owner_app(owner &page.Page, document &dom.Document, runtime &browserjs.Runtime) BrowserApp {
	return BrowserApp{
		page_model:       owner
		document:         document
		js_runtime:       runtime
		layout_tree_only: true
		viewport_width:   320
		viewport_height:  200
	}
}

// Compare exposed values with the actual record dispatched by Page. Page/offset
// geometry depends on its committed paint state; this fixture does not replace
// that calculation or claim physical Cocoa coordinate construction parity.
fn mouse_event_owner_record_matches(mut runtime browserjs.Runtime, expression string) !bool {
	wrapper := runtime.evaluate_host_value(expression)!
	event := runtime.native_event(wrapper)!
	if runtime.javascript_event(event)! != wrapper { return false }
	mouse := unsafe { &dom.MouseEvent(event) }
	mut values := [mouse.screen_x(), mouse.screen_y(), mouse.page_x(),
		mouse.page_y(), mouse.client_x(), mouse.client_y(), mouse.offset_x(),
		mouse.offset_y()]
	if event.interface_ == .pointer_event {
		pointer := unsafe { &dom.PointerEvent(event) }
		values = [pointer.screen_x(), pointer.screen_y(), pointer.page_x(),
			pointer.page_y(), pointer.client_x(), pointer.client_y(),
			pointer.offset_x(), pointer.offset_y()]
	}
	// MouseEvent::x/y call the virtual client getter, including PointerEvent's
	// fractional untrusted move behavior, rather than its base implementation.
	values << values[4]
	values << values[5]
	values << mouse.movement_x()
	values << mouse.movement_y()
	values << f64(mouse.button())
	values << f64(mouse.buttons())
	expected := values.map(it.str()).join(',')
	if runtime.evaluate_host('(()=>{const event=${expression};return [event.screenX,event.screenY,event.pageX,event.pageY,event.clientX,event.clientY,event.offsetX,event.offsetY,event.x,event.y,event.movementX,event.movementY,event.button,event.buttons].every((value,index)=>value===[${expected}][index])&&event.ctrlKey===${mouse.ctrl_key()}&&event.shiftKey===${mouse.shift_key()}&&event.altKey===${mouse.alt_key()}&&event.metaKey===${mouse.meta_key()}&&event.getModifierState("Control")===${mouse.get_modifier_state('Control')}&&event.getModifierState("Shift")===${mouse.get_modifier_state('Shift')}&&event.getModifierState("Alt")===${mouse.get_modifier_state('Alt')}&&event.getModifierState("Meta")===${mouse.get_modifier_state('Meta')}&&event.getModifierState("AltGraph")===${mouse.get_modifier_state('AltGraph')}&&event.getModifierState("Super")===${mouse.get_modifier_state('Super')}&&event.getModifierState("unknown")===false})()')! != 'true' {
		return false
	}
	if related := event.related_target() {
		return runtime.evaluate_host_value('${expression}.relatedTarget')! == runtime.javascript_event_target(related,
			none)!
	}
	return runtime.evaluate_host('${expression}.relatedTarget===null')! == 'true'
}

fn test_trusted_page_mouse_binding_exposes_native_movement_and_related_owner_values() {
	$if !darwin { return }
	mut owner, mut document :=
		mouse_event_owner_document('https://mouse-event-movement-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.mouseAudio=document.createElement("audio");mouseAudio.id="mouse-audio";0',
	], runtime, mut messages)
	assert messages == []
	assert mouse_event_owner_guard(runtime)!
	assert document.get_element_by_id('mouse-audio') == none
	created_target := runtime.native_event_target(runtime.evaluate_host_value('mouseAudio')!)!
	runtime.evaluate_host(r'
globalThis.mouseMoveOrder=[];globalThis.mouseMoveSaved=[];globalThis.mouseMoveChecks=[];globalThis.mouseHoverSaved=[];globalThis.mouseHoverChecks=[];globalThis.mouseExpectedRelated=null;globalThis.mouseExpectedTrusted=true;globalThis.mouseExpectedButton=2;globalThis.mouseExpectedButtons=2;globalThis.cancelNativePointerMove=true;globalThis.cancelNativeMouseMove=false;
for(const player of [video,mouseAudio]){
 player.addEventListener("mouseover",function(event){mouseHoverSaved.push(event);mouseHoverChecks.push(this===player&&event instanceof MouseEvent&&event instanceof UIEvent&&event.isTrusted&&event.target===player&&event.currentTarget===player&&event.relatedTarget===mouseExpectedRelated&&event.view===window&&window.event===event)});
 for(const type of ["pointermove","mousemove"]){
  player.addEventListener(type,function(event){mouseMoveOrder.push(type+":before");mouseMoveChecks.push(this===player&&event.target===player&&event.currentTarget===player&&window.event===event)});
  player["on"+type]=function(event){mouseMoveOrder.push(type+":handler");mouseMoveSaved.push(event);mouseMoveChecks.push(this===player&&arguments.length===1&&event instanceof MouseEvent&&event instanceof UIEvent&&event instanceof Event&&event.type===type&&event.isTrusted===mouseExpectedTrusted&&event.view===window&&event.detail===0&&event.which===mouseExpectedButton+1&&event.button===mouseExpectedButton&&event.buttons===mouseExpectedButtons&&event.relatedTarget===null&&event.target===player&&event.currentTarget===player&&window.event===event);return(type==="pointermove"?cancelNativePointerMove:cancelNativeMouseMove)?false:0};
  player.addEventListener(type,function(event){mouseMoveOrder.push(type+":after");mouseMoveChecks.push(this===player&&event.currentTarget===player&&event.defaultPrevented===(type==="pointermove"?cancelNativePointerMove:cancelNativeMouseMove)&&window.event===event);result.textContent=mouseMoveOrder.join(",")});
 }
}
document.body.appendChild(mouseAudio);void mouseAudio.paused;0
')!
	assert voidptr(document.get_element_by_id('mouse-audio')?) == voidptr(created_target)
	mut app := mouse_event_owner_app(owner, document, runtime)
	for index, id in ['video', 'mouse-audio'] {
		target := document.get_element_by_id(id)?
		input := page.InputTarget.from_node(target.as_node())
		runtime.evaluate_host('mouseMoveOrder=[];mouseMoveSaved=[];mouseExpectedRelated=${if index == 0 {
			'null'
		} else {
			'video'
		}};mouseExpectedTrusted=true;mouseExpectedButton=2;mouseExpectedButtons=2;cancelNativePointerMove=true;cancelNativeMouseMove=false;0')!
		assert owner.event_handler.handle_platform_pointer_event('pointermove', input, page.PixelPoint{11.5, 21.125}, page.PixelPoint{111.25, 221.75},
			2, 2, dom.modifier_ctrl | dom.modifier_shift | dom.modifier_alt | dom.modifier_super, 0) == .handled
		assert runtime.evaluate_host('mouseMoveSaved.length===2&&mouseMoveSaved.every(event=>event.screenX===111.25&&event.screenY===221.75&&event.clientX===11.5&&event.clientY===21.125&&event.ctrlKey&&event.shiftKey&&event.altKey&&event.metaKey)&&mouseMoveSaved[0].defaultPrevented&&!mouseMoveSaved[1].defaultPrevented')! == 'true'
		app.poll_javascript_tasks()
		assert document.get_element_by_id('result')?.as_node().text_content()? == 'pointermove:before,pointermove:handler,pointermove:after,mousemove:before,mousemove:handler,mousemove:after'
		runtime.evaluate_host('mouseExpectedButton=1;mouseExpectedButtons=4;cancelNativePointerMove=false;cancelNativeMouseMove=true;0')!
		assert owner.event_handler.handle_platform_pointer_event('pointermove', input, page.PixelPoint{12.75, 22.5}, page.PixelPoint{112.875, 222.625},
			1, 4, dom.modifier_shift, 0) == .cancelled
		assert runtime.evaluate_host('mouseMoveSaved.length===4&&mouseMoveSaved.slice(2).every(event=>event.clientX===12.75&&event.clientY===22.5&&event.shiftKey&&!event.ctrlKey&&!event.altKey&&!event.metaKey)&&!mouseMoveSaved[2].defaultPrevented&&mouseMoveSaved[3].defaultPrevented&&mouseMoveChecks.every(Boolean)&&window.event===undefined')! == 'true'
		for saved in 0 .. 4 {
			assert mouse_event_owner_record_matches(mut runtime, 'mouseMoveSaved[${saved}]')!
		}
		// Source dispatchEvent turns these actual records untrusted. Pointer move
		// keeps fractional virtual coordinates; Mouse move floors its coordinates.
		assert runtime.evaluate_host(r'(()=>{mouseExpectedTrusted=false;cancelNativePointerMove=false;cancelNativeMouseMove=false;mouseExpectedButton=1;mouseExpectedButtons=4;const replayMouseOwner=mouseMoveSaved[2].target;const pointerReplay=replayMouseOwner.dispatchEvent(mouseMoveSaved[2]);mouseExpectedButton=2;mouseExpectedButtons=2;const mouseReplay=replayMouseOwner.dispatchEvent(mouseMoveSaved[1]);return pointerReplay&&mouseReplay&&mouseMoveSaved.length===6&&mouseMoveSaved[4]===mouseMoveSaved[2]&&mouseMoveSaved[5]===mouseMoveSaved[1]&&!mouseMoveSaved[4].isTrusted&&!mouseMoveSaved[5].isTrusted&&mouseMoveSaved[4].screenX===112.875&&mouseMoveSaved[4].clientX===12.75&&mouseMoveSaved[4].x===12.75&&mouseMoveSaved[5].screenX===111&&mouseMoveSaved[5].clientX===11&&mouseMoveSaved[5].x===11})()')! == 'true'
		assert runtime.evaluate_host('mouseMoveChecks.every(Boolean)&&mouseMoveSaved.every(event=>event.currentTarget===null&&event.eventPhase===Event.NONE)&&window.event===undefined')! == 'true'
		for saved in 4 .. 6 {
			assert mouse_event_owner_record_matches(mut runtime, 'mouseMoveSaved[${saved}]')!
		}
		app.poll_javascript_tasks()
		assert document.get_element_by_id('result')?.as_node().text_content()? == runtime.evaluate_host('mouseMoveOrder.join(",")')!
		assert !app.dispatch_javascript_event('pointermove', target)
		assert !app.dispatch_javascript_event('mousemove', target)
		assert runtime.evaluate_host('mouseMoveOrder.length===18')! == 'true'
	}
	assert runtime.evaluate_host('mouseHoverSaved.length===2&&mouseHoverChecks.every(Boolean)&&mouseHoverSaved[0].relatedTarget===null&&mouseHoverSaved[1].relatedTarget===video')! == 'true'
	for saved in 0 .. 2 {
		assert mouse_event_owner_record_matches(mut runtime, 'mouseHoverSaved[${saved}]')!
	}
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert app.js_messages == [] && !runtime.libjs_vm().has_running_execution_context()
}

fn test_trusted_page_mouse_click_binding_keeps_native_data_cancellation_and_single_compact_delivery() {
	$if !darwin { return }
	mut owner, mut document :=
		mouse_event_owner_document('https://mouse-event-click-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.mouseClickAudio=document.createElement("audio");mouseClickAudio.id="mouse-click-audio";0',
	], runtime, mut messages)
	assert messages == []
	assert mouse_event_owner_guard(runtime)!
	runtime.evaluate_host(r'
globalThis.mouseClickOrder=[];globalThis.mouseClickSaved=[];globalThis.mouseClickChecks=[];globalThis.cancelNativeClick=false;
for(const player of [video,mouseClickAudio])for(const type of ["pointerdown","mousedown","pointerup","mouseup","click"]){
 player.addEventListener(type,function(event){mouseClickOrder.push(type+":before");mouseClickChecks.push(this===player&&event.currentTarget===player&&window.event===event)});
 player["on"+type]=function(event){
  mouseClickOrder.push(type+":handler");mouseClickSaved.push(event);const detail=type.startsWith("pointer")?0:1;
  mouseClickChecks.push(this===player&&arguments.length===1&&event instanceof MouseEvent&&event instanceof UIEvent&&event instanceof Event&&event.isTrusted&&event.type===type&&event.view===window&&event.detail===detail&&event.button===0&&event.which===1&&event.relatedTarget===null&&event.target===player&&event.currentTarget===player&&window.event===event);
  const original=[event.screenX,event.screenY,event.pageX,event.pageY,event.clientX,event.clientY,event.offsetX,event.offsetY,event.button,event.buttons,event.ctrlKey,event.shiftKey,event.altKey,event.metaKey];
  const returned=event.initMouseEvent("ignored while dispatching",false,false,null,99,7,8,9,10,false,false,false,false,1,null);
  mouseClickChecks.push(returned===undefined&&event.type===type&&event.detail===detail&&event.view===window&&event.isTrusted&&event.bubbles&&event.cancelable&&event.currentTarget===player&&window.event===event&&[event.screenX,event.screenY,event.pageX,event.pageY,event.clientX,event.clientY,event.offsetX,event.offsetY,event.button,event.buttons,event.ctrlKey,event.shiftKey,event.altKey,event.metaKey].every((value,index)=>value===original[index]));if(type==="click"&&cancelNativeClick)return false;
 };
 player.addEventListener(type,function(event){mouseClickOrder.push(type+":after");mouseClickChecks.push(this===player&&event.currentTarget===player&&window.event===event&&event.defaultPrevented===(type==="click"&&cancelNativeClick));result.textContent=mouseClickOrder.join(",")});
}
document.body.appendChild(mouseClickAudio);void mouseClickAudio.paused;0
')!
	mut app := mouse_event_owner_app(owner, document, runtime)
	for id in ['video', 'mouse-click-audio'] {
		target := document.get_element_by_id(id)?
		input := page.InputTarget.from_node(target.as_node())
		for cancel in [false, true] {
			runtime.evaluate_host('mouseClickOrder=[];mouseClickSaved=[];cancelNativeClick=${cancel};0')!
			assert owner.event_handler.handle_platform_pointer_event('pointerdown', input, page.PixelPoint{10.25, 20.75}, page.PixelPoint{110.5, 220.875},
				0, 1, dom.modifier_shift | dom.modifier_alt, 1) == .handled
			assert owner.event_handler.handle_platform_pointer_event('pointerup', input, page.PixelPoint{11.75, 21.25}, page.PixelPoint{111.875, 221.625},
				0, 0, dom.modifier_shift | dom.modifier_super, 1) == .handled
			assert owner.event_handler.last_click_allowed() == !cancel
			assert runtime.evaluate_host('mouseClickOrder.join(",")==="pointerdown:before,pointerdown:handler,pointerdown:after,mousedown:before,mousedown:handler,mousedown:after,pointerup:before,pointerup:handler,pointerup:after,mouseup:before,mouseup:handler,mouseup:after,click:before,click:handler,click:after"&&mouseClickSaved.length===5&&mouseClickChecks.every(Boolean)&&mouseClickSaved.slice(0,2).every(event=>event.screenX===110.5&&event.clientX===10.25&&event.buttons===1&&event.shiftKey&&event.altKey&&!event.ctrlKey&&!event.metaKey)&&mouseClickSaved.slice(2).every(event=>event.screenX===111.875&&event.clientX===11.75&&event.buttons===0&&event.shiftKey&&event.metaKey&&!event.ctrlKey&&!event.altKey)&&mouseClickSaved[4].defaultPrevented===cancelNativeClick&&mouseClickSaved.every(event=>event.currentTarget===null&&event.eventPhase===Event.NONE)&&window.event===undefined')! == 'true'
			for saved in 0 .. 5 {
				assert mouse_event_owner_record_matches(mut runtime, 'mouseClickSaved[${saved}]')!
			}
			app.poll_javascript_tasks()
			assert document.get_element_by_id('result')?.as_node().text_content()? == runtime.evaluate_host('mouseClickOrder.join(",")')!
			assert !app.dispatch_javascript_event('click', target)
			assert owner.event_handler.take_last_click_event() == none
			assert runtime.evaluate_host('mouseClickOrder.length===15&&mouseClickSaved.length===5')! == 'true'
		}
	}
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert app.js_messages == [] && !runtime.libjs_vm().has_running_execution_context()
}
