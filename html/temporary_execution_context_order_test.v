module html

import dom
import libjs

@[heap]
struct TemporaryContextCheckpointCount {
mut:
	calls int
}

fn temporary_context_order_fixture() !(&EnvironmentSettingsObject, &ScriptingRealm, &EventLoop) {
	url := dom.URL{value: 'https://temporary-context.example/'}
	document := create_navigation_document(url, url.origin(), none)!
	settings := unsafe { &EnvironmentSettingsObject(document.relevant_settings_object()) }
	return settings, settings.realm(), unsafe { &EventLoop(settings.responsible_event_loop()) }
}

fn test_source_temporary_context_script_checkpoint_retains_prepared_callback_and_incumbent() {
	settings, mut realm, mut event_loop := temporary_context_order_fixture()!
	count := &TemporaryContextCheckpointCount{}
	assert event_loop.is_backup_incumbent_realm_stack_empty()
	event_loop.enqueue_microtask(Task.create(.microtask, none, fn [settings, realm, event_loop, count] () {
		assert realm.script_execution_depth == 0
		assert realm.callback_execution_depth == 1
		assert voidptr(event_loop.top_of_backup_incumbent_realm_stack()) == voidptr(realm)
		assert voidptr(incumbent_settings_object()) == voidptr(settings)
		mut observation := unsafe { &TemporaryContextCheckpointCount(count) }
		observation.calls++
	}))
	mut context := TemporaryExecutionContext.create(mut realm, .yes)
	assert realm.script_execution_depth == 1 && realm.callback_execution_depth == 1
	context.close()
	assert count.calls == 1
	assert realm.script_execution_depth == 0 && realm.callback_execution_depth == 0
	assert event_loop.is_backup_incumbent_realm_stack_empty()
	checkpoint_count := realm.microtask_checkpoint_count
	context.close()
	assert realm.microtask_checkpoint_count == checkpoint_count
}

fn test_source_temporary_context_checkpoint_pops_actual_vm_context_before_callback_cleanup() {
	settings, mut realm, mut event_loop := temporary_context_order_fixture()!
	mut vm := libjs.VM.create()
	mut realm_context := libjs.ExecutionContext.create(0, [], 0)
	realm.bind_embedding_execution_context(vm, realm_context)
	event_loop.bind_vm(vm)
	defer { event_loop.bind_vm(none) }
	count := &TemporaryContextCheckpointCount{}
	event_loop.enqueue_microtask(Task.create(.microtask, none, fn [settings, realm, vm, count] () {
		assert !vm.has_running_execution_context()
		assert realm.script_execution_depth == 0 && realm.callback_execution_depth == 1
		assert voidptr(incumbent_settings_object()) == voidptr(settings)
		mut observation := unsafe { &TemporaryContextCheckpointCount(count) }
		observation.calls++
	}))
	mut context := TemporaryExecutionContext.create(mut realm, .yes)
	assert vm.execution_context_stack().len == 1
	assert voidptr(vm.running_execution_context()) == voidptr(realm_context)
	context.close()
	assert count.calls == 1 && !vm.has_running_execution_context()
	assert realm.callback_execution_depth == 0
	assert event_loop.is_backup_incumbent_realm_stack_empty()
}

fn test_source_temporary_context_without_callbacks_preserves_an_outer_callback_incumbent() {
	outer_settings, mut outer, mut event_loop := temporary_context_order_fixture()!
	_, mut realm, _ := temporary_context_order_fixture()!
	prepare_to_run_callback(mut outer)
	count := &TemporaryContextCheckpointCount{}
	event_loop.enqueue_microtask(Task.create(.microtask, none, fn [outer_settings, outer, realm, count] () {
		assert realm.script_execution_depth == 0 && realm.callback_execution_depth == 0
		assert outer.callback_execution_depth == 1
		assert voidptr(incumbent_settings_object()) == voidptr(outer_settings)
		mut observation := unsafe { &TemporaryContextCheckpointCount(count) }
		observation.calls++
	}))
	mut context := TemporaryExecutionContext.create(mut realm, .no)
	context.close()
	assert count.calls == 1
	assert realm.callback_execution_depth == 0 && outer.callback_execution_depth == 1
	assert voidptr(event_loop.top_of_backup_incumbent_realm_stack()) == voidptr(outer)
	clean_up_after_running_callback(mut outer)
	assert event_loop.is_backup_incumbent_realm_stack_empty()
}
