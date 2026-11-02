module browserjs

import dom
import html
import loader
import platform

fn microtask_binding_fixture() !(&Runtime, &dom.Document) {
	if !loader.is_initialized() { loader.initialize() }
	url := dom.URL{ value: 'https://microtask.test/' }
	document := html.parse_navigation_document('<!doctype html>', url, url.origin(), none)!
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) })!
	runtime.install_document_window_event_binding(document, runtime.evaluate_host_value('globalThis.document={}')!)!
	runtime.install_microtask_binding()!
	return runtime, document
}

fn test_microtask_binding_shares_promise_fifo_and_keeps_nested_jobs_asynchronous() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document := microtask_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 globalThis.order=[];
 Promise.resolve().then(()=>{order.push("p1");queueMicrotask(()=>order.push("p1q"))});
 queueMicrotask(()=>{order.push("q1");Promise.resolve().then(()=>order.push("q1p"));queueMicrotask(()=>order.push("q1q"))});
 Promise.resolve().then(()=>order.push("p2"));queueMicrotask(()=>order.push("q2"));order.push("sync");
 order.join(",");
 ')! == 'sync'
	assert runtime.evaluate_host('order.join(",")')! == 'sync,p1,q1,p2,q2,p1q,q1p,q1q'
	assert runtime.take_document_state_dirty()
	assert microtask_bindings_[voidptr(runtime)].pending.len == 0
}

fn test_microtask_binding_reports_original_exception_continues_and_ignores_results() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document := microtask_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 globalThis.marker={message:"microtask failed"};globalThis.continued=false;globalThis.adopted=false;
 queueMicrotask(()=>{throw marker});queueMicrotask(()=>{continued=true;return {get then(){adopted=true;throw Error("must not adopt")}}});true;
 ')! == 'true'
	assert runtime.evaluate_host('continued&&!adopted')! == 'true'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 1
	reported := settings.realm().reported_exceptions[0]
	assert reported.error_in_promise == .no
	value := runtime.actual_webidl_value(reported.value.native_value_ or { panic('Missing original exception') })!
	assert runtime.call_engine_function(runtime.value_same_intrinsic_, [value,
		runtime.evaluate_host_value('marker')!])! == C.vox_jsc_JSValueMakeBoolean(runtime.context, true)
}

fn test_microtask_binding_webidl_receiver_callback_and_native_function_shape() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document := microtask_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 globalThis.calls=0;globalThis.strictThis=false;
 let errors=0;for(const run of [()=>queueMicrotask(),()=>queueMicrotask(null),()=>queueMicrotask({handleEvent(){}}),()=>queueMicrotask(1),()=>new queueMicrotask(()=>{}),()=>queueMicrotask.call({},()=>{}),()=>queueMicrotask.call(document,()=>{})])try{run()}catch(e){if(e instanceof TypeError)errors++}
 queueMicrotask.call(null,()=>calls++);queueMicrotask.call(undefined,()=>calls++);
 const result=queueMicrotask(function(){"use strict";strictThis=this===undefined&&arguments.length===0});
 errors===7&&calls===0&&result===undefined&&queueMicrotask.name==="queueMicrotask"&&queueMicrotask.length===1&&Function.prototype.toString.call(queueMicrotask).includes("[native code]")&&!("prototype" in queueMicrotask);
 ')! == 'true'
	assert runtime.evaluate_host('calls===2&&strictThis')! == 'true'
}

fn test_microtask_binding_uses_private_intrinsics_after_author_mutation() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document := microtask_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 globalThis.ran=false;
 const P=Promise;Object.defineProperty(P.prototype,"constructor",{get(){throw Error("author constructor")}});
 Object.defineProperty(P,Symbol.species,{get(){throw Error("author species")}});
 P.prototype.then=function(){throw Error("author then")};P.resolve=function(){throw Error("author resolve")};
 globalThis.Promise=function(){throw Error("author Promise")};Reflect.apply=function(){throw Error("author apply")};
 queueMicrotask(()=>{ran=true;queueMicrotask(()=>{ran="nested"})});true;
 ')! == 'true'
	assert runtime.evaluate_host('ran')! == 'nested'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().reported_exceptions.len == 0
}

fn test_microtask_binding_releases_completed_callback_roots_and_runtime_ownership() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document := microtask_binding_fixture()!
	defer { document.finalize() }
	baseline := runtime.protected_values_.len
	mut temporary := platform.begin_thread_scratch('microtask source')
	source := 'globalThis.calls=0;for(let i=0;i<100;i++)queueMicrotask(()=>{calls++});true'.clone()
	temporary.leave()
	assert runtime.evaluate_host(source)! == 'true'
	temporary.finish()
	gc_collect()
	assert runtime.evaluate_host('calls')! == '100'
	assert runtime.protected_values_.len == baseline
	assert runtime.evaluate_host('queueMicrotask=17;true')! == 'true'
	runtime.install_microtask_binding()!
	assert runtime.evaluate_host('queueMicrotask')! == '17'
	runtime.close()
	assert voidptr(runtime) !in microtask_bindings_
	assert runtime.protected_values_.len == 0
}
