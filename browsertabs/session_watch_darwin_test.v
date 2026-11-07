module browsertabs

import time

#flag darwin -framework CoreFoundation
#include <CoreFoundation/CoreFoundation.h>

fn C.CFRunLoopRunInMode(mode voidptr, seconds f64, return_after_source_handled bool) i32
fn C.vox_tabs_unwatch()

// The default run-loop mode also drains the main dispatch queue.
fn run_main_loop(seconds f64, return_after_source_handled bool) {
	C.CFRunLoopRunInMode(voidptr(C.kCFRunLoopDefaultMode), seconds, return_after_source_handled)
}

struct WatchCounts {
mut:
	changes int
}

fn count_session_change(context voidptr) {
	mut counts := unsafe { &WatchCounts(context) }
	counts.changes++
}

fn wait_for_session_change(counts &WatchCounts, previous int) bool {
	deadline := time.now().add(2 * time.second)
	for counts.changes == previous && time.now() < deadline {
		run_main_loop(0.02, true)
	}
	return counts.changes > previous
}

fn test_watching_wakes_a_tab_when_another_process_saves_the_session() {
	mut session := create(Frame{ width: 800, height: 600 })!
	defer { session.leave() or {} }
	mut counts := &WatchCounts{}
	assert session.watch(count_session_change, counts)
	// Another process's save, here through a second session handle.
	mut other := &Session{ folder: session.folder, id: session.id }
	other.request_reopen()!
	assert wait_for_session_change(counts, 0)
	// Watching a detached group replaces the previous directory.
	mut detached := session.detach_self(Frame{ width: 800, height: 600 })!
	defer { detached.leave() or {} }
	assert detached.watch(count_session_change, counts)
	// Deliver anything the detach itself reported before counting.
	run_main_loop(0.1, false)
	before := counts.changes
	detached.request_reopen()!
	assert wait_for_session_change(counts, before)
	C.vox_tabs_unwatch()
	run_main_loop(0.1, false)
	after := counts.changes
	detached.request_reopen()!
	assert !wait_for_session_change(counts, after)
}
