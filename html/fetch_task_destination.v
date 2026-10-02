// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// Fetch/Infrastructure/Task.cpp and PendingResponse's deferred callback boundary.
module html

pub fn (settings &EnvironmentSettingsObject) fetch_request_client_queue_fetch_task(algorithm fn ()) u64 {
	return queue_a_task(.networking, settings.responsible_event_loop(), settings.responsible_document(), algorithm)
}

pub fn (settings &EnvironmentSettingsObject) fetch_request_client_cancel_fetch_task(task_id u64) {
	mut owner := settings.responsible_event_loop()
	mut queue := owner.task_queue()
	queue.remove_tasks_matching(fn [task_id] (task &Task) bool { return task.id == task_id })
}

pub fn (settings &EnvironmentSettingsObject) fetch_request_client_deferred_invoke(algorithm fn ()) {
	queue_a_task(.unspecified, settings.responsible_event_loop(), none, algorithm)
}
