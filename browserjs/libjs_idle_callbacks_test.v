// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn test_libjs_idle_callbacks_run_during_actual_window_idle_period_without_jsc() {
	mut document, _ := idle_host_document()
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close(); document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	runtime.install_libjs_document(document)!
	runtime.evaluate('var results=[],cancelled=0,handle=requestIdleCallback(function(deadline){"use strict";results.push(this===undefined,deadline instanceof IdleDeadline,deadline.didTimeout,deadline.timeRemaining()>=0,Object.prototype.toString.call(deadline))});var discard=requestIdleCallback(()=>cancelled++);cancelIdleCallback(discard)')!
	mut loop := settings.responsible_event_loop()
	for _ in 0 .. 4 {
		loop.process()
		for loop.task_queue().has_runnable_tasks() { loop.process() }
	}
	assert runtime.evaluate('JSON.stringify(results)')! == '[true,true,false,true,"[object IdleDeadline]"]'
	assert runtime.evaluate('cancelled')! == '0'
	assert !runtime.native_context_initialized() && runtime.take_libjs_messages().len == 0
	assert runtime.agent_vm.execution_context_stack().len == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
}

fn test_libjs_idle_callbacks_queue_window_microtasks_before_the_next_idle_callback() {
	mut document, _ := idle_host_document()
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close(); document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!; runtime.install_libjs_document(document)!
	runtime.evaluate('var order=[];requestIdleCallback(()=>{order.push("idle1");queueMicrotask(()=>order.push("microtask"));Promise.resolve().then(()=>order.push("promise"))});requestIdleCallback(()=>order.push("idle2"))')!
	mut loop := settings.responsible_event_loop()
	for _ in 0 .. 4 {
		loop.process()
		for loop.task_queue().has_runnable_tasks() { loop.process() }
	}
	assert runtime.evaluate('order.join()')! == 'idle1,microtask,promise,idle2'
	assert !runtime.native_context_initialized() && runtime.take_libjs_messages().len == 0
}
