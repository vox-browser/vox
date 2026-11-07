module main

import browserjs
import dom
import html
import page
import time

fn wheel_event_owner_document(address string) !(&page.Page, &dom.Document) {
	mut owner := page.Page.create(1)!
	owner.set_enable_autoscroll(false)
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="video"></video><div id="result">waiting</div>', dom.URL{
		value: address
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	return owner, document
}

fn wheel_event_owner_guard(runtime &browserjs.Runtime) !bool {
	return runtime.evaluate_host(r'typeof WheelEvent==="function"&&Object.getPrototypeOf(WheelEvent.prototype)===MouseEvent.prototype&&["deltaX","deltaY","deltaZ","deltaMode","wheelDeltaX","wheelDeltaY","wheelDelta"].every(name=>{const descriptor=Object.getOwnPropertyDescriptor(WheelEvent.prototype,name);return !!descriptor&&typeof descriptor.get==="function"&&Function.prototype.toString.call(descriptor.get).includes("[native code]")})&&WheelEvent.DOM_DELTA_PIXEL===0&&WheelEvent.DOM_DELTA_LINE===1&&WheelEvent.DOM_DELTA_PAGE===2')! == 'true'
}

fn wheel_event_owner_app(owner &page.Page, document &dom.Document, runtime &browserjs.Runtime) BrowserApp {
	return BrowserApp{
		page_model:       owner
		document:         document
		js_runtime:       runtime
		layout_tree_only: true
		viewport_width:   320
		viewport_height:  200
	}
}

fn wheel_event_owner_record_matches(mut runtime browserjs.Runtime, expression string) !bool {
	wrapper := runtime.evaluate_host_value(expression)!
	event := runtime.native_event(wrapper)!
	if event.interface_ != .wheel_event || runtime.javascript_event(event)! != wrapper {
		return false
	}
	wheel := unsafe { &dom.WheelEvent(event) }
	mouse := unsafe { &dom.MouseEvent(event) }
	values := [wheel.delta_x(), wheel.delta_y(), wheel.delta_z(), f64(wheel.delta_mode()),
		f64(wheel.wheel_delta_x()), f64(wheel.wheel_delta_y()), f64(wheel.wheel_delta()),
		mouse.screen_x(), mouse.screen_y(), mouse.page_x(), mouse.page_y(),
		mouse.client_x(), mouse.client_y(), mouse.offset_x(),
		mouse.offset_y(), mouse.x(), mouse.y(), mouse.movement_x(),
		mouse.movement_y(), f64(mouse.button()), f64(mouse.buttons())]
	expected := values.map(it.str()).join(',')
	if runtime.evaluate_host('(()=>{const event=${expression};return Object.getPrototypeOf(event)===WheelEvent.prototype&&Object.prototype.toString.call(event)==="[object WheelEvent]"&&event instanceof WheelEvent&&event instanceof MouseEvent&&event instanceof UIEvent&&event instanceof Event&&!(event instanceof PointerEvent)&&[event.deltaX,event.deltaY,event.deltaZ,event.deltaMode,event.wheelDeltaX,event.wheelDeltaY,event.wheelDelta,event.screenX,event.screenY,event.pageX,event.pageY,event.clientX,event.clientY,event.offsetX,event.offsetY,event.x,event.y,event.movementX,event.movementY,event.button,event.buttons].every((value,index)=>value===[${expected}][index])&&event.ctrlKey===${mouse.ctrl_key()}&&event.shiftKey===${mouse.shift_key()}&&event.altKey===${mouse.alt_key()}&&event.metaKey===${mouse.meta_key()}&&event.getModifierState("Control")===${mouse.get_modifier_state('Control')}&&event.getModifierState("Shift")===${mouse.get_modifier_state('Shift')}})()')! != 'true' {
		return false
	}
	if related := event.related_target() {
		return runtime.evaluate_host_value('${expression}.relatedTarget')! == runtime.javascript_event_target(related,
			none)!
	}
	return runtime.evaluate_host('${expression}.relatedTarget===null')! == 'true'
}

