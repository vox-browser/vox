// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import libjs
import html
import dom

fn keyboard_binding_fixture() !(&Host, &libjs.VM) {
	document := html.parse_document_with_url('<body><button id="button">button</button></body>', dom.URL{ value: 'https://keyboard_events.test/' })
	_ = html.WindowModel.create_top_level(document, none, 'keyboard_binding')!
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	host := Host.create(vm, vm.realm(), document, Hooks{})!
	return host, vm
}

fn keyboard_binding_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'keyboard_events.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{ max_instructions: 100000 }) or { return error(exception_message(err)) }
}

fn test_keyboard_event_uses_native_keys_modifiers_and_ui_event_inheritance() {
	mut host, mut vm := keyboard_binding_fixture()!
	defer { host.close() }
	assert keyboard_binding_eval(mut vm, 'class Key extends KeyboardEvent{}var e=new Key("keydown",{key:"Escape",code:"Escape",location:4294967298,keyCode:27,charCode:9,ctrlKey:true,modifierCapsLock:true,repeat:true,isComposing:true,view:window});e instanceof Key&&e instanceof KeyboardEvent&&e instanceof UIEvent&&e instanceof Event&&e.key==="Escape"&&e.code==="Escape"&&e.location===2&&e.keyCode===27&&e.which===27&&e.charCode===9&&e.ctrlKey&&e.repeat&&e.isComposing&&e.getModifierState("Control")&&e.getModifierState("CapsLock")&&e.view===window&&!e.isTrusted&&Object.getPrototypeOf(KeyboardEvent)===UIEvent&&KeyboardEvent.DOM_KEY_LOCATION_NUMPAD===3&&Object.prototype.toString.call(e)==="[object KeyboardEvent]"')!.as_bool()
	assert keyboard_binding_eval(mut vm, 'var e=new KeyboardEvent("before");e.initKeyboardEvent("after",true,true,window,"a",1,true,false,true,false);e.type==="after"&&e.key==="a"&&e.location===1&&e.ctrlKey&&e.shiftKey&&e.bubbles&&e.cancelable')!.as_bool()
}

fn test_platform_keyboard_event_wraps_the_actual_key_for_dom_listeners() {
	mut host, mut vm := keyboard_binding_fixture()!
	defer { host.close() }
	keyboard_binding_eval(mut vm, 'var observed=false;document.addEventListener("keydown",e=>{observed=e instanceof KeyboardEvent&&e.key==="Escape"&&e.code==="Escape"&&e.keyCode===27&&e.isTrusted})')!
	native := dom.KeyboardEvent.create('keydown', dom.KeyboardEventInit{ key: 'Escape', code: 'Escape', key_code: 27 })
	dom.EventDispatcher.dispatch(unsafe { &dom.EventTarget(host.document) }, unsafe { &dom.Event(native) }, false)
	assert keyboard_binding_eval(mut vm, 'observed')!.as_bool()
}
