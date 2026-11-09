module main

import platform

// Each spawned background job publishes exactly one response, including on
// failure. Polling consumes that job; retirement hands the remaining responses
// to a finite drain so producers cannot block behind an abandoned full queue.
// The drain owns only the channel and count, never the document or session.
fn (mut session DocumentSession) retire_background_resources() {
	jobs := session.background_resource_jobs
	session.background_resource_jobs = 0
	// Scoped producers may suppress their response after cancellation. They
	// wake from a full queue themselves, so no fixed-count drain may wait here.
	if scope := session.background_resource_scope {
		scope.cancel()
		scope.release()
		session.background_resource_scope = none
		return
	}
	if jobs == 0 { return }
	results := session.background_resource_results
	persistent := platform.enter_persistent()
	spawn drain_retired_session_resources(results, jobs)
	platform.leave_persistent(persistent)
}

fn drain_retired_session_resources(results chan PreloadedResource, jobs int) {
	for _ in 0 .. jobs {
		_ = <-results
	}
}
