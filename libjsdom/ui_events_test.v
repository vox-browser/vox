// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs

fn ui_binding_fixture() !(&Host, &libjs.VM) {
	document := html.parse_document_with_url('<body><button id="button">button</button></body>', dom.URL{ value: 'https://ui-events.test/' })
	_ = html.WindowModel.create_top_level(document, none, 'libjs-ui-events')!
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	host := Host.create(vm, vm.realm(), document, Hooks{})!
	return host, vm
}

fn ui_binding_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'ui_events.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{ max_instructions: 100000 }) or { return error(exception_message(err)) }
}

fn test_ui_event_uses_actual_native_state_window_identity_and_constructor_inheritance() {
	mut host, mut vm := ui_binding_fixture()!
	defer { host.close() }
	assert ui_binding_eval(mut vm, 'class Detail extends UIEvent{answer=42}var event=new Detail("ui",{view:window,detail:4294967297,bubbles:true});event instanceof Detail&&event instanceof UIEvent&&event instanceof Event&&event.answer===42&&event.view===window&&event.detail===1&&!event.isTrusted&&event.bubbles&&Object.getPrototypeOf(UIEvent)===Event&&Object.prototype.toString.call(event)==="[object UIEvent]"')!.as_bool()
	assert ui_binding_eval(mut vm, 'var event=new UIEvent("before");event.initUIEvent("after",true,true,window,7);event.type==="after"&&event.detail===7&&event.view===window&&event.cancelable&&event.bubbles&&event.which===0')!.as_bool()
}

fn test_ui_event_validates_receiver_and_new_target_before_author_conversions() {
	mut host, mut vm := ui_binding_fixture()!
	defer { host.close() }
	assert ui_binding_eval(mut vm, 'var reads=0,marker={},same=false,Next=new Proxy(function(){},{get(target,name){if(name==="prototype")throw marker;return target[name]}});try{Reflect.construct(UIEvent,[{toString(){reads++;return "x"}},{get detail(){reads++;return 1}}],Next)}catch(error){same=error===marker}same&&reads===0')!.as_bool()
	assert ui_binding_eval(mut vm, 'var caught=0;for(var run of [()=>UIEvent("x"),()=>new UIEvent(),()=>new UIEvent("x",true),()=>new UIEvent("x",{view:{}}),()=>Object.getOwnPropertyDescriptor(UIEvent.prototype,"detail").get.call(new Event("x"))])try{run()}catch(error){if(error instanceof TypeError)caught++}caught===5')!.as_bool()
}
