// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module html

import dom
import performancetimeline

@[heap]
pub struct VisibilityStateEntry {
pub:
	entry &performancetimeline.PerformanceEntry
}

pub fn VisibilityStateEntry.create(state dom.VisibilityState, timestamp f64) &VisibilityStateEntry {
	return &VisibilityStateEntry{
		entry: &performancetimeline.PerformanceEntry{
			name: if state == .visible { 'visible' } else { 'hidden' }
			entry_type: 'visibility-state'
			start_time: timestamp
			duration: 0
			max_buffer_size: u64(50)
		}
	}
}

fn document_queue_visibility_state_entry(target voidptr, document &dom.Document, initial bool) {
	window := unsafe { &WindowModel(target) }
	mut scope := window.window_or_worker_global_scope()
	mut performance := scope.performance()
	entry := VisibilityStateEntry.create(document.visibility_state_value(),
		if initial { 0.0 } else { performance.now() })
	scope.queue_performance_entry(global_performance_entry(entry.entry))
	scope.add_performance_entry(global_performance_entry(entry.entry))
}
