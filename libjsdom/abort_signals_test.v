// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import os
import platform
import rand
import time

fn abort_fixture() !(&Host, &libjs.VM, &dom.Document) {
	address := dom.URL{value: 'https://libjs-abort.test/'}
	mut document := html.parse_navigation_document('<body></body>', address, address.origin(), none)!
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	host := Host.create(vm, vm.realm(), document, Hooks{})!
	return host, vm, document
}

fn abort_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-abort.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 100000}) or { return error(exception_message(err)) }
}

fn test_abort_controller_native_identity_subclasses_and_abort_reason_values_are_not_coerced() {
	mut host, mut vm, _ := abort_fixture()!
	defer { host.close() }
	assert abort_eval(mut vm, 'class C extends AbortController{answer=42}var controller=new C(),signal=controller.signal;controller instanceof C&&controller instanceof AbortController&&controller.answer===42&&signal===controller.signal&&signal instanceof AbortSignal&&signal instanceof EventTarget&&!signal.aborted&&signal.reason===undefined&&signal.throwIfAborted()===undefined&&Object.getPrototypeOf(AbortSignal)===EventTarget&&Object.prototype.toString.call(signal)==="[object AbortSignal]"')!.as_bool()
	assert abort_eval(mut vm, 'Object.getOwnPropertyNames(AbortSignal.prototype).join(",")==="constructor,aborted,reason,throwIfAborted,onabort"&&Object.getOwnPropertyNames(AbortSignal).slice(-3).join(",")==="abort,timeout,any"')!.as_bool()
	assert abort_eval(mut vm, 'var reason={toString(){throw 1}},count=0,identity=false;signal.onabort=function(e){count++;identity=this===signal&&e.target===signal&&e.currentTarget===signal&&e.type==="abort"&&e.isTrusted};controller.abort(reason);controller.abort(2);var same=false;try{signal.throwIfAborted()}catch(e){same=e===reason}signal.aborted&&signal.reason===reason&&same&&count===1&&identity')!.as_bool()
	assert abort_eval(mut vm, 'var ok=true;for(var value of [null,false,0,-0,NaN,"\\ud800",42n,Symbol("reason")]){var s=AbortSignal.abort(value);ok=ok&&s.aborted&&Object.is(s.reason,value);try{s.throwIfAborted()}catch(e){ok=ok&&Object.is(e,value)}}ok')!.as_bool()
}

fn test_abort_default_dom_exception_retains_native_identity_across_dependent_signals() {
	mut host, mut vm, _ := abort_fixture()!
	defer { host.close() }
	assert abort_eval(mut vm, 'var c=new AbortController(),dependent=AbortSignal.any([c.signal]);c.abort();var reason=c.signal.reason,same=false;try{dependent.throwIfAborted()}catch(e){same=e===reason}reason instanceof DOMException&&reason.name==="AbortError"&&reason.code===20&&reason===c.signal.reason&&reason===dependent.reason&&same&&AbortSignal.abort().reason.name==="AbortError"')!.as_bool()
	assert host.dom_exceptions.len == 2 && host.dom_exception_wrappers.len == 2
}

fn test_abort_any_uses_native_dependencies_order_and_sequence_validation_closes_iterators() {
	mut host, mut vm, _ := abort_fixture()!
	defer { host.close() }
	assert abort_eval(mut vm, 'var first=new AbortController(),second=new AbortController(),reason={},count=0;var signal=AbortSignal.any([first.signal,second.signal,first.signal]);signal.addEventListener("abort",()=>count++);second.abort(reason);first.abort(99);signal.aborted&&signal.reason===reason&&count===1&&!AbortSignal.any([]).aborted&&AbortSignal.any([AbortSignal.abort(1),AbortSignal.abort(2)]).reason===1')!.as_bool()
	assert abort_eval(mut vm, 'var closed=0,source={[Symbol.iterator](){return {next(){return {value:{},done:false}},return(){closed++;return {}}}}},failed=false;try{AbortSignal.any(source)}catch(e){failed=e instanceof TypeError}failed&&closed===1')!.as_bool()
}

