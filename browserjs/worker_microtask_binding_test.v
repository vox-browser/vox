module browserjs

import dom
import html
import platform

@[heap]
struct WorkerMicrotaskErrors {
mut:
	values []dom.JSValue
}

fn worker_microtask_fixture() !(&Runtime, &html.WorkerEnvironmentSettingsObject) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	url := dom.URL{value: 'https://worker-microtask.test/agent.js'}
	mut realm := &html.ScriptingRealm{}
	scope := html.DedicatedWorkerGlobalScope.create(url, html.WorkerOptions{}, realm)
	environment := html.WorkerEnvironmentSettingsObject.setup(&scope.WorkerGlobalScope, mut realm,
		html.SerializedEnvironmentSettingsObject{
			creation_url: url
			api_base_url: url
			origin: url.origin()
			global: html.SerializedWorkerGlobalScope{relevant_settings_object_is_secure_context: true}
		}, 12)
	mut runtime := Runtime.create_for_worker()
	mut host := WorkerGlobalHost.create(environment)!
	host.install(mut runtime)!
	runtime.install_microtask_binding()!
	return runtime, environment
}

fn test_worker_microtasks_share_promise_fifo_and_enter_the_actual_worker_callback_realm() {
	mut runtime, environment := worker_microtask_fixture()!
	defer { runtime.close() }
	settings := environment.settings
	loop := environment.global_scope.event_loop
	context := runtime.context
	runtime.define_value_host_function('__checkWorkerRealm', fn [settings, loop, context] (_ voidptr, _ []voidptr) !voidptr {
		assert voidptr(html.current_principal_settings_object()) == voidptr(settings)
		assert voidptr(html.incumbent_settings_object()) == voidptr(settings)
		assert voidptr(settings.responsible_event_loop()) == voidptr(loop)
		return C.vox_jsc_JSValueMakeBoolean(context, true)
	})!
	assert runtime.evaluate_host(r'
 globalThis.order=[];globalThis.callbackRealm=false;globalThis.strictReceiver=false;
 Promise.resolve().then(()=>{order.push("p1");queueMicrotask(()=>order.push("p1q"))});
 queueMicrotask(function(){"use strict";strictReceiver=this===undefined&&arguments.length===0;callbackRealm=__checkWorkerRealm();order.push("q1");Promise.resolve().then(()=>order.push("q1p"));queueMicrotask(()=>order.push("q1q"))});
 Promise.resolve().then(()=>order.push("p2"));queueMicrotask(()=>order.push("q2"));order.push("sync");order.join();
 ')! == 'sync'
	assert runtime.evaluate_host('order.join() === "sync,p1,q1,p2,q2,p1q,q1p,q1q"&&callbackRealm&&strictReceiver')! == 'true'
	assert environment.settings.responsible_document() == none
	assert microtask_bindings_[voidptr(runtime)].pending.len == 0
}

fn test_worker_microtasks_report_the_original_exception_continue_and_ignore_callback_results() {
	mut runtime, environment := worker_microtask_fixture()!
	defer { runtime.close() }
	observed := &WorkerMicrotaskErrors{}
	environment.global_scope.this_impl().add_event_listener_without_options('error',
		dom.IDLEventListener.create(&dom.CallbackType{
			handle_event: fn [observed] (base_event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
				mut errors := unsafe { observed }
				event := unsafe { &dom.ErrorEvent(base_event) }
				errors.values << event.error()
				return dom.js_undefined()
			}
		}))
	assert runtime.evaluate_host(r'
 globalThis.marker={message:"worker microtask failed"};globalThis.continued=false;globalThis.adopted=false;
 queueMicrotask(()=>{throw marker});queueMicrotask(()=>{continued=true;return {get then(){adopted=true;throw Error("must not adopt")}}});true;
 ')! == 'true'
	assert runtime.evaluate_host('continued&&!adopted')! == 'true'
	assert environment.settings.realm().reported_exceptions.len == 0
	assert observed.values.len == 1
	actual := runtime.actual_webidl_value(observed.values[0].native_value_ or { panic('Missing original exception') })!
	assert runtime.call_engine_function(runtime.value_same_intrinsic_, [actual,
		runtime.evaluate_host_value('marker')!])! == C.vox_jsc_JSValueMakeBoolean(runtime.context, true)
}

fn test_worker_microtask_callback_conversion_receiver_checks_and_native_function_metadata() {
	mut runtime, _ := worker_microtask_fixture()!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'
 globalThis.calls=0;let errors=0;
 for(const call of [()=>queueMicrotask(),()=>queueMicrotask(null),()=>queueMicrotask({handleEvent(){}}),()=>queueMicrotask(1),()=>new queueMicrotask(()=>{}),()=>queueMicrotask.call({},()=>{}),()=>queueMicrotask.call(new EventTarget(),()=>{})])try{call()}catch(error){if(error instanceof TypeError)errors++}
 const result=queueMicrotask(()=>calls++);queueMicrotask.call(null,()=>calls++);queueMicrotask.call(undefined,()=>calls++);
 errors===7&&calls===0&&result===undefined&&queueMicrotask.name==="queueMicrotask"&&queueMicrotask.length===1&&!("prototype" in queueMicrotask)&&Function.prototype.toString.call(queueMicrotask).includes("[native code]");
 ')! == 'true'
	assert runtime.evaluate_host('calls===3')! == 'true'
}

fn test_worker_microtasks_keep_private_engine_intrinsics_after_author_replacement() {
	mut runtime, environment := worker_microtask_fixture()!
	defer { runtime.close() }
	assert runtime.evaluate_host(r'
 globalThis.ran=false;const P=Promise;
 Object.defineProperty(P.prototype,"constructor",{get(){throw Error("author constructor")}});Object.defineProperty(P,Symbol.species,{get(){throw Error("author species")}});
 P.prototype.then=function(){throw Error("author then")};P.resolve=function(){throw Error("author resolve")};globalThis.Promise=function(){throw Error("author Promise")};Reflect.apply=function(){throw Error("author apply")};
 queueMicrotask(()=>{ran=true;queueMicrotask(()=>{ran="nested"})});true;
 ')! == 'true'
	assert runtime.evaluate_host('ran')! == 'nested'
	assert environment.settings.realm().reported_exceptions.len == 0
}

fn test_worker_microtasks_survive_poisoned_scratch_resets_release_roots_and_close_their_registration() {
	mut runtime, _ := worker_microtask_fixture()!
	baseline := runtime.protected_values_.len
	mut caller := platform.begin_thread_scratch('worker microtask caller')
	runtime.evaluate_host('globalThis.calls=0;globalThis.message="Санкт-Петербург 😀";for(let i=0;i<100;i++)queueMicrotask(()=>{calls++;queueMicrotask(()=>calls++)});')!
	caller.finish()
	mut delivery := platform.begin_thread_scratch('worker microtask delivery')
	assert runtime.evaluate_host('calls===200&&message==="Санкт-Петербург 😀"')! == 'true'
	delivery.finish()
	assert runtime.protected_values_.len == baseline
	assert microtask_bindings_[voidptr(runtime)].pending.len == 0
	runtime.evaluate_host('queueMicrotask=17')!
	runtime.install_microtask_binding()!
	assert runtime.evaluate_host('queueMicrotask')! == '17'
	runtime.close()
	assert voidptr(runtime) !in microtask_bindings_
	assert runtime.protected_values_.len == 0
}
