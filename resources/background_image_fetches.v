module main

import platform

fn (mut app BrowserApp) request_background_resource(image_url string) {
	mut jobs := []ResourceFetchJob{}
	app.enqueue_background_resource(image_url, mut jobs)
	app.start_background_resource_batch(jobs)
}

// Reserve the URL as soon as a scan finds it. Later discoveries in the same
// scan and the paint replay share that pending request.
fn (mut app BrowserApp) enqueue_background_resource(image_url string, mut jobs []ResourceFetchJob) {
	if app.state == .retired || image_url in app.resource_cache
		|| image_url in app.background_resource_pending {
		return
	}
	persistent := platform.enter_persistent()
	owned_url := image_url.clone()
	app.background_resource_pending[owned_url] = true
	platform.leave_persistent(persistent)
	jobs << ResourceFetchJob{url: owned_url, request_type: 'image'}
}

// A discovery pass shares the existing fetch pool, including cancellation and
// completion wakeups, instead of retaining a separate thread for every URL.
fn (mut app BrowserApp) start_background_resource_batch(jobs []ResourceFetchJob) {
	if jobs.len == 0 { return }
	source_url := if app.document != unsafe { nil } { app.document.url.serialize() } else { app.address }
	app.background_resource_jobs += jobs.len
	scope := app.resource_request_scope()
	spawn_resource_fetch_workers_with_scope(jobs, source_url, true, app.background_resource_results, scope)
}
