module main

fn (mut app BrowserApp) start_navigation_fetch(pending PendingNavigation) {
	app.navigation_fetch_generation = pending.generation
	spawn fetch_page_in_background(pending.resolved, pending.base, pending.generation,
		pending.add_history, pending.had_cached_page, app.navigation_results)
}

fn (app &BrowserApp) has_navigation_fetch_in_flight() bool {
	return app.navigation_fetch_generation > 0
		&& app.navigation_fetch_generation == app.navigation_generation
}
