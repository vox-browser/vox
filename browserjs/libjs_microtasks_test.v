// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import html
import libjs
import os
import rand

fn test_libjs_window_microtasks_share_fifo_order_with_native_promise_jobs() {
	address := dom.URL{value: 'https://libjs-microtask.test/order'}
	mut document := html.create_navigation_document(address, address.origin(), none)!
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close(); document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	runtime.install_libjs_document(document)!
	assert runtime.evaluate('var order=[];Promise.resolve().then(()=>{order.push("p1");queueMicrotask(()=>order.push("p1q"))});queueMicrotask(()=>{order.push("q1");Promise.resolve().then(()=>order.push("q1p"));queueMicrotask(()=>order.push("q1q"))});Promise.resolve().then(()=>order.push("p2"));queueMicrotask(()=>order.push("q2"));order.push("sync");order.join()')! == 'sync'
	assert runtime.evaluate('order.join()')! == 'sync,p1,q1,p2,q2,p1q,q1p,q1q'
	assert runtime.take_libjs_messages().len == 0 && !runtime.native_context_initialized()
	assert runtime.agent_vm.execution_context_stack().len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
}

fn test_libjs_window_microtasks_respect_script_policy_after_enqueue() {
	address := dom.URL{value: 'https://libjs-microtask.test/policy'}
	mut document := html.create_navigation_document(address, address.origin(), none)!
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close(); document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	runtime.install_libjs_document(document)!
	mut vm := runtime.agent_vm
	stop := libjs.NativeFunction.create(mut vm, runtime.realm, runtime.realm.function_prototype, fn [document] (mut vm libjs.VM) !libjs.Value {
		mut owner := unsafe { &dom.Document(document) }; owner.set_scripting_enabled_by_embedder(false)
		return libjs.js_undefined()
	}, 0, libjs.PropertyName.from_str('disableScripts'), none)
	mut global := runtime.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('disableScripts'), libjs.Value.from_object(stop.object), 0)
	runtime.evaluate('var calls=0;queueMicrotask(()=>calls++);disableScripts()')!
	document.set_scripting_enabled_by_embedder(true)
	assert runtime.evaluate('calls')! == '0'
	assert runtime.take_libjs_messages().len == 0 && !runtime.native_context_initialized()
}

fn test_cached_window_microtask_callback_executes_after_revisit_without_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-window-microtask-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		address := dom.URL{value: 'https://libjs-microtask.test/cache'}
		mut document := html.create_navigation_document(address, address.origin(), none)!
		mut runtime := Runtime.create_with_engine(.libjs)
		settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
		runtime.bind_scripting_environment(settings)!; runtime.install_libjs_document(document)!
		mut vm := runtime.agent_vm
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		runtime.evaluate('var answer=0;queueMicrotask(()=>{answer=42})')!
		assert runtime.realm.global_object_record().get(mut vm, libjs.PropertyName.from_str('answer'))!.number == 42
		activity := vm.diagnose_native_code(false)!; stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		assert !runtime.native_context_initialized()
		vm.close_native_code()!; runtime.close(); document.finalize()
	}
}
