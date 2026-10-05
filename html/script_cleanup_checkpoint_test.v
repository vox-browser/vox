module html

import dom
import libjs

@[heap]
struct ScriptCleanupObservations {
mut:
	calls []string
}

fn script_cleanup_window() &WindowModel {
	url := dom.URL{value: 'https://cleanup.example.test/'}
	return WindowModel.create_top_level(&dom.Document{url: url, origin_: url.origin()}, none, 'cleanup') or { panic(err) }
}

fn test_script_cleanup_waits_for_outer_realm_and_drains_reentrant_jobs_on_actual_owner() {
	window := script_cleanup_window()
	settings := window.environment_settings_.settings
	mut event_loop := unsafe { &EventLoop(settings.responsible_event_loop()) }
	mut outer := unsafe { &ScriptingRealm(settings.realm()) }
	mut inner := &ScriptingRealm{}
	mut seen := &ScriptCleanupObservations{}
	event_loop.enqueue_microtask(Task.create(.microtask, none, fn [mut outer, mut seen] () {
		assert outer.script_execution_depth == 0
		prepare_to_run_script(mut outer)
		seen.calls << 'first'
		clean_up_after_running_script(mut outer)
		seen.calls << 'after reentrant cleanup'
	}))
	event_loop.enqueue_microtask(Task.create(.microtask, none, fn [mut seen] () { seen.calls << 'second' }))
	prepare_to_run_script(mut outer)
	prepare_to_run_script(mut inner)
	clean_up_after_running_script(mut inner)
	assert seen.calls.len == 0
	assert inner.microtask_checkpoint_count == 0
	clean_up_after_running_script(mut outer)
	assert seen.calls == ['first', 'after reentrant cleanup', 'second']
	assert event_loop.microtask_queue.len == 0
	assert !event_loop.performing_a_microtask_checkpoint
}

fn test_script_cleanup_preserves_actual_outer_vm_execution_context() {
	window := script_cleanup_window()
	settings := window.environment_settings_.settings
	mut event_loop := unsafe { &EventLoop(settings.responsible_event_loop()) }
	mut realm := unsafe { &ScriptingRealm(settings.realm()) }
	mut vm := libjs.VM.create()
	mut outer := libjs.ExecutionContext.create(0, [], 0)
	mut realm_context := libjs.ExecutionContext.create(0, [], 0)
	realm.bind_embedding_execution_context(vm, realm_context)
	vm.push_execution_context_checked(mut outer) or { panic(err) }
	event_loop.bind_vm(vm)
	defer { event_loop.bind_vm(none) }
	mut seen := &ScriptCleanupObservations{}
	event_loop.enqueue_microtask(Task.create(.microtask, none, fn [mut seen] () { seen.calls << 'job' }))
	prepare_to_run_script(mut realm)
	assert voidptr(vm.running_execution_context()) == voidptr(realm_context)
	assert vm.execution_context_stack().len == 2
	clean_up_after_running_script(mut realm)
	assert seen.calls.len == 0
	assert vm.has_running_execution_context()
	assert voidptr(vm.running_execution_context()) == voidptr(outer)
	vm.pop_execution_context()
	prepare_to_run_script(mut realm)
	clean_up_after_running_script(mut realm)
	assert seen.calls == ['job']
	assert !vm.has_running_execution_context()
}

fn test_checkpoint_finishes_each_attached_actual_vm_generation_once() {
	mut event_loop := EventLoop.create(.window)
	first := libjs.VM.create()
	second := libjs.VM.create()
	event_loop.bind_vm(first)
	event_loop.attach_embedding_vm(first)
	event_loop.attach_embedding_vm(first)
	event_loop.attach_embedding_vm(second)
	first_generation := first.execution_generation()
	second_generation := second.execution_generation()
	event_loop.perform_a_microtask_checkpoint()
	assert first.execution_generation() == first_generation + 1
	assert second.execution_generation() == second_generation + 1
	event_loop.detach_embedding_vm(second)
	event_loop.perform_a_microtask_checkpoint()
	assert first.execution_generation() == first_generation + 2
	assert second.execution_generation() == second_generation + 1
}
