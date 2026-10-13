module main

import browserjs
import dom
import html
import page
import time

fn drag_event_owner_document(address string) !(&page.Page, &dom.Document) {
	mut owner := page.Page.create(1)!
	owner.set_enable_autoscroll(false)
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="video"></video><div id="result">waiting</div>', dom.URL{
		value: address
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	return owner, document
}

fn drag_event_owner_guard(runtime &browserjs.Runtime) !bool {
	return runtime.evaluate_host(r'typeof DragEvent==="function"&&Object.getPrototypeOf(DragEvent.prototype)===MouseEvent.prototype&&(()=>{const descriptor=Object.getOwnPropertyDescriptor(DragEvent.prototype,"dataTransfer");return !!descriptor&&typeof descriptor.get==="function"&&Function.prototype.toString.call(descriptor.get).includes("[native code]")})()')! == 'true'
}

fn drag_event_owner_app(owner &page.Page, document &dom.Document, runtime &browserjs.Runtime) BrowserApp {
	return BrowserApp{
		page_model:       owner
		document:         document
		js_runtime:       runtime
		layout_tree_only: true
		viewport_width:   320
		viewport_height:  200
	}
}

fn drag_event_owner_export(mut runtime browserjs.Runtime, name string, value voidptr) ! {
	runtime.define_value_host_function(name, fn [value] (_ voidptr, _ []voidptr) !voidptr {
		return value
	})!
}

fn drag_event_owner_record_matches(mut runtime browserjs.Runtime, expression string) !bool {
	wrapper := runtime.evaluate_host_value(expression)!
	event := runtime.native_event(wrapper)!
	if event.interface_ != .drag_event || runtime.javascript_event(event)! != wrapper {
		return false
	}
	drag := unsafe { &html.DragEvent(event) }
	mouse := unsafe { &dom.MouseEvent(event) }
	values := [mouse.screen_x(), mouse.screen_y(), mouse.page_x(), mouse.page_y(), mouse.client_x(),
		mouse.client_y(), mouse.offset_x(), mouse.offset_y(), mouse.x(), mouse.y(), mouse.movement_x(),
		mouse.movement_y(), f64(mouse.button()), f64(mouse.buttons()), event.time_stamp()]
	expected := values.map(it.str()).join(',')
	if runtime.evaluate_host('(()=>{const event=${expression};return Object.getPrototypeOf(event)===DragEvent.prototype&&Object.prototype.toString.call(event)==="[object DragEvent]"&&event instanceof DragEvent&&event instanceof MouseEvent&&event instanceof UIEvent&&event instanceof Event&&!(event instanceof PointerEvent)&&!(event instanceof WheelEvent)&&[event.screenX,event.screenY,event.pageX,event.pageY,event.clientX,event.clientY,event.offsetX,event.offsetY,event.x,event.y,event.movementX,event.movementY,event.button,event.buttons,event.timeStamp].every((value,index)=>value===[${expected}][index])&&event.ctrlKey===${mouse.ctrl_key()}&&event.shiftKey===${mouse.shift_key()}&&event.altKey===${mouse.alt_key()}&&event.metaKey===${mouse.meta_key()}&&event.getModifierState("Control")===${mouse.get_modifier_state('Control')}&&event.getModifierState("Shift")===${mouse.get_modifier_state('Shift')}})()')! != 'true' {
		return false
	}
	if transfer := drag.data_transfer() {
		transfer_wrapper := runtime.evaluate_host_value('${expression}.dataTransfer')!
		if runtime.native_data_transfer(transfer_wrapper)! != transfer
			|| runtime.javascript_data_transfer(transfer)! != transfer_wrapper {
			return false
		}
	} else if runtime.evaluate_host('${expression}.dataTransfer===null')! != 'true' {
		return false
	}
	if related := event.related_target() {
		return runtime.evaluate_host_value('${expression}.relatedTarget')! == runtime.javascript_event_target(related,
			none)!
	}
	return runtime.evaluate_host('${expression}.relatedTarget===null')! == 'true'
}

