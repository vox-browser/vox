// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// Fetch/Infrastructure/Task.cpp and PendingResponse's deferred callback boundary.
module html

import fetch
import platform

fn create_fetch_parallel_queue() fetch.FetchTaskDestinationProvider {
	return ParallelQueue.create()
}

pub fn (queue &ParallelQueue) fetch_request_client_queue_fetch_task(algorithm fn ()) u64 {
	return queue.enqueue(algorithm)
}

pub fn (_ &ParallelQueue) fetch_request_client_cancel_fetch_task(task_id u64) {
	mut owner := main_thread_event_loop()
	mut queue := owner.task_queue()
	queue.remove_tasks_matching(fn [task_id] (task &Task) bool { return task.id == task_id })
}

pub fn (_ &ParallelQueue) fetch_request_client_deferred_invoke(algorithm fn ()) {
	defer_fetch_continuation(algorithm, platform.current_retained_arena())
}

pub fn (settings &EnvironmentSettingsObject) fetch_request_client_queue_fetch_task(algorithm fn ()) u64 {
	return queue_a_task(.networking, settings.responsible_event_loop(), settings.responsible_document(), algorithm)
}

pub fn (settings &EnvironmentSettingsObject) fetch_request_client_cancel_fetch_task(task_id u64) {
	mut owner := settings.responsible_event_loop()
	mut queue := owner.task_queue()
	queue.remove_tasks_matching(fn [task_id] (task &Task) bool { return task.id == task_id })
}

pub fn (settings &EnvironmentSettingsObject) fetch_request_client_deferred_invoke(algorithm fn ()) {
	mut owner := platform.current_retained_arena()
	if document := settings.responsible_document() {
		// A destroyed document's fetches are terminated. Its native storage,
		// which holds the requests' policy containers, may already have been
		// released, so a late response must not continue main fetch.
		if document.has_been_destroyed() { return }
		storage := document.native_storage()
		if storage != unsafe { nil } { owner = storage }
	}
	defer_fetch_continuation(algorithm, owner)
}

// PendingResponse uses the platform's deferred queue, independently of HTML
// task selection. Only Fetch's response handover queues a networking task.
fn defer_fetch_continuation(algorithm fn (), storage &platform.RetainedArena) {
	mut owner := unsafe { &platform.RetainedArena(storage) }
	if owner != unsafe { nil } { owner.retain() }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut plugin := platform.EventLoopPlugin.the()
	plugin.deferred_invoke(fn [algorithm, mut owner] () {
		defer { if owner != unsafe { nil } { owner.release() } }
		algorithm()
	})
}
