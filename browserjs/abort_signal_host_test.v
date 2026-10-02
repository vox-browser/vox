module browserjs

import dom
import html
import platform
import time
import webidl

fn abort_binding_document() &dom.Document {
	url := dom.URL{'https://abort-binding.example.test/'}
	return &dom.Document{url: url, origin_: url.origin()}
}

fn wait_for_native_abort_binding(condition fn () bool) {
	deadline := time.sys_mono_now() + i64(2_000_000_000)
	for !condition() && time.sys_mono_now() < deadline { platform.pump_native_events(0.01) }
	assert condition()
}

fn test_native_abort_controller_signal_reasons_events_and_default_exception_identity() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := AbortSignalHost.create(abort_binding_document())!
	host.install(mut runtime)!
	actual := runtime.evaluate_host_value('globalThis.abortController=new AbortController();globalThis.abortSignal=abortController.signal;abortSignal')!
	native := runtime.native_abort_signal(actual)!
	controller := runtime.native_abort_controller(runtime.evaluate_host_value('abortController')!)!
	assert voidptr(native) == voidptr(controller.signal())
	assert voidptr(runtime.native_event_target(actual)!) == voidptr(unsafe { &dom.EventTarget(native) })
	assert runtime.evaluate_host(r'
 globalThis.abortReasonCoercions=0;globalThis.abortReason={toString(){abortReasonCoercions++;throw "coercion"}};
 globalThis.abortDependent=AbortSignal.any([abortSignal]);globalThis.abortOrder=[];
 const listener=function(event){abortOrder.push(this===abortSignal&&event.target===abortSignal&&event.currentTarget===abortSignal&&event.isTrusted&&event.type==="abort"&&abortDependent.aborted&&abortDependent.reason===abortReason);globalThis.actualAbortEvent=event};
 abortSignal.addEventListener("abort",listener);abortSignal.onabort=function(event){abortOrder.push(this===abortSignal&&event===actualAbortEvent)};
 abortDependent.addEventListener("abort",function(event){abortOrder.push(this===abortDependent&&event.isTrusted&&event.target===abortDependent)});
 abortController.abort(abortReason);abortController.abort(Symbol("ignored later"));
 let caught;try{abortSignal.throwIfAborted()}catch(reason){caught=reason}
 [abortSignal===abortController.signal,abortSignal instanceof AbortSignal,abortSignal instanceof EventTarget,abortSignal.aborted,abortSignal.reason===abortReason,caught===abortReason,abortReasonCoercions===0,abortOrder.join(",")==="true,true,true",actualAbortEvent.currentTarget===null].every(Boolean)
')! == 'true'
	assert runtime.actual_webidl_value(native.reason().as_webidl_value()!)! == runtime.evaluate_host_value('abortReason')!
	assert native.abort_algorithms.len == 0
	assert runtime.evaluate_host(r'
 globalThis.defaultAbortController=new AbortController();defaultAbortController.abort(undefined);
 const defaultSignal=defaultAbortController.signal;let defaultCaught;try{defaultSignal.throwIfAborted()}catch(value){defaultCaught=value}
 [defaultSignal.reason instanceof DOMException,defaultSignal.reason.name==="AbortError",defaultSignal.reason.message==="Aborted without reason",defaultCaught===defaultSignal.reason,AbortSignal.abort().reason instanceof DOMException,AbortSignal.abort("actual string").reason==="actual string"].every(Boolean)
')! == 'true'
	default_signal := runtime.native_abort_signal(runtime.evaluate_host_value('defaultAbortController.signal')!)!
	reason := default_signal.reason().as_webidl_value()!
	actual_reason := runtime.evaluate_host_value('defaultAbortController.signal.reason')!
	assert runtime.javascript_dom_exception(reason)! == actual_reason
	assert voidptr(runtime.native_dom_exception(actual_reason)!.dom_exception_ or { panic('missing actual default record') }) == voidptr(reason.dom_exception_ or { panic('missing source default record') })
}

fn test_native_abort_any_uses_actual_iteration_close_brands_and_original_thrown_values() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := AbortSignalHost.create(abort_binding_document())!
	host.install(mut runtime)!
	assert runtime.evaluate_host(r'
 globalThis.abortIterationClosed=0;globalThis.abortIterationOrder=[];
 const invalidIterable={[Symbol.iterator](){abortIterationOrder.push("iterator");return {next(){abortIterationOrder.push("next");return {value:{},done:false}},return(){abortIterationClosed++;return {done:true}}}}};
 let badType=false;try{AbortSignal.any(invalidIterable)}catch(error){badType=error instanceof TypeError}
 const iteratorReason={native:"original iterator reason"};const throwingIterable={get [Symbol.iterator](){throw iteratorReason}};let actualReason;try{AbortSignal.any(throwingIterable)}catch(error){actualReason=error}
 const first=AbortSignal.abort(Symbol("first")),second=AbortSignal.abort({second:true});const result=AbortSignal.any([first,second]);
 const source=new AbortController(),chain=AbortSignal.any([source.signal]),flattened=AbortSignal.any([chain]);const reason={flattened:true};source.abort(reason);
 [AbortSignal.abort.length===0,AbortController.prototype.abort.length===0,badType,abortIterationClosed===1,abortIterationOrder.join(",")==="iterator,next",actualReason===iteratorReason,result.reason===first.reason,result!==first,chain.reason===reason,flattened.reason===reason].every(Boolean)
')! == 'true'
	assert runtime.evaluate_host(r'
 const tests=[()=>new AbortSignal(),()=>AbortController(),()=>Object.getOwnPropertyDescriptor(AbortSignal.prototype,"reason").get.call({}),()=>AbortController.prototype.abort.call({}),()=>AbortSignal.prototype.throwIfAborted.call({})];
 tests.every(callback=>{try{callback();return false}catch(error){return error instanceof TypeError}})
')! == 'true'
	assert runtime.evaluate_host(r'
 class DerivedAbortController extends AbortController {};
 const derived=new DerivedAbortController();derived instanceof DerivedAbortController&&derived instanceof AbortController&&derived.signal instanceof AbortSignal
')! == 'true'
}

fn test_native_abort_timeout_uses_enforce_range_conversion_and_actual_owner_timer_task() {
	$if !darwin { return }
	if !platform.native_timer_scheduling_available() { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := AbortSignalHost.create(abort_binding_document())!
	host.install(mut runtime)!
	assert runtime.evaluate_host(r'
 const invalidTimeouts=[NaN,Infinity,-1,Number.MAX_SAFE_INTEGER+1,Symbol("duration"),1n];
 invalidTimeouts.every(value=>{try{AbortSignal.timeout(value);return false}catch(error){return error instanceof TypeError}})
')! == 'true'
	mut owner := unsafe { &html.EventLoop(host.settings.responsible_event_loop()) }
	pause_handle := owner.pause()
	defer { if owner.execution_paused() { owner.unpause(pause_handle) } }
	actual := runtime.evaluate_host_value(r'
 globalThis.nativeTimeoutSignal=AbortSignal.timeout({valueOf(){return 5.75}});
 globalThis.nativeTimeoutEvent=null;nativeTimeoutSignal.onabort=function(event){nativeTimeoutEvent=event;globalThis.nativeTimeoutCallbackThis=this};nativeTimeoutSignal
')!
	native := runtime.native_abort_signal(actual)!
	mut scope := host.settings.window_or_worker_global_scope()!
	wait_for_native_abort_binding(fn [scope] () bool { return scope.active_timer_count() == 0 })
	assert !native.aborted()
	assert runtime.evaluate_host('nativeTimeoutSignal.aborted===false&&nativeTimeoutEvent===null')! == 'true'
	owner.unpause(pause_handle)
	owner.schedule()
	wait_for_native_abort_binding(fn [native] () bool { return native.aborted() })
	assert runtime.evaluate_host(r'
 let timedOut;try{nativeTimeoutSignal.throwIfAborted()}catch(reason){timedOut=reason}
 [nativeTimeoutSignal.reason instanceof DOMException,nativeTimeoutSignal.reason.name==="TimeoutError",nativeTimeoutSignal.reason.message==="Signal timed out",nativeTimeoutEvent.target===nativeTimeoutSignal,nativeTimeoutEvent.isTrusted,nativeTimeoutEvent.currentTarget===null,nativeTimeoutCallbackThis===nativeTimeoutSignal,timedOut===nativeTimeoutSignal.reason].every(Boolean)
')! == 'true'
	assert runtime.take_document_state_dirty()
	reason := native.reason().as_webidl_value()!
	exception := webidl.dom_exception_from_object(reason) or { panic('missing native timeout exception') }
	assert exception.name() == 'TimeoutError'
}

fn test_source_timeout_may_settle_after_runtime_close_without_entering_released_engine() {
	$if !darwin { return }
	if !platform.native_timer_scheduling_available() { return }
	mut runtime := Runtime.create()
	mut host := AbortSignalHost.create(abort_binding_document())!
	host.install(mut runtime)!
	actual := runtime.evaluate_host_value('globalThis.lateAbortSignal=AbortSignal.timeout(5);lateAbortSignal.onabort=function(){throw "closed engine callback"};lateAbortSignal')!
	native := runtime.native_abort_signal(actual)!
	runtime.close()
	wait_for_native_abort_binding(fn [native] () bool { return native.aborted() })
	assert host.closed
}
