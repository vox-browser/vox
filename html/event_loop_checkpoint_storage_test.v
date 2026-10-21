module html

import dom
import libjs
import platform

fn test_checkpoint_reuses_private_settings_snapshot_and_visits_vms_without_copying_lists() {
	mut owner := EventLoop.create(.worker)
	first := libjs.VM.create()
	second := libjs.VM.create()
	owner.bind_vm(first)
	owner.attach_embedding_vm(first)
	owner.attach_embedding_vm(second)
	for _ in 0 .. 2 {
		realm := &ScriptingRealm{}
		environment := Environment.create('checkpoint-storage', dom.url_about_blank(), none, none, none)
		_ = create_environment_settings(realm, environment, .snapshot, owner)
	}
	owner.perform_a_microtask_checkpoint()
	data := owner.microtask_settings_snapshot_.data
	assert owner.microtask_settings_snapshot_.cap >= 2
	assert owner.microtask_settings_snapshot_.len == 0
	first_generation := first.execution_generation()
	second_generation := second.execution_generation()
	before := platform.thread_arena_usage().used
	for _ in 0 .. 1024 {
		assert !owner.has_running_execution_context()
		owner.perform_a_microtask_checkpoint()
	}
	$if prealloc {
		assert platform.thread_arena_usage().used - before < 1024
	}
	assert owner.microtask_settings_snapshot_.data == data
	assert first.execution_generation() == first_generation + 1024
	assert second.execution_generation() == second_generation + 1024
	// Reused storage must not become a long-lived root to a removed realm.
	for index in 0 .. 2 {
		assert unsafe { (&voidptr(data))[index] } == unsafe { nil }
	}
	owner.detach_embedding_vm(first)
	owner.perform_a_microtask_checkpoint()
	assert first.execution_generation() == first_generation + 1025
	assert second.execution_generation() == second_generation + 1025
	owner.bind_vm(none)
	owner.perform_a_microtask_checkpoint()
	assert first.execution_generation() == first_generation + 1025
	assert second.execution_generation() == second_generation + 1026
}
