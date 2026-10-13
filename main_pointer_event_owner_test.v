module main

import browserjs
import dom
import html
import page
import time

fn pointer_event_owner_document(address string) !(&page.Page, &dom.Document) {
	mut owner := page.Page.create(1)!
	owner.set_enable_autoscroll(false)
	document := parse_browser_navigation_document_for_page_with_response_time('<video id="video"></video><div id="result">waiting</div>', dom.URL{
		value: address
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	return owner, document
}

fn pointer_event_owner_guard(runtime &browserjs.Runtime, secure bool) !bool {
	return runtime.evaluate_host('typeof PointerEvent==="function"&&Object.getPrototypeOf(PointerEvent.prototype)===MouseEvent.prototype&&typeof PointerEvent.prototype.getPredictedEvents==="function"&&Object.hasOwn(PointerEvent.prototype,"getCoalescedEvents")===${secure}')! == 'true'
}

fn pointer_event_owner_app(owner &page.Page, document &dom.Document, runtime &browserjs.Runtime) BrowserApp {
	return BrowserApp{
		page_model:       owner
		document:         document
		js_runtime:       runtime
		layout_tree_only: true
		viewport_width:   320
		viewport_height:  200
	}
}

// Page/offset data follows the real committed paint state. The helper observes
// those records without replacing Page geometry or claiming physical input.
fn pointer_event_owner_record_matches(mut runtime browserjs.Runtime, expression string) !bool {
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
		attributes := [f64(pointer.pointer_id()), pointer.width(),
			pointer.height(), f64(pointer.pressure()), f64(pointer.tangential_pressure()),
			f64(pointer.tilt_x()), f64(pointer.tilt_y()), f64(pointer.twist()), pointer.altitude_angle(),
			pointer.azimuth_angle(), f64(pointer.persistent_device_id())].map(it.str()).join(',')
		if runtime.evaluate_host('(()=>{const event=${expression};return Object.getPrototypeOf(event)===PointerEvent.prototype&&Object.prototype.toString.call(event)==="[object PointerEvent]"&&[event.pointerId,event.width,event.height,event.pressure,event.tangentialPressure,event.tiltX,event.tiltY,event.twist,event.altitudeAngle,event.azimuthAngle,event.persistentDeviceId].every((value,index)=>value===[${attributes}][index])&&event.pointerType==="${pointer.pointer_type()}"&&event.isPrimary===${pointer.is_primary()}})()')! != 'true' {
			return false
		}
		if pointer.get_coalesced_events().len != 0 || pointer.get_predicted_events().len != 0 {
			return false
		}
	} else if runtime.evaluate_host('!(${expression} instanceof PointerEvent)&&Object.getPrototypeOf(${expression})===MouseEvent.prototype&&Object.prototype.toString.call(${expression})==="[object MouseEvent]"')! != 'true' {
		return false
	}
	values << values[4]
	values << values[5]
	values << mouse.movement_x()
	values << mouse.movement_y()
	values << f64(mouse.button())
	values << f64(mouse.buttons())
	expected := values.map(it.str()).join(',')
	if runtime.evaluate_host('(()=>{const event=${expression};return [event.screenX,event.screenY,event.pageX,event.pageY,event.clientX,event.clientY,event.offsetX,event.offsetY,event.x,event.y,event.movementX,event.movementY,event.button,event.buttons].every((value,index)=>value===[${expected}][index])&&event.ctrlKey===${mouse.ctrl_key()}&&event.shiftKey===${mouse.shift_key()}&&event.altKey===${mouse.alt_key()}&&event.metaKey===${mouse.meta_key()}&&event.getModifierState("Shift")===${mouse.get_modifier_state('Shift')}})()')! != 'true' {
		return false
	}
	if related := event.related_target() {
		return runtime.evaluate_host_value('${expression}.relatedTarget')! == runtime.javascript_event_target(related,
			none)!
	}
	return runtime.evaluate_host('${expression}.relatedTarget===null')! == 'true'
}

fn test_secure_page_pointer_binding_keeps_native_subtype_movement_and_sequence_ownership() {
	$if !darwin { return }
	mut owner, mut document :=
		pointer_event_owner_document('https://pointer-event-movement-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.pointerAudio=document.createElement("audio");pointerAudio.id="pointer-audio";0',
	], runtime, mut messages)
	assert messages == []
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.is_secure_context()
	assert pointer_event_owner_guard(runtime, true)!
	assert document.get_element_by_id('pointer-audio') == none
	created_target := runtime.native_event_target(runtime.evaluate_host_value('pointerAudio')!)!
	runtime.evaluate_host(r'
globalThis.pointerOwnerOrder=[];globalThis.pointerOwnerSaved=[];globalThis.pointerOwnerChecks=[];globalThis.pointerHoverSaved=[];globalThis.pointerExpectedRelated=null;globalThis.pointerExpectedTrusted=true;globalThis.pointerExpectedButton=2;globalThis.pointerExpectedButtons=2;globalThis.cancelOwnerPointer=true;globalThis.cancelOwnerMouse=false;
globalThis.pointerPlatformFields=event=>event.pointerId===0&&event.width===1&&event.height===1&&event.pressure===0&&event.tangentialPressure===0&&event.tiltX===0&&event.tiltY===0&&event.twist===0&&event.altitudeAngle===Math.PI/2&&event.azimuthAngle===0&&event.pointerType==="mouse"&&event.isPrimary&&event.persistentDeviceId===0;
for(const player of [video,pointerAudio]){
 player.addEventListener("pointerover",function(event){pointerHoverSaved.push(event);pointerOwnerChecks.push(this===player&&event instanceof PointerEvent&&Object.getPrototypeOf(event)===PointerEvent.prototype&&event.isTrusted&&event.relatedTarget===pointerExpectedRelated&&window.event===event&&pointerPlatformFields(event))});
 for(const type of ["pointermove","mousemove"]){
  player.addEventListener(type,function(event){pointerOwnerOrder.push(type+":before");pointerOwnerChecks.push(this===player&&event.target===player&&event.currentTarget===player&&window.event===event)});
  player["on"+type]=function(event){pointerOwnerOrder.push(type+":handler");pointerOwnerSaved.push(event);pointerOwnerChecks.push(this===player&&arguments.length===1&&event instanceof MouseEvent&&event instanceof UIEvent&&event instanceof Event&&event.isTrusted===pointerExpectedTrusted&&event.type===type&&event.detail===0&&event.view===window&&event.button===pointerExpectedButton&&event.buttons===pointerExpectedButtons&&event.which===pointerExpectedButton+1&&event.target===player&&event.currentTarget===player&&event.relatedTarget===null&&window.event===event);
   if(type==="pointermove"){const coalesced=event.getCoalescedEvents(),predicted=event.getPredictedEvents();pointerOwnerChecks.push(event instanceof PointerEvent&&Object.getPrototypeOf(event)===PointerEvent.prototype&&Object.prototype.toString.call(event)==="[object PointerEvent]"&&pointerPlatformFields(event)&&Array.isArray(coalesced)&&Array.isArray(predicted)&&coalesced.length===0&&predicted.length===0&&coalesced!==event.getCoalescedEvents()&&predicted!==event.getPredictedEvents());coalesced.push(event);predicted.push(event);pointerOwnerChecks.push(event.getCoalescedEvents().length===0&&event.getPredictedEvents().length===0)}else pointerOwnerChecks.push(!(event instanceof PointerEvent)&&Object.getPrototypeOf(event)===MouseEvent.prototype);
   return(type==="pointermove"?cancelOwnerPointer:cancelOwnerMouse)?false:0;
  };
  player.addEventListener(type,function(event){pointerOwnerOrder.push(type+":after");pointerOwnerChecks.push(this===player&&event.currentTarget===player&&event.defaultPrevented===(type==="pointermove"?cancelOwnerPointer:cancelOwnerMouse)&&window.event===event);result.textContent=pointerOwnerOrder.join(",")});
 }
}
document.body.appendChild(pointerAudio);void pointerAudio.paused;0
')!
	assert voidptr(document.get_element_by_id('pointer-audio')?) == voidptr(created_target)
	mut app := pointer_event_owner_app(owner, document, runtime)
	for index, id in ['video', 'pointer-audio'] {
		target := document.get_element_by_id(id)?
		input := page.InputTarget.from_node(target.as_node())
		runtime.evaluate_host('pointerOwnerOrder=[];pointerOwnerSaved=[];pointerExpectedRelated=${if index == 0 {
			'null'
		} else {
			'video'
		}};pointerExpectedTrusted=true;pointerExpectedButton=2;pointerExpectedButtons=2;cancelOwnerPointer=true;cancelOwnerMouse=false;0')!
		assert owner.event_handler.handle_platform_pointer_event('pointermove', input, page.PixelPoint{11.5, 21.125}, page.PixelPoint{111.25, 221.75},
			2, 2, dom.modifier_shift | dom.modifier_alt, 0) == .handled
		assert runtime.evaluate_host('pointerOwnerSaved.length===2&&pointerOwnerSaved[0].screenX===111.25&&pointerOwnerSaved[0].clientX===11.5&&pointerOwnerSaved[0].x===11.5&&pointerOwnerSaved[0].defaultPrevented&&!pointerOwnerSaved[1].defaultPrevented')! == 'true'
		app.poll_javascript_tasks()
		assert document.get_element_by_id('result')?.as_node().text_content()? == 'pointermove:before,pointermove:handler,pointermove:after,mousemove:before,mousemove:handler,mousemove:after'
		runtime.evaluate_host('pointerExpectedButton=1;pointerExpectedButtons=4;cancelOwnerPointer=false;cancelOwnerMouse=true;0')!
		assert owner.event_handler.handle_platform_pointer_event('pointermove', input, page.PixelPoint{12.75, 22.5}, page.PixelPoint{112.875, 222.625},
			1, 4, dom.modifier_ctrl | dom.modifier_super, 0) == .cancelled
		assert runtime.evaluate_host('pointerOwnerSaved.length===4&&!pointerOwnerSaved[2].defaultPrevented&&pointerOwnerSaved[3].defaultPrevented&&pointerOwnerChecks.every(Boolean)&&window.event===undefined')! == 'true'
		for saved in 0 .. 4 {
			assert pointer_event_owner_record_matches(mut runtime, 'pointerOwnerSaved[${saved}]')!
		}
		// The same native Pointer record becomes untrusted through source JS
		// dispatchEvent; its move coordinates remain fractional by native type.
		assert runtime.evaluate_host(r'(()=>{pointerExpectedTrusted=false;cancelOwnerPointer=false;cancelOwnerMouse=false;const saved=pointerOwnerSaved[2];return saved.target.dispatchEvent(saved)&&pointerOwnerSaved.length===5&&pointerOwnerSaved[4]===saved&&!saved.isTrusted&&saved.clientX===12.75&&saved.screenX===112.875&&saved.x===12.75})()')! == 'true'
		assert pointer_event_owner_record_matches(mut runtime, 'pointerOwnerSaved[4]')!
		assert runtime.evaluate_host('pointerOwnerChecks.every(Boolean)&&pointerOwnerSaved.every(event=>event.currentTarget===null&&event.eventPhase===Event.NONE)&&window.event===undefined')! == 'true'
		app.poll_javascript_tasks()
		assert document.get_element_by_id('result')?.as_node().text_content()? == runtime.evaluate_host('pointerOwnerOrder.join(",")')!
		assert !app.dispatch_javascript_event('pointermove', target)
		assert !app.dispatch_javascript_event('mousemove', target)
		assert runtime.evaluate_host('pointerOwnerOrder.length===15&&pointerOwnerSaved.length===5')! == 'true'
	}
	assert runtime.evaluate_host('pointerHoverSaved.length===2&&pointerHoverSaved[0].relatedTarget===null&&pointerHoverSaved[1].relatedTarget===video&&pointerOwnerChecks.every(Boolean)')! == 'true'
	for saved in 0 .. 2 {
		assert pointer_event_owner_record_matches(mut runtime, 'pointerHoverSaved[${saved}]')!
	}
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert app.js_messages == [] && !runtime.libjs_vm().has_running_execution_context()
}

