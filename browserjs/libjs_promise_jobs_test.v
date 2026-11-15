// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import html
import libjs
import platform

@[heap]
struct LibJSJobObservations {
mut:
	order []string
}

fn test_libjs_jobs_share_the_document_microtask_queue_in_enqueue_order() {
	address := dom.URL{value: 'https://libjs-jobs.test/page'}
	mut document := html.create_navigation_document(address, address.origin(), none)!
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close(); document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut seen := &LibJSJobObservations{}
	mut vm := runtime.agent_vm
	mut global := runtime.realm.global_object_record()
	record := libjs.NativeFunction.create(mut vm, runtime.realm, runtime.realm.function_prototype, fn [seen] (mut vm libjs.VM) !libjs.Value {
		mut state := unsafe { &LibJSJobObservations(seen) }
		state.order << vm.argument(0).as_string().str()
		return libjs.js_undefined()
	}, 1, libjs.PropertyName.from_str('record'), none)
	queue_html := libjs.NativeFunction.create(mut vm, runtime.realm, runtime.realm.function_prototype, fn [seen, settings] (mut vm libjs.VM) !libjs.Value {
		task := html.Task.create(.microtask, settings.responsible_document(), fn [seen] () {
			mut state := unsafe { &LibJSJobObservations(seen) }
			state.order << 'html'
		})
		mut loop := settings.responsible_event_loop(); loop.enqueue_microtask(task)
		return libjs.js_undefined()
	}, 0, libjs.PropertyName.from_str('queueHTML'), none)
	global.define_direct_property(libjs.PropertyName.from_str('record'), libjs.Value.from_object(record.object), 0)
	global.define_direct_property(libjs.PropertyName.from_str('queueHTML'), libjs.Value.from_object(queue_html.object), 0)
	runtime.bind_scripting_environment(settings)!
	runtime.evaluate('record("script");Promise.resolve().then(()=>record("promise1"));queueHTML();Promise.resolve().then(()=>record("promise2"));')!
	assert seen.order == ['script', 'promise1', 'html', 'promise2']
	assert !runtime.native_context_initialized()
	assert vm.execution_context_stack().len == 0 && !vm.has_running_execution_context()
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
}

fn test_external_libjs_jobs_run_without_a_new_script_entry_and_restore_current_script() {
	address := dom.URL{value: 'https://libjs-jobs.test/external'}
	mut document := html.create_navigation_document(address, address.origin(), none)!
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close(); document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut vm := runtime.agent_vm
	capability := libjs.new_promise_capability(mut vm, libjs.Value.from_object(runtime.realm.promise_constructor_record()))!
	mut global := runtime.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('external'), capability.promise, 0)
	runtime.bind_scripting_environment(settings)!
	runtime.install_libjs_document(document)!
	runtime.evaluate('var answer=0,sawCurrentScript=false;external.then(value=>{answer=value;sawCurrentScript=document.currentScript!==null})')!
	script := document.create_element('script')!
	document.set_current_script(script)
	runtime.prepare_html_script()
	libjs.call(mut vm, capability.resolve, libjs.js_undefined(), [libjs.Value.from_i32(42)])!
	runtime.clean_up_html_script()
	// Inspect native storage directly: no evaluate() call is allowed to make
	// this reaction progress, and the enclosing classic-script identity returns.
	assert global.get(mut vm, libjs.PropertyName.from_str('answer'))!.number == 42
	assert !global.get(mut vm, libjs.PropertyName.from_str('sawCurrentScript'))!.as_bool()
	assert voidptr(document.current_script()?) == voidptr(script)
	document.set_current_script(none)
	assert !vm.has_running_execution_context() && !runtime.native_context_initialized()
}

fn test_queued_libjs_jobs_respect_document_scripting_and_runtime_shutdown() {
	address := dom.URL{value: 'https://libjs-jobs.test/disabled'}
	mut document := html.create_navigation_document(address, address.origin(), none)!
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close(); document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	mut seen := &LibJSJobObservations{}
	mut vm := runtime.agent_vm
	job := fn [seen] () !libjs.Value {
		mut state := unsafe { &LibJSJobObservations(seen) }; state.order << 'ran'
		return libjs.js_undefined()
	}
	work := platform.begin_thread_scratch('enqueue LibJS promise job')
	vm.host_enqueue_promise_job(job, runtime.realm)
	work.finish()
	document.set_scripting_enabled_by_embedder(false)
	mut loop := settings.responsible_event_loop(); loop.perform_a_microtask_checkpoint()
	assert seen.order.len == 0
	document.set_scripting_enabled_by_embedder(true)
	vm.host_enqueue_promise_job(job, runtime.realm)
	runtime.close()
	loop.perform_a_microtask_checkpoint()
	assert seen.order.len == 0 && !vm.has_running_execution_context()
}
