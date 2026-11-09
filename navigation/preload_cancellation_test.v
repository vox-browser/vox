module main

import browsernet

fn test_replacing_a_pending_preload_cancels_its_request_scope() {
	scope := browsernet.new_request_scope()
	// The observer owns a reference independently of the pending navigation.
	scope.retain()
	defer { scope.release() }
	mut app := BrowserApp{
		pending_page_preload: PendingPagePreload{
			requests: scope
			results:  chan PreloadedResource{cap: 1}
		}
	}
	app.cancel_page_preload()
	assert app.pending_page_preload == none
	assert scope.is_cancelled()
	// An already retired navigation has no owner reference left to release.
	app.cancel_page_preload()
}