fn test_insecure_page_pointer_press_release_retains_mouse_click_family_and_single_delivery() {
	$if !darwin { return }
	mut owner, mut document :=
		pointer_event_owner_document('http://pointer-event-click-owner.example.test/')!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'globalThis.pointerClickAudio=document.createElement("audio");pointerClickAudio.id="pointer-click-audio";0',
	], runtime, mut messages)
	assert messages == []
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert !settings.is_secure_context()
	assert pointer_event_owner_guard(runtime, false)!
	runtime.evaluate_host(r'
globalThis.pointerClickOrder=[];globalThis.pointerClickSaved=[];globalThis.pointerClickChecks=[];globalThis.cancelPointerOwnerClick=false;
for(const player of [video,pointerClickAudio])for(const type of ["pointerdown","mousedown","pointerup","mouseup","click"]){
 player.addEventListener(type,function(event){pointerClickOrder.push(type+":before");pointerClickChecks.push(this===player&&event.currentTarget===player&&window.event===event)});
 player["on"+type]=function(event){pointerClickOrder.push(type+":handler");pointerClickSaved.push(event);const pointer=type.startsWith("pointer"),detail=pointer?0:1;pointerClickChecks.push(this===player&&arguments.length===1&&event instanceof MouseEvent&&event instanceof UIEvent&&event instanceof Event&&event.isTrusted&&event.type===type&&event.detail===detail&&event.view===window&&event.button===0&&event.which===1&&event.relatedTarget===null&&event.target===player&&event.currentTarget===player&&window.event===event);
  if(pointer){const predicted=event.getPredictedEvents();pointerClickChecks.push(event instanceof PointerEvent&&Object.getPrototypeOf(event)===PointerEvent.prototype&&Object.prototype.toString.call(event)==="[object PointerEvent]"&&event.pointerId===0&&event.width===1&&event.height===1&&event.pressure===0&&event.tangentialPressure===0&&event.tiltX===0&&event.tiltY===0&&event.twist===0&&event.altitudeAngle===Math.PI/2&&event.azimuthAngle===0&&event.pointerType==="mouse"&&event.isPrimary&&event.persistentDeviceId===0&&!("getCoalescedEvents" in event)&&Array.isArray(predicted)&&predicted.length===0&&predicted!==event.getPredictedEvents())}else pointerClickChecks.push(!(event instanceof PointerEvent)&&Object.getPrototypeOf(event)===MouseEvent.prototype&&Object.prototype.toString.call(event)==="[object MouseEvent]");
  if(type==="click"&&cancelPointerOwnerClick)return false;
 };
 player.addEventListener(type,function(event){pointerClickOrder.push(type+":after");pointerClickChecks.push(this===player&&event.currentTarget===player&&event.defaultPrevented===(type==="click"&&cancelPointerOwnerClick)&&window.event===event);result.textContent=pointerClickOrder.join(",")});
}
document.body.appendChild(pointerClickAudio);void pointerClickAudio.paused;0
')!
	mut app := pointer_event_owner_app(owner, document, runtime)
	for id in ['video', 'pointer-click-audio'] {
		target := document.get_element_by_id(id)?
		input := page.InputTarget.from_node(target.as_node())
		for cancel in [false, true] {
			runtime.evaluate_host('pointerClickOrder=[];pointerClickSaved=[];cancelPointerOwnerClick=${cancel};0')!
			assert owner.event_handler.handle_platform_pointer_event('pointerdown', input, page.PixelPoint{10.25, 20.75}, page.PixelPoint{110.5, 220.875},
				0, 1, dom.modifier_shift | dom.modifier_alt, 1) == .handled
			assert owner.event_handler.handle_platform_pointer_event('pointerup', input, page.PixelPoint{11.75, 21.25}, page.PixelPoint{111.875, 221.625},
				0, 0, dom.modifier_shift | dom.modifier_super, 1) == .handled
			assert owner.event_handler.last_click_allowed() == !cancel
			assert runtime.evaluate_host('pointerClickOrder.join(",")==="pointerdown:before,pointerdown:handler,pointerdown:after,mousedown:before,mousedown:handler,mousedown:after,pointerup:before,pointerup:handler,pointerup:after,mouseup:before,mouseup:handler,mouseup:after,click:before,click:handler,click:after"&&pointerClickSaved.length===5&&pointerClickChecks.every(Boolean)&&pointerClickSaved.slice(0,2).every(event=>event.screenX===110.5&&event.clientX===10.25&&event.buttons===1)&&pointerClickSaved.slice(2).every(event=>event.screenX===111.875&&event.clientX===11.75&&event.buttons===0)&&pointerClickSaved[4].defaultPrevented===cancelPointerOwnerClick&&pointerClickSaved.every(event=>event.currentTarget===null&&event.eventPhase===Event.NONE)&&window.event===undefined')! == 'true'
			for saved in 0 .. 5 {
				assert pointer_event_owner_record_matches(mut runtime,
					'pointerClickSaved[${saved}]')!
			}
			app.poll_javascript_tasks()
			assert document.get_element_by_id('result')?.as_node().text_content()? == runtime.evaluate_host('pointerClickOrder.join(",")')!
			assert !app.dispatch_javascript_event('click', target)
			assert owner.event_handler.take_last_click_event() == none
			assert runtime.evaluate_host('pointerClickOrder.length===15&&pointerClickSaved.length===5')! == 'true'
		}
	}
	assert settings.realm().reported_exceptions.len == 0
	assert settings.realm().script_execution_depth == 0
		&& settings.realm().callback_execution_depth == 0
	assert app.js_messages == [] && !runtime.libjs_vm().has_running_execution_context()
}
