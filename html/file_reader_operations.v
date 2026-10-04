// Copyright (c) 2023-2026, Shannon Booth <shannon@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// FileReader.cpp's relevant JS-global task/event operations retain actual
// Window/Worker settings; this is not DOM::Node's current-Document overload.
module html

import fileapi

pub fn (settings &EnvironmentSettingsObject) create_file_reader() !&fileapi.FileReader {
	// Source constructor verifies its global is a WindowOrWorkerGlobalScope.
	settings.window_or_worker_global_scope() or {
		panic('Source VERIFY: FileReader requires a Window or Worker global')
	}
	context := fileapi.FileReaderGlobalContext{
		global_object:             settings.global_object()
		queue_file_reading_task:   fn [settings] (steps fn ()) u64 {
			// Source queue_global_task reads the global's associated Document at
			// queue time. Its relevant agent/Realm remains the creation owner.
			return queue_a_task(.file_reading, settings.responsible_event_loop(),
				settings.responsible_document(), steps)
		}
		currently_running_task_id: fn [settings] () u64 {
			task := settings.responsible_event_loop().currently_running_task() or {
				panic('Source VERIFY: FileReader task requires a currently running task')
			}
			return task.id()
		}
		remove_affiliated_tasks:   fn [settings] (ids []u64) {
			mut queue := settings.responsible_event_loop().task_queue()
			queue.remove_tasks_matching(fn [ids] (task &Task) bool {
				return task.id() in ids
			})
		}
		event_timestamp:           fn [settings] () f64 {
			return settings.global_relative_event_timestamp()
		}
	}
	return fileapi.FileReader.create_in_global_context(context)
}
