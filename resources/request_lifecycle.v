module main

import browsernet
import platform

fn (mut app BrowserApp) resource_request_scope() &browsernet.RequestScope {
	return app.background_resource_scope or {
		created := browsernet.new_request_scope()
		app.background_resource_scope = created
		created
	}
}

fn publish_navigation_result(result NavigationResult, results chan NavigationResult, scope &browsernet.RequestScope) {
	_ = browsernet.publish_result(result, results, scope)
}

fn (mut app NavigationController) take_navigation_fetch_scope() ?&browsernet.RequestScope {
	scope := app.navigation_request_scope
	app.navigation_request_scope = none
	app.navigation_fetch_generation = 0
	return scope
}

fn (mut app NavigationController) cancel_navigation_fetch() {
	if scope := app.take_navigation_fetch_scope() {
		scope.cancel()
		scope.release()
	}
}

fn (mut app BrowserApp) cancel_background_resource_fetches() {
	mut session := app.document_session()
	session.retire_background_resources()
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	app.background_resource_pending = map[string]bool{}
	// Completions already queued for the outgoing document cannot be applied
	// to a replacement document requesting the same URL.
	app.background_resource_results = chan PreloadedResource{cap: max_cached_resources}
}
