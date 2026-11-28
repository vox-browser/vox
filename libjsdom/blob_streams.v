// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import fileapi
import html
import libjs
import platform

@[heap]
struct BlobStreamTaskBinding {
	event_loop &html.EventLoop
	task &html.Task
}

fn (mut host Host) blob_stream(mut vm libjs.VM, blob &fileapi.Blob) !libjs.Value {
	charge_buffer_source_work(mut vm, blob.size())!
	host.frame_window(mut vm)!
	settings := unsafe { &html.EnvironmentSettingsObject(host.document.relevant_settings_object()) }
	native, task := settings.get_blob_stream_in_realm_with_task(blob, settings.stream_realm())
	host.blob_stream_tasks[voidptr(native)] = &BlobStreamTaskBinding{event_loop: settings.responsible_event_loop(), task: task}
	return host.wrap_readable_stream(native, none)
}

fn (mut host Host) close_blob_stream_tasks() {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	for _, binding in host.blob_stream_tasks {
		task := binding.task
		matches := fn [task] (candidate &html.Task) bool { return voidptr(candidate) == voidptr(task) }
		mut queue := binding.event_loop.task_queue()
		queue.remove_tasks_matching(matches)
		platform.release_closure(voidptr(matches))
	}
	host.blob_stream_tasks.clear()
}