// Page's current wheel entry points retain routing metadata without dispatching
// a DOM WheelEvent. Exercise the translated native platform factory and actual
// owner dispatch directly; this does not claim Cocoa/Page wheel delivery or
// default scrolling behavior.
fn test_native_platform_wheel_factory_keeps_owner_identity_fields_and_cancellation() {
	$if !darwin {
		return
	}
	mut owner, mut document :=
		wheel_event_owner_document('https://wheel-event-platform-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.wheelAudio=document.createElement("audio");wheelAudio.id="wheel-audio";0',
	], runtime, mut messages)
	assert messages == []
	assert wheel_event_owner_guard(runtime)!
	assert document.get_element_by_id('wheel-audio') == none
	created_target := runtime.native_event_target(runtime.evaluate_host_value('wheelAudio')!)!
	runtime.evaluate_host(r'
globalThis.wheelOwnerOrder=[];globalThis.wheelOwnerSaved=[];globalThis.wheelOwnerChecks=[];globalThis.wheelOwnerTrusted=true;globalThis.wheelOwnerCancel=false;
for(const player of [video,wheelAudio]){
 player.addEventListener("wheel",function(event){wheelOwnerOrder.push("before");wheelOwnerChecks.push(this===player&&event.target===player&&event.currentTarget===player&&window.event===event)});
 player.addEventListener("wheel",function(event){
  wheelOwnerOrder.push("payload");wheelOwnerSaved.push(event);
  wheelOwnerChecks.push(this===player&&arguments.length===1&&event instanceof WheelEvent&&event instanceof MouseEvent&&event instanceof UIEvent&&event instanceof Event&&!(event instanceof PointerEvent)&&Object.getPrototypeOf(event)===WheelEvent.prototype&&Object.prototype.toString.call(event)==="[object WheelEvent]"&&event.type==="wheel"&&event.isTrusted===wheelOwnerTrusted&&event.bubbles&&event.cancelable&&event.composed&&event.view===window&&event.detail===0&&event.which===3&&event.button===2&&event.buttons===2&&event.relatedTarget===null&&event.target===player&&event.currentTarget===player&&window.event===event&&event.deltaX===2.5&&event.deltaY===-3.6&&event.deltaZ===0&&event.deltaMode===event.DOM_DELTA_PIXEL&&event.wheelDeltaX===-2&&event.wheelDeltaY===4&&event.wheelDelta===4&&event.ctrlKey&&event.shiftKey&&event.altKey&&event.metaKey);
  const original=JSON.stringify([event.type,event.isTrusted,event.view===window,event.detail,event.screenX,event.screenY,event.clientX,event.clientY,event.button,event.buttons,event.deltaX,event.deltaY,event.deltaZ,event.deltaMode,event.wheelDeltaX,event.wheelDeltaY,event.wheelDelta]);
  const returned=event.initMouseEvent("ignored during dispatch",false,false,null,99,1,2,3,4,false,false,false,false,0,null);
  wheelOwnerChecks.push(returned===undefined&&JSON.stringify([event.type,event.isTrusted,event.view===window,event.detail,event.screenX,event.screenY,event.clientX,event.clientY,event.button,event.buttons,event.deltaX,event.deltaY,event.deltaZ,event.deltaMode,event.wheelDeltaX,event.wheelDeltaY,event.wheelDelta])===original);
  if(wheelOwnerCancel)event.preventDefault();
 });
 player.addEventListener("wheel",function(event){wheelOwnerOrder.push("after");wheelOwnerChecks.push(this===player&&event.currentTarget===player&&event.defaultPrevented===wheelOwnerCancel&&window.event===event);result.textContent=wheelOwnerOrder.join(",")});
}
document.body.appendChild(wheelAudio);void wheelAudio.paused;0
')!
	assert voidptr(document.get_element_by_id('wheel-audio')?) == voidptr(created_target)
	mut app := wheel_event_owner_app(owner, document, runtime)
	for id in ['video', 'wheel-audio'] {
		target := document.get_element_by_id(id)?
		for cancel in [false, true] {
			runtime.evaluate_host('wheelOwnerOrder=[];wheelOwnerSaved=[];wheelOwnerTrusted=true;wheelOwnerCancel=${cancel};0')!
			wheel := dom.WheelEvent.create_from_platform_event(voidptr(document.get_window()?),
				'wheel', dom.CSSPixelPoint_{111.25, 221.75}, dom.CSSPixelPoint_{31.5, 41.125}, dom.CSSPixelPoint_{11.5, 21.125}, dom.CSSPixelPoint_{1.75, 2.625},
				2.5, -3.6, 2, 2,
				dom.modifier_ctrl | dom.modifier_shift | dom.modifier_alt | dom.modifier_super)
			event := unsafe { &dom.Event(wheel) }
			assert dom.event_target_dispatch_event(unsafe { &dom.EventTarget(target) }, event) == !cancel
			assert runtime.evaluate_host('wheelOwnerOrder.join(",")==="before,payload,after"&&wheelOwnerSaved.length===1&&wheelOwnerChecks.every(Boolean)&&wheelOwnerSaved[0].isTrusted&&wheelOwnerSaved[0].screenX===111.25&&wheelOwnerSaved[0].clientX===11.5&&wheelOwnerSaved[0].pageX===31.5&&wheelOwnerSaved[0].offsetX===1.75&&wheelOwnerSaved[0].defaultPrevented===wheelOwnerCancel&&wheelOwnerSaved[0].currentTarget===null&&wheelOwnerSaved[0].eventPhase===Event.NONE&&window.event===undefined')! == 'true'
			wrapper := runtime.evaluate_host_value('wheelOwnerSaved[0]')!
			assert runtime.native_event(wrapper)! == event
			assert runtime.javascript_event(event)! == wrapper
			assert event.is_trusted() && event.default_prevented() == cancel
			assert voidptr(event.target()?) == voidptr(target)
			assert wheel_event_owner_record_matches(mut runtime, 'wheelOwnerSaved[0]')!
			app.poll_javascript_tasks()
			assert document.get_element_by_id('result')?.as_node().text_content()? == 'before,payload,after'
			assert !app.dispatch_javascript_event('wheel', target)
			assert runtime.evaluate_host('wheelOwnerOrder.length===3&&wheelOwnerSaved.length===1')! == 'true'
			// JavaScript redispatch retains the native record and Wheel slots while
			// MouseEvent's inherited geometry becomes untrusted and floored.
			assert runtime.evaluate_host(r'(()=>{wheelOwnerTrusted=false;const event=wheelOwnerSaved[0],player=event.target;return player.dispatchEvent(event)===!wheelOwnerCancel&&wheelOwnerSaved.length===2&&wheelOwnerSaved[1]===event&&!event.isTrusted&&event.screenX===111&&event.clientX===11&&event.pageX===31&&event.offsetX===1&&event.deltaX===2.5&&event.deltaY===-3.6&&event.wheelDeltaX===-2&&event.wheelDeltaY===4&&wheelOwnerChecks.every(Boolean)&&event.currentTarget===null&&window.event===undefined})()')! == 'true'
			assert runtime.native_event(runtime.evaluate_host_value('wheelOwnerSaved[1]')!)! == event
			assert wheel_event_owner_record_matches(mut runtime, 'wheelOwnerSaved[1]')!
			app.poll_javascript_tasks()
			assert document.get_element_by_id('result')?.as_node().text_content()? == 'before,payload,after,before,payload,after'
			assert !app.dispatch_javascript_event('wheel', target)
			assert runtime.evaluate_host('wheelOwnerOrder.length===6&&wheelOwnerSaved.length===2')! == 'true'
		}
	}
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert app.js_messages == [] && !runtime.libjs_vm().has_running_execution_context()
}

