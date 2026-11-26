// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import os
import rand

fn custom_event_fixture() !(&Host, &libjs.VM) {
	address := dom.URL{value:'https://custom-event.test/'}
	document := html.parse_navigation_document('<body><div id="target"></div></body>',address,address.origin(),none)!
	mut vm := libjs.VM.create(); libjs.create_simple_execution_context(mut vm)
	host := Host.create(vm,vm.realm(),document,Hooks{})!
	return host,vm
}

fn custom_event_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source,vm.realm(),'custom-events.js',unsafe { nil })!
	return vm.run_with_limits(mut script,libjs.ExecutionLimits{max_instructions:100000}) or { return error(exception_message(err)) }
}

fn test_custom_event_keeps_actual_detail_subclass_and_native_dispatch_identity() {
	mut host, mut vm := custom_event_fixture()!
	defer { host.close() }
	assert custom_event_eval(mut vm, 'class Message extends CustomEvent{}var payload={toString(){throw 1}},event=new Message("message",{detail:payload,bubbles:true,cancelable:true,composed:true}),target=document.getElementById("target"),identity=false;target.addEventListener("message",function(e){identity=e===event&&e.detail===payload&&e.target===target&&this===target;e.preventDefault()});var result=target.dispatchEvent(event);identity&&!result&&event.defaultPrevented&&event instanceof Message&&event instanceof CustomEvent&&event instanceof Event&&Object.getPrototypeOf(CustomEvent)===Event&&event.bubbles&&event.cancelable&&event.composed&&!event.isTrusted&&Object.prototype.toString.call(event)==="[object CustomEvent]"&&new CustomEvent("x").detail===null&&new CustomEvent("x",{detail:undefined}).detail===null')!.as_bool()
}

fn test_custom_event_dictionary_order_reinitialization_and_brand_checks() {
	mut host, mut vm := custom_event_fixture()!
	defer { host.close() }
	assert custom_event_eval(mut vm, 'var order="",detail=Symbol("detail"),event=new CustomEvent({toString(){order+="t";return "x"}},{get bubbles(){order+="b"},get cancelable(){order+="c"},get composed(){order+="o"},get detail(){order+="d";return detail}}),same=false,target=new EventTarget();target.addEventListener("x",()=>{event.initCustomEvent("during",true,true,1);same=event.type==="x"&&event.detail===detail});target.dispatchEvent(event);event.initCustomEvent("after",true,true,42n);var failed=0;for(var call of [()=>CustomEvent("x"),()=>new CustomEvent(),()=>CustomEvent.prototype.initCustomEvent.call({},{toString(){throw 1}}),()=>Object.getOwnPropertyDescriptor(CustomEvent.prototype,"detail").get.call(new Event("x"))])try{call()}catch(e){if(e instanceof TypeError)failed++}order==="tbcod"&&same&&event.type==="after"&&event.detail===42n&&event.bubbles&&event.cancelable&&failed===4')!.as_bool()
}

fn test_native_custom_event_wrapper_selects_the_custom_event_interface() {
	mut host, mut vm := custom_event_fixture()!
	defer { host.close() }
	native := dom.CustomEvent.create('native',dom.CustomEventInit{detail:dom.js_string('actual detail')})
	value := host.wrap_event(unsafe { &dom.Event(native) })
	mut global := vm.global_object()
	global.define_direct_property(libjs.PropertyName.from_str('nativeEvent'),value,0)
	assert custom_event_eval(mut vm, 'nativeEvent instanceof CustomEvent&&nativeEvent instanceof Event&&nativeEvent.type==="native"&&nativeEvent.detail==="actual detail"')!.as_bool()
}

fn test_cached_custom_event_dispatch_preserves_detail_without_compiler() {
	directory := os.join_path(os.temp_dir(),'vox-custom-event-'+rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm := custom_event_fixture()!
		vm.enable_native_code_cache(directory,if visit==0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert custom_event_eval(mut vm, 'var target=new EventTarget(),payload={},identity=false;target.addEventListener("x",event=>{identity=event.detail===payload});target.dispatchEvent(new CustomEvent("x",{detail:payload}));identity')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit==1 { assert stats.cache_hits>0&&stats.cache_misses==0&&stats.compiler_invocations==0&&activity.entries>0 }
		vm.close_native_code()!
		host.close()
	}
}
