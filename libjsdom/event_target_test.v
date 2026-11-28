// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import os
import rand

fn event_target_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-event-target.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 100000}) or { return error(exception_message(err)) }
}

fn event_target_document() !&dom.Document {
	address := dom.URL{value: 'https://event-target.test/'}
	mut document := html.parse_navigation_document('<body></body>', address, address.origin(), none)!
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	return document
}

fn test_event_target_constructor_subclasses_prototypes_and_native_identity() {
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), event_target_document()!, Hooks{})!
	defer { host.close() }
	assert event_target_eval(mut vm, 'class Target extends EventTarget{answer=42}var t=new Target();t instanceof Target&&t instanceof EventTarget&&t.answer===42&&t.constructor===Target&&Object.getPrototypeOf(t)===Target.prototype&&Object.prototype.toString.call(t)==="[object EventTarget]"&&Object.getPrototypeOf(Node)===EventTarget&&Object.getPrototypeOf(Node.prototype)===EventTarget.prototype&&document instanceof EventTarget&&document.body instanceof EventTarget&&document.addEventListener===EventTarget.prototype.addEventListener&&window.addEventListener===EventTarget.prototype.addEventListener&&EventTarget.length===0')!.as_bool()
	assert event_target_eval(mut vm, 'var ok=true;for(var name of ["addEventListener","removeEventListener","dispatchEvent"]){var d=Object.getOwnPropertyDescriptor(EventTarget.prototype,name);ok=ok&&d.enumerable&&d.writable&&d.configurable&&d.value.name===name&&d.value.length===(name==="dispatchEvent"?1:2)}ok')!.as_bool()
	value := vm.global_object().get(mut vm, libjs.PropertyName.from_str('t'))!
	native := host.event_targets[voidptr(value.as_object())] or { panic('Missing native EventTarget') }
	assert native.data.kind == .generic
	assert voidptr(host.wrap_target(native).as_object()) == voidptr(value.as_object())
}

fn test_event_target_dispatch_uses_native_callbacks_cancellation_once_and_target_identity() {
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), event_target_document()!, Hooks{})!
	defer { host.close() }
	assert event_target_eval(mut vm, 'var t=new EventTarget(),n=0,identity=false,e=new Event("ping",{cancelable:true});function listener(event){n++;identity=this===t&&event===e&&event.target===t&&event.currentTarget===t&&event.eventPhase===Event.AT_TARGET;event.preventDefault()}t.addEventListener("ping",listener,{once:true});t.addEventListener("ping",listener,{once:true});var first=t.dispatchEvent(e),second=t.dispatchEvent(new Event("ping"));!first&&second&&n===1&&identity&&e.defaultPrevented&&e.target===t&&e.currentTarget===null&&e.eventPhase===Event.NONE&&!e.isTrusted')!.as_bool()
	event_target_eval(mut vm, 'var seen=0,object={handleEvent(event){if(this===object&&event.target===t&&event.currentTarget===t)seen++}};t.addEventListener("native",object)')!
	value := vm.global_object().get(mut vm, libjs.PropertyName.from_str('t'))!
	native := host.event_targets[voidptr(value.as_object())] or { panic('Missing native EventTarget') }
	native.dispatch_event(dom.Event.create('native', dom.EventInit{}))
	assert event_target_eval(mut vm, 'seen===1')!.as_bool()
}

fn test_event_target_dispatch_brand_checks_and_recursive_dispatch_dom_exception() {
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), event_target_document()!, Hooks{})!
	defer { host.close() }
	assert event_target_eval(mut vm, 'var t=new EventTarget(),caught=false;t.addEventListener("x",function(e){try{t.dispatchEvent(e)}catch(error){caught=error instanceof DOMException&&error.name==="InvalidStateError"}});t.dispatchEvent(new Event("x"))&&caught')!.as_bool()
	for source in ['EventTarget()', 'EventTarget.prototype.dispatchEvent.call({},new Event("x"))', 't.dispatchEvent()', 't.dispatchEvent({})', 't.addEventListener("x",42)', 't.addEventListener("x")'] {
		assert event_target_eval(mut vm, 'var failed=false;try{'+source+'}catch(e){failed=e instanceof TypeError}failed')!.as_bool()
	}
	assert event_target_eval(mut vm, 'var listener={handleEvent(){throw 42}},calls=0;t.addEventListener("errors",listener);t.addEventListener("errors",function(){calls++});t.dispatchEvent(new Event("errors"))&&calls===1')!.as_bool()
}

fn test_event_target_listener_capture_removal_passive_and_close_cleanup() {
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), event_target_document()!, Hooks{})!
	defer { host.close() }
	assert event_target_eval(mut vm, 'var t=new EventTarget(),calls=0,log="",options={get capture(){log+="c";return true},get once(){log+="o";return false},get passive(){log+="p";return true}};function listener(e){calls++;e.preventDefault()}t.addEventListener("x",listener,options);t.addEventListener("x",listener,false);t.removeEventListener("x",listener,false);var e=new Event("x",{cancelable:true});t.dispatchEvent(e)&&!e.defaultPrevented&&calls===1&&log==="cop"')!.as_bool()
	value := vm.global_object().get(mut vm, libjs.PropertyName.from_str('t'))!
	native := host.event_targets[voidptr(value.as_object())] or { panic('Missing native EventTarget') }
	assert native.event_listener_list().len == 1
	host.close()
	assert native.event_listener_list().len == 0 && host.event_targets.len == 0
	native.dispatch_event(dom.Event.create('x', dom.EventInit{}))
	assert vm.global_object().get(mut vm, libjs.PropertyName.from_str('calls'))!.number == 1
}

fn test_cached_event_target_dispatch_executes_in_a_fresh_vm_with_compiler_disabled() {
	directory := os.join_path(os.temp_dir(), 'vox-event-target-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := libjs.VM.create()
		libjs.create_simple_execution_context(mut vm)
		mut host := Host.create(vm, vm.realm(), event_target_document()!, Hooks{})!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert event_target_eval(mut vm, 'var t=new EventTarget(),n=0;function listener(e){if(this===t&&e.target===t)n++}t.addEventListener("x",listener);t.dispatchEvent(new Event("x"))&&n===1')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
		host.close()
	}
}
