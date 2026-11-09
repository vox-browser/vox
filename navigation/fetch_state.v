module main

import browsernet
import platform

fn (mut app BrowserApp) start_navigation_fetch(pending PendingNavigation) {
	app.cancel_navigation_fetch()
	// A queued worker can outlive the document/frame that requested navigation.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	resolved := pending.resolved.clone()
	base := pending.base.clone()
	scope := browsernet.new_request_scope()
	app.navigation_request_scope = scope
	app.navigation_fetch_generation = pending.generation
	scope.retain()
	spawn fetch_page_in_background_with_scope(resolved, base, pending.generation,
		pending.add_history, app.navigation_results, scope)
}

fn (app &BrowserApp) has_navigation_fetch_in_flight() bool {
	return app.navigation_fetch_generation > 0
		&& app.navigation_fetch_generation == app.navigation_generation
}