fn test_constructed_owner_wheel_dispatch_preserves_own_slots_through_inherited_legacy_initializers() {
	$if !darwin {
		return
	}
	mut owner, mut document :=
		wheel_event_owner_document('http://wheel-event-constructor-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.constructedWheelAudio=document.createElement("audio");constructedWheelAudio.id="constructed-wheel-audio";0',
	], runtime, mut messages)
	assert messages == []
	assert wheel_event_owner_guard(runtime)!
	runtime.evaluate_host(r'
globalThis.constructedWheelEvents=[];globalThis.constructedWheelSaved=[];globalThis.constructedWheelChecks=[];globalThis.constructedWheelOrder=[];globalThis.constructedWheelCancel=true;globalThis.constructedWheelDetail=7;globalThis.constructedWheelButton=1;
const wheelSlots=event=>[event.deltaX,event.deltaY,event.deltaZ,event.deltaMode,event.wheelDeltaX,event.wheelDeltaY,event.wheelDelta].join(",");
for(const player of [video,constructedWheelAudio]){
 player.addEventListener("wheel",function(event){
  constructedWheelOrder.push(player.id);constructedWheelSaved.push(event);
  constructedWheelChecks.push(this===player&&arguments.length===1&&event instanceof WheelEvent&&event instanceof MouseEvent&&event instanceof UIEvent&&event instanceof Event&&Object.getPrototypeOf(event)===WheelEvent.prototype&&!event.isTrusted&&event.type==="wheel"&&event.view===window&&event.detail===constructedWheelDetail&&event.button===constructedWheelButton&&event.which===constructedWheelButton+1&&event.buttons===4&&event.bubbles&&event.cancelable&&event.composed&&event.target===player&&event.currentTarget===player&&window.event===event&&wheelSlots(event)==="0,0,1.25,3,120,-240,-240"&&event.relatedTarget===(player===video?constructedWheelAudio:video));
  if(constructedWheelCancel)event.preventDefault();result.textContent=constructedWheelOrder.join(",");
 });
}
document.body.appendChild(constructedWheelAudio);void constructedWheelAudio.paused;
for(const player of [video,constructedWheelAudio]){
 const related=player===video?constructedWheelAudio:video;
 const event=new WheelEvent("wheel",{bubbles:true,cancelable:true,composed:true,view:window,detail:7,button:1,buttons:4,clientX:9.75,clientY:-2.25,screenX:100.625,screenY:200.875,movementX:1.25,movementY:-2.75,ctrlKey:true,shiftKey:true,relatedTarget:related,deltaX:0,deltaY:0,deltaZ:1.25,deltaMode:3,wheelDeltaX:120,wheelDeltaY:-240});
 constructedWheelEvents.push(event);constructedWheelDetail=7;constructedWheelButton=1;constructedWheelCancel=true;
 constructedWheelChecks.push(player.dispatchEvent(event)===false&&event.defaultPrevented&&event.currentTarget===null&&event.eventPhase===Event.NONE&&event.clientX===9&&event.clientY===-3&&event.pageX===9&&event.offsetY===-3&&event.relatedTarget===related&&window.event===undefined);
 const slots=wheelSlots(event);const returned=event.initMouseEvent("wheel",true,true,window,11,101,202,13,24,true,false,true,true,2,related);
 constructedWheelChecks.push(returned===undefined&&wheelSlots(event)===slots&&event.target===null&&!event.defaultPrevented&&!event.isTrusted&&event.clientX===13&&event.clientY===24&&event.pageX===9&&event.offsetY===-3&&event.button===2&&event.buttons===4&&event.movementX===1.25&&event.movementY===-2.75&&event.getModifierState("Control")&&event.getModifierState("Shift")&&event.getModifierState("Meta")&&!event.getModifierState("Alt")&&event.relatedTarget===related);
 event.initUIEvent("wheel",true,true,window,12);constructedWheelDetail=12;constructedWheelButton=2;constructedWheelCancel=false;
 constructedWheelChecks.push(wheelSlots(event)===slots&&event.detail===12&&event.clientX===13&&event.buttons===4&&player.dispatchEvent(event)&&!event.defaultPrevented&&event.currentTarget===null&&window.event===undefined);
}
0
')!
	assert runtime.evaluate_host('constructedWheelEvents.length===2&&constructedWheelSaved.length===4&&constructedWheelSaved[0]===constructedWheelEvents[0]&&constructedWheelSaved[1]===constructedWheelEvents[0]&&constructedWheelSaved[2]===constructedWheelEvents[1]&&constructedWheelSaved[3]===constructedWheelEvents[1]&&constructedWheelChecks.every(Boolean)&&constructedWheelOrder.join(",")==="video,video,constructed-wheel-audio,constructed-wheel-audio"')! == 'true'
	for index in 0 .. 2 {
		assert wheel_event_owner_record_matches(mut runtime, 'constructedWheelEvents[${index}]')!
		event :=
			runtime.native_event(runtime.evaluate_host_value('constructedWheelEvents[${index}]')!)!
		assert event.interface_ == .wheel_event && !event.is_trusted()
		target := document.get_element_by_id(if index == 0 {
			'video'
		} else {
			'constructed-wheel-audio'
		})?
		assert voidptr(event.target()?) == voidptr(target)
	}
	mut app := wheel_event_owner_app(owner, document, runtime)
	app.poll_javascript_tasks()
	assert document.get_element_by_id('result')?.as_node().text_content()? == 'video,video,constructed-wheel-audio,constructed-wheel-audio'
	for id in ['video', 'constructed-wheel-audio'] {
		assert !app.dispatch_javascript_event('wheel', document.get_element_by_id(id)?)
	}
	assert runtime.evaluate_host('constructedWheelSaved.length===4&&constructedWheelChecks.every(Boolean)')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert !settings.is_secure_context()
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert app.js_messages == [] && !runtime.libjs_vm().has_running_execution_context()
}