// Page's translated drag route records DragDispatch entries rather than
// dispatching DOM DragEvents. Exercise the existing native factory and actual
// owner dispatcher directly; this does not claim Cocoa/Page drag delivery,
// drag-data-store transitions, or default drop behavior.
fn test_native_drag_factory_keeps_real_owner_transfer_identity_and_cancellation() {
	$if !darwin {
		return
	}
	mut owner, mut document :=
		drag_event_owner_document('https://drag-event-factory-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.dragAudio=document.createElement("audio");dragAudio.id="drag-audio";0',
	], runtime, mut messages)
	assert messages == []
	assert drag_event_owner_guard(runtime)!
	assert document.get_element_by_id('drag-audio') == none
	created_target := runtime.native_event_target(runtime.evaluate_host_value('dragAudio')!)!
	mut transfer := html.DataTransfer.construct()
	transfer.set_data('text', 'factory owner payload')
	drag_event_owner_export(mut runtime, '__ownerNativeDragTransfer',
		runtime.javascript_data_transfer(transfer)!)!
	runtime.evaluate_host(r'
globalThis.dragOwnerTransfer=__ownerNativeDragTransfer();globalThis.dragOwnerOrder=[];globalThis.dragOwnerSaved=[];globalThis.dragOwnerChecks=[];globalThis.dragOwnerTrusted=true;globalThis.dragOwnerCancel=false;
for(const player of [video,dragAudio]){
 player.addEventListener("dragover",function(event){dragOwnerOrder.push("before");dragOwnerChecks.push(this===player&&event.target===player&&event.currentTarget===player&&window.event===event)});
 player.addEventListener("dragover",function(event){
  dragOwnerOrder.push("payload");dragOwnerSaved.push(event);
  dragOwnerChecks.push(this===player&&arguments.length===1&&event instanceof DragEvent&&event instanceof MouseEvent&&event instanceof UIEvent&&event instanceof Event&&!(event instanceof PointerEvent)&&!(event instanceof WheelEvent)&&Object.getPrototypeOf(event)===DragEvent.prototype&&Object.prototype.toString.call(event)==="[object DragEvent]"&&event.type==="dragover"&&event.isTrusted===dragOwnerTrusted&&event.bubbles&&event.cancelable&&event.composed&&event.view===window&&event.detail===7&&event.which===3&&event.button===2&&event.buttons===2&&event.relatedTarget===(player===video?dragAudio:video)&&event.target===player&&event.currentTarget===player&&window.event===event&&event.dataTransfer===dragOwnerTransfer&&event.dataTransfer===event.dataTransfer&&event.ctrlKey&&event.shiftKey&&event.altKey&&event.metaKey);
  const original=JSON.stringify([event.type,event.isTrusted,event.view===window,event.detail,event.screenX,event.screenY,event.clientX,event.clientY,event.button,event.buttons,event.timeStamp]);
  const mouseReturn=event.initMouseEvent("ignored during dispatch",false,false,null,99,1,2,3,4,false,false,false,false,0,null),uiReturn=event.initUIEvent("also ignored",false,false,null,100);
  dragOwnerChecks.push(mouseReturn===undefined&&uiReturn===undefined&&event.dataTransfer===dragOwnerTransfer&&JSON.stringify([event.type,event.isTrusted,event.view===window,event.detail,event.screenX,event.screenY,event.clientX,event.clientY,event.button,event.buttons,event.timeStamp])===original);
  if(dragOwnerCancel)event.preventDefault();
 });
 player.addEventListener("dragover",function(event){dragOwnerOrder.push("after");dragOwnerChecks.push(this===player&&event.currentTarget===player&&event.defaultPrevented===dragOwnerCancel&&window.event===event);result.textContent=dragOwnerOrder.join(",")});
}
document.body.appendChild(dragAudio);void dragAudio.paused;0
')!
	assert voidptr(document.get_element_by_id('drag-audio')?) == voidptr(created_target)
	mut app := drag_event_owner_app(owner, document, runtime)
	for id in ['video', 'drag-audio'] {
		target := document.get_element_by_id(id)?
		related := document.get_element_by_id(if id == 'video' { 'drag-audio' } else { 'video' })?
		for cancel in [false, true] {
			runtime.evaluate_host('dragOwnerOrder=[];dragOwnerSaved=[];dragOwnerTrusted=true;dragOwnerCancel=${cancel};0')!
			drag := html.DragEvent.create('dragover', html.DragEventInit{
				MouseEventInit: dom.MouseEventInit{
					EventModifierInit: dom.EventModifierInit{
						UIEventInit: dom.UIEventInit{
							EventInit: dom.EventInit{
								bubbles:    true
								cancelable: true
								composed:   true
							}
							view:      voidptr(document.get_window()?)
							detail:    7
						}
						ctrl_key:    true
						shift_key:   true
						alt_key:     true
						meta_key:    true
					}
					screen_x:          111.25
					screen_y:          221.75
					client_x:          11.5
					client_y:          21.125
					button:            2
					buttons:           2
					related_target:    unsafe { &dom.EventTarget(related) }
				}
				data_transfer:  transfer
			}, 31.5, 41.125, 1.75, 2.625)
			event := unsafe { &dom.Event(drag) }
			stamp := event.time_stamp()
			assert dom.event_target_dispatch_event(unsafe { &dom.EventTarget(target) }, event) == !cancel
			assert runtime.evaluate_host('dragOwnerOrder.join(",")==="before,payload,after"&&dragOwnerSaved.length===1&&dragOwnerChecks.every(Boolean)&&dragOwnerSaved[0].isTrusted&&dragOwnerSaved[0].screenX===111.25&&dragOwnerSaved[0].clientX===11.5&&dragOwnerSaved[0].pageX===31.5&&dragOwnerSaved[0].offsetX===1.75&&dragOwnerSaved[0].defaultPrevented===dragOwnerCancel&&dragOwnerSaved[0].currentTarget===null&&dragOwnerSaved[0].eventPhase===Event.NONE&&window.event===undefined')! == 'true'
			wrapper := runtime.evaluate_host_value('dragOwnerSaved[0]')!
			assert runtime.native_event(wrapper)! == event
			assert runtime.javascript_event(event)! == wrapper
			assert event.is_trusted() && event.default_prevented() == cancel
			assert voidptr(event.target()?) == voidptr(target)
			assert drag.data_transfer()? == transfer && transfer.get_data('text') == 'factory owner payload'
			assert drag_event_owner_record_matches(mut runtime, 'dragOwnerSaved[0]')!
			app.poll_javascript_tasks()
			assert document.get_element_by_id('result')?.as_node().text_content()? == 'before,payload,after'
			assert !app.dispatch_javascript_event('dragover', target)
			assert runtime.evaluate_host('dragOwnerOrder.length===3&&dragOwnerSaved.length===1')! == 'true'
			// Source dispatchEvent changes trust and inherited Mouse geometry,
			// while preserving the exact Drag payload, timestamp and wrapper.
			assert runtime.evaluate_host(r'(()=>{dragOwnerTrusted=false;const event=dragOwnerSaved[0],player=event.target,stamp=event.timeStamp;return player.dispatchEvent(event)===!dragOwnerCancel&&dragOwnerSaved.length===2&&dragOwnerSaved[1]===event&&!event.isTrusted&&event.screenX===111&&event.clientX===11&&event.pageX===31&&event.offsetX===1&&event.dataTransfer===dragOwnerTransfer&&event.timeStamp===stamp&&dragOwnerChecks.every(Boolean)&&event.currentTarget===null&&window.event===undefined})()')! == 'true'
			assert runtime.native_event(runtime.evaluate_host_value('dragOwnerSaved[1]')!)! == event
			assert event.time_stamp() == stamp && drag.data_transfer()? == transfer
			assert drag_event_owner_record_matches(mut runtime, 'dragOwnerSaved[1]')!
			app.poll_javascript_tasks()
			assert document.get_element_by_id('result')?.as_node().text_content()? == 'before,payload,after,before,payload,after'
			assert !app.dispatch_javascript_event('dragover', target)
			assert runtime.evaluate_host('dragOwnerOrder.length===6&&dragOwnerSaved.length===2')! == 'true'
		}
	}
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert app.js_messages == [] && !runtime.libjs_vm().has_running_execution_context()
}

