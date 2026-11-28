module main

import browsernet
import os
import platform

// VOX_DEFER_INITIAL_NAVIGATION_FETCH=1 holds the first fetch of a launch
// until the first window frame, as before, for matched comparisons.
const defer_initial_navigation_fetch = os.getenv('VOX_DEFER_INITIAL_NAVIGATION_FETCH') != ''
const disable_early_navigation_stylesheets = os.getenv('VOX_DISABLE_EARLY_NAVIGATION_STYLESHEETS') != ''

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
	// A launch can overlap stylesheet fetches with native window setup. The
	// worker has no access to the tab's resource cache or page model.
	policy := if !disable_early_navigation_stylesheets && !disable_tokenized_navigation_preloads
		&& !app.initial_window_frame_presented && app.resource_cache.len == 0
		&& (app.page_model == unsafe { nil } || app.page_model.is_scripting_enabled()) {
		app.script_policy
	} else {
		BrowserScriptPolicy.disabled
	}
	spawn fetch_page_in_background_with_scope(resolved, base, pending.generation,
		pending.add_history, app.navigation_results, scope, policy)
}

fn (mut app BrowserApp) adopt_navigation_stylesheets(result NavigationResult, loaded LoadedPage) bool {
	stylesheets := result.stylesheets or { return false }
	scope := app.take_navigation_fetch_scope() or { return false }
	_ = prepare_markup_render_heap(loaded.markup, true)
	app.pending_page_preload = PendingPagePreload{
		loaded: loaded
		add_history: result.add_history
		generation: result.generation
		requests: scope
		results: stylesheets.results
		remaining: stylesheets.count
	}
	// Responses can already be queued. Consume them in this frame even when
	// the worker's wake was coalesced with the main-resource wake.
	app.poll_page_preload()
	return true
}

fn (app &BrowserApp) has_navigation_fetch_in_flight() bool {
	return app.navigation_fetch_generation > 0
		&& app.navigation_fetch_generation == app.navigation_generation
}