fn test_abortable_event_listeners_remove_native_and_vm_registrations_and_allow_readding() {
	mut host, mut vm, _ := abort_fixture()!
	defer { host.close() }
	assert abort_eval(mut vm, 'var controller=new AbortController(),target=new EventTarget(),calls=0;function listener(){calls++}target.addEventListener("x",listener,{signal:controller.signal});target.dispatchEvent(new Event("x"));controller.abort();target.dispatchEvent(new Event("x"));target.addEventListener("x",listener);target.dispatchEvent(new Event("x"));target.removeEventListener("x",listener);target.addEventListener("x",listener,{signal:controller.signal});target.dispatchEvent(new Event("x"));calls===2')!.as_bool()
	assert host.listeners.len == 0
	assert abort_eval(mut vm, 'var controller=new AbortController(),target=new EventTarget(),order="";target.addEventListener("x",()=>{order+="a";controller.abort()});target.addEventListener("x",()=>{order+="b"},{signal:controller.signal});target.dispatchEvent(new Event("x"));order==="a"')!.as_bool()
	assert abort_eval(mut vm, 'var controller=new AbortController(),target=new EventTarget(),f=()=>0;target.addEventListener("x",f,{signal:controller.signal});target.removeEventListener("x",f);controller.abort();true')!.as_bool()
	assert abort_eval(mut vm, 'var reads=0,failed=false;try{target.addEventListener("x",null,{get signal(){reads++;return null}})}catch(e){failed=e instanceof TypeError}failed&&reads===1')!.as_bool()
}

fn test_abort_bindings_validate_native_brands_and_timeout_enforce_range_and_run_real_owner_task() {
	mut host, mut vm, _ := abort_fixture()!
	defer { host.close() }
	assert abort_eval(mut vm, 'var count=0;for(var run of [()=>AbortController(),()=>new AbortSignal(),()=>AbortSignal(),()=>AbortController.prototype.abort.call({}),()=>Object.getOwnPropertyDescriptor(AbortSignal.prototype,"reason").get.call({}),()=>AbortSignal.any(),()=>AbortSignal.any([{}]),()=>AbortSignal.timeout(),()=>AbortSignal.timeout(-1),()=>AbortSignal.timeout(Infinity),()=>AbortSignal.timeout(NaN),()=>AbortSignal.timeout(18446744073709551616),()=>AbortSignal.timeout(1n),()=>AbortSignal.timeout(Symbol()),()=>new EventTarget().addEventListener("x",()=>0,{signal:null})])try{run()}catch(e){if(e instanceof TypeError)count++}count===15')!.as_bool()
	if !platform.native_timer_scheduling_available() { return }
	abort_eval(mut vm, 'var timed=AbortSignal.timeout({valueOf(){return 5.75}}),seen=false;timed.onabort=function(e){seen=timed.reason instanceof DOMException&&timed.reason.name==="TimeoutError"&&e.target===timed}')!
	deadline := time.sys_mono_now() + i64(2000000000)
	for time.sys_mono_now() < deadline {
		platform.pump_native_events(0.01)
		if vm.global_object().get(mut vm, libjs.PropertyName.from_str('seen'))!.as_bool() { break }
	}
	assert vm.global_object().get(mut vm, libjs.PropertyName.from_str('seen'))!.as_bool()
}

fn test_cached_abort_dispatch_and_listener_cleanup_work_without_compiler_and_retire_close_hooks() {
	directory := os.join_path(os.getenv_opt('TMPDIR') or { os.temp_dir() }, 'vox-native-abort-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm, _ := abort_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		abort_eval(mut vm, 'var controller=new AbortController(),target=new EventTarget(),calls=0;target.addEventListener("x",()=>calls++,{signal:controller.signal});controller.signal.addEventListener("abort",()=>calls+=42);controller.abort();target.dispatchEvent(new Event("x"))')!
		assert vm.global_object().get(mut vm, libjs.PropertyName.from_str('calls'))!.number == 42
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
		abort_eval(mut vm, 'var remaining=new AbortController(),owned=new EventTarget();owned.addEventListener("x",()=>calls++,{signal:remaining.signal})')!
		value := vm.global_object().get(mut vm, libjs.PropertyName.from_str('remaining'))!
		mut native := host.abort_controllers[voidptr(value.as_object())] or { panic('Missing native controller') }
		host.close()
		native.abort(dom.js_undefined())
		assert vm.global_object().get(mut vm, libjs.PropertyName.from_str('calls'))!.number == 42
	}
}