fn test_constructed_owner_drag_dispatch_retains_transfer_through_inherited_initializers() {
	$if !darwin {
		return
	}
	mut owner, mut document :=
		drag_event_owner_document('http://drag-event-constructor-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.constructedDragAudio=document.createElement("audio");constructedDragAudio.id="constructed-drag-audio";0',
	], runtime, mut messages)
	assert messages == []
	assert drag_event_owner_guard(runtime)!
	mut transfer := html.DataTransfer.construct()
	transfer.set_data('text', 'constructor owner payload')
	drag_event_owner_export(mut runtime, '__ownerConstructorDragTransfer',
		runtime.javascript_data_transfer(transfer)!)!
	runtime.evaluate_host(r'
globalThis.constructedDragTransfer=__ownerConstructorDragTransfer();globalThis.constructedDragEvents=[];globalThis.constructedDragSaved=[];globalThis.constructedDragChecks=[];globalThis.constructedDragOrder=[];globalThis.constructedDragCancel=true;globalThis.constructedDragDetail=7;globalThis.constructedDragButton=1;
for(const player of [video,constructedDragAudio]){
 player.addEventListener("drop",function(event){
  constructedDragOrder.push(player.id);constructedDragSaved.push(event);
  constructedDragChecks.push(this===player&&arguments.length===1&&event instanceof DragEvent&&event instanceof MouseEvent&&event instanceof UIEvent&&event instanceof Event&&!(event instanceof PointerEvent)&&!(event instanceof WheelEvent)&&Object.getPrototypeOf(event)===DragEvent.prototype&&Object.prototype.toString.call(event)==="[object DragEvent]"&&!event.isTrusted&&event.type==="drop"&&event.view===window&&event.detail===constructedDragDetail&&event.button===constructedDragButton&&event.which===constructedDragButton+1&&event.buttons===4&&event.bubbles&&event.cancelable&&event.composed&&event.target===player&&event.currentTarget===player&&window.event===event&&event.dataTransfer===constructedDragTransfer&&event.relatedTarget===(player===video?constructedDragAudio:video));
  if(constructedDragCancel)event.preventDefault();result.textContent=constructedDragOrder.join(",");
 });
}
document.body.appendChild(constructedDragAudio);void constructedDragAudio.paused;
for(const player of [video,constructedDragAudio]){
 const related=player===video?constructedDragAudio:video;
 const event=new DragEvent("drop",{bubbles:true,cancelable:true,composed:true,view:window,detail:7,button:1,buttons:4,clientX:9.75,clientY:-2.25,screenX:100.625,screenY:200.875,movementX:1.25,movementY:-2.75,ctrlKey:true,shiftKey:true,relatedTarget:related,dataTransfer:constructedDragTransfer});
 const stamp=event.timeStamp;constructedDragEvents.push(event);constructedDragDetail=7;constructedDragButton=1;constructedDragCancel=true;
 constructedDragChecks.push(!event.isTrusted&&stamp>=0&&stamp<10000&&event.target===null&&event.dataTransfer===constructedDragTransfer&&player.dispatchEvent(event)===false&&event.defaultPrevented&&event.currentTarget===null&&event.eventPhase===Event.NONE&&event.clientX===9&&event.clientY===-3&&event.pageX===9&&event.offsetY===-3&&event.relatedTarget===related&&window.event===undefined);
 const returned=event.initMouseEvent("drop",true,true,window,11,101,202,13,24,true,false,true,true,2,related);
 constructedDragChecks.push(returned===undefined&&event.dataTransfer===constructedDragTransfer&&event.timeStamp===stamp&&event.target===null&&!event.defaultPrevented&&!event.isTrusted&&event.clientX===13&&event.clientY===24&&event.pageX===9&&event.offsetY===-3&&event.button===2&&event.buttons===4&&event.movementX===1.25&&event.movementY===-2.75&&event.getModifierState("Control")&&event.getModifierState("Shift")&&event.getModifierState("Meta")&&!event.getModifierState("Alt")&&event.relatedTarget===related);
 event.initUIEvent("drop",true,true,window,12);constructedDragDetail=12;constructedDragButton=2;constructedDragCancel=false;
 constructedDragChecks.push(event.dataTransfer===constructedDragTransfer&&event.timeStamp===stamp&&event.detail===12&&event.clientX===13&&event.buttons===4&&player.dispatchEvent(event)&&!event.defaultPrevented&&event.currentTarget===null&&window.event===undefined);
}
0
')!
	assert runtime.evaluate_host('constructedDragEvents.length===2&&constructedDragSaved.length===4&&constructedDragSaved[0]===constructedDragEvents[0]&&constructedDragSaved[1]===constructedDragEvents[0]&&constructedDragSaved[2]===constructedDragEvents[1]&&constructedDragSaved[3]===constructedDragEvents[1]&&constructedDragChecks.every(Boolean)&&constructedDragOrder.join(",")==="video,video,constructed-drag-audio,constructed-drag-audio"')! == 'true'
	for index in 0 .. 2 {
		assert drag_event_owner_record_matches(mut runtime, 'constructedDragEvents[${index}]')!
		event :=
			runtime.native_event(runtime.evaluate_host_value('constructedDragEvents[${index}]')!)!
		assert event.interface_ == .drag_event && !event.is_trusted()
		drag := unsafe { &html.DragEvent(event) }
		assert drag.data_transfer()? == transfer
		assert transfer.get_data('text') == 'constructor owner payload'
		target := document.get_element_by_id(if index == 0 {
			'video'
		} else {
			'constructed-drag-audio'
		})?
		assert voidptr(event.target()?) == voidptr(target)
	}
	mut app := drag_event_owner_app(owner, document, runtime)
	app.poll_javascript_tasks()
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'video,video,constructed-drag-audio,constructed-drag-audio'
	for id in ['video', 'constructed-drag-audio'] {
		assert !app.dispatch_javascript_event('drop', document.get_element_by_id(id)?)
	}
	assert runtime.evaluate_host('constructedDragSaved.length===4&&constructedDragChecks.every(Boolean)')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert !settings.is_secure_context()
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert app.js_messages == [] && !runtime.libjs_vm().has_running_execution_context()
}
