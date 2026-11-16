// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import html
import dom
import libjs
import os
import rand

fn mouse_binding_fixture() !(&Host, &libjs.VM) {
	document := html.parse_document_with_url('<body><button id="button">button</button></body>', dom.URL{ value: 'https://mouse_events.test/' })
	_ = html.WindowModel.create_top_level(document, none, 'mouse_binding')!
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	host := Host.create(vm, vm.realm(), document, Hooks{})!
	return host, vm
}

fn mouse_binding_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'mouse_events.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{ max_instructions: 100000 }) or { return error(exception_message(err)) }
}

fn test_mouse_event_dictionary_properties_modifiers_and_native_subclass_identity() {
	mut host, mut vm := mouse_binding_fixture()!
	defer { host.close() }
	assert mouse_binding_eval(mut vm, 'class Click extends MouseEvent{}var event=new Click("click",{view:window,detail:3,clientX:12.5,clientY:-2.25,screenX:23.5,movementX:1.75,button:65535,buttons:65537,ctrlKey:true,modifierCapsLock:true,relatedTarget:document.body,bubbles:true});event instanceof Click&&event instanceof MouseEvent&&event instanceof UIEvent&&event instanceof Event&&event.view===window&&event.detail===3&&event.clientX===12.5&&event.x===12.5&&event.clientY===-2.25&&event.pageX===12.5&&event.offsetY===-2.25&&event.screenX===23.5&&event.movementX===1.75&&event.button===-1&&event.buttons===1&&event.ctrlKey&&event.getModifierState("Control")&&event.getModifierState("CapsLock")&&!event.getModifierState("unknown")&&event.relatedTarget===document.body&&!event.isTrusted&&Object.getPrototypeOf(MouseEvent)===UIEvent&&Object.prototype.toString.call(event)==="[object MouseEvent]"')!.as_bool()
	assert mouse_binding_eval(mut vm, 'var event=new MouseEvent("before");event.initMouseEvent("after",true,true,window,4,1,2,3,4,true,false,true,false,2,document.body);event.type==="after"&&event.detail===4&&event.clientX===3&&event.clientY===4&&event.ctrlKey&&event.shiftKey&&event.button===2&&event.relatedTarget===document.body')!.as_bool()
}

fn test_mouse_event_dictionary_order_finite_coordinates_and_brand_errors() {
	mut host, mut vm := mouse_binding_fixture()!
	defer { host.close() }
	assert mouse_binding_eval(mut vm, 'var names=[],options=new Proxy({},{get(target,name){names.push(name);return undefined}});new MouseEvent("x",options);names.join()=== "bubbles,cancelable,composed,detail,view,altKey,ctrlKey,metaKey,modifierAltGraph,modifierCapsLock,modifierFn,modifierFnLock,modifierHyper,modifierNumLock,modifierScrollLock,modifierSuper,modifierSymbol,modifierSymbolLock,shiftKey,button,buttons,clientX,clientY,movementX,movementY,relatedTarget,screenX,screenY"')!.as_bool()
	assert mouse_binding_eval(mut vm, 'var count=0;for(var run of [()=>MouseEvent("x"),()=>new MouseEvent(),()=>new MouseEvent("x",{clientX:NaN}),()=>new MouseEvent("x",{screenY:Infinity}),()=>new MouseEvent("x",{relatedTarget:{}}),()=>MouseEvent.prototype.getModifierState.call(new Event("x"),"Control")])try{run()}catch(error){if(error instanceof TypeError)count++}count===6')!.as_bool()
}

fn test_native_mouse_dispatch_keeps_its_trust_and_wrapped_ui_state() {
	mut host, mut vm := mouse_binding_fixture()!
	defer { host.close() }
	mouse_binding_eval(mut vm, 'var received=false,button=document.getElementById("button");button.addEventListener("click",event=>{received=event instanceof MouseEvent&&event instanceof UIEvent&&event.isTrusted&&event.clientX===12.5&&event.button===1&&event.ctrlKey&&event.composedPath()[0]===button})')!
	native := dom.MouseEvent.create('click', dom.MouseEventInit{ EventModifierInit: dom.EventModifierInit{ ctrl_key: true }, client_x: 12.5, button: 1 })
	target := unsafe { &dom.EventTarget(host.document.get_element_by_id('button')?) }
	dom.EventDispatcher.dispatch(target, unsafe { &dom.Event(native) }, false)
	assert mouse_binding_eval(mut vm, 'received')!.as_bool()
}

fn test_mouse_event_cached_execution_uses_each_new_document_owner() {
	directory := os.join_path(os.temp_dir(), 'vox-mouse-bindings-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm := mouse_binding_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 {
			'/usr/bin/clang'
		} else {
			'/usr/bin/false'
		})!
		vm.diagnose_native_code(true)!
		assert mouse_binding_eval(mut vm, 'var event=new MouseEvent("click",{relatedTarget:document.body,clientX:2.5,ctrlKey:true});event instanceof MouseEvent&&event.clientX===2.5&&event.relatedTarget===document.body&&event.getModifierState("Control")')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 {
			assert stats.cache_misses == 0 && stats.compiler_invocations == 0 && activity.entries > 0
		}
		vm.close_native_code()!
		host.close()
	}
}
