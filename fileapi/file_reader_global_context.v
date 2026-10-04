// Copyright (c) 2023-2026, Shannon Booth <shannon@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// FileReader's actual relevant-global operations cross FileAPI → HTML here.
module fileapi

import dom

pub struct FileReaderGlobalContext {
pub:
	global_object             &dom.EventTarget @[required]
	queue_file_reading_task   fn (fn ()) u64   @[required]
	currently_running_task_id fn () u64        @[required]
	remove_affiliated_tasks   fn ([]u64)       @[required]
	event_timestamp           fn () f64        @[required]
}

// The context retains the real creation global and its Realm/settings hooks.
// The standalone constructor remains a separate compatibility entry point.
pub fn FileReader.create_in_global_context(context FileReaderGlobalContext) &FileReader {
	return &FileReader{
		relevant_global_object_: context.global_object
		global_context_:         context
	}
}

fn (mut reader FileReader) queue_owned_file_reading_task(context FileReaderGlobalContext, task FileReaderTask) {
	owner_handle := voidptr(&reader)
	id := context.queue_file_reading_task(fn [owner_handle, context, task] () {
		current_task_id := context.currently_running_task_id()
		mut actual_reader := unsafe { &FileReader(owner_handle) }
		task(mut actual_reader)
		// Source removes the currently executing task after its callback. An
		// abort/reentrant queue operation inside the callback can change this set.
		actual_reader.pending_task_ids_ = actual_reader.pending_task_ids_.filter(it != current_task_id)
	})
	reader.pending_task_ids_ << id
}
