module main

import dom
import platform
import time

// A tab keeps its navigation history and pending replacement work when its
// active DocumentSession changes. BrowserApp supplies shell commands; this
// owner selects history responses and invalidates abandoned navigation work.
struct NavigationController {
mut:
	history                        []HistoryEntry
	history_index                  int = -1
	back_forward_cache             BrowserBackForwardCache
	history_scroll_restoration     ?HistoryScrollRestoration
	navigation_results             chan NavigationResult
	navigation_generation          int
	navigation_fetch_generation    int
	pending_navigation             ?PendingNavigation
	pending_page_preload           ?PendingPagePreload
	navigation_preloaded_resources map[string]PreloadedResource
	pending_native_navigation      ?string
}

struct HistoryEntry {
	url          string
	markup       string
	content_type string = 'text/html'
	// Saved when navigation leaves this entry; traversal and reload restore it.
	scroll_y ?f64
}

struct LoadedPage {
	url                   string
	markup                string
	status                string
	content_type          string
	javascript_url_source ?&dom.Document
	// Compact navigation produces a response locally; this is the source
	// Document.cpp non-Fetch timing fallback, recorded when that response exists.
	monotonic_response_time_ns i64 = time.sys_mono_now()
}

struct NavigationResult {
	generation  int
	add_history bool
	resolved    string
	loaded      ?LoadedPage
	error       string
}

struct PendingNavigation {
	resolved    string
	base        string
	generation  int
	add_history bool
}

// The controller owns the response used when no live session can be restored.
// Preserve the current stored-response policy in one place so navigation can
// later adopt a fuller history/response model without involving browser chrome.
struct HistoryTraversal {
	from_index   int
	target_index int
	response     LoadedPage
}

fn (navigation &NavigationController) history_traversal(delta int) ?HistoryTraversal {
	target := navigation.history_index + delta
	if target < 0 || target >= navigation.history.len { return none }
	entry := navigation.history[target]
	return HistoryTraversal{
		from_index:   navigation.history_index
		target_index: target
		response:     LoadedPage{
			url:          entry.url
			markup:       entry.markup
			status:       'History'
			content_type: entry.content_type
		}
	}
}

// Late worker results retain their generation and are ignored by the owner.
// Invalidate queued fetches as well as active work: a traversal before the
// first window frame must not later launch the navigation it replaced.
fn (mut navigation NavigationController) cancel_pending_navigation() {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	navigation.navigation_generation++
	navigation.navigation_fetch_generation = 0
	navigation.pending_navigation = none
	navigation.pending_native_navigation = none
	navigation.history_scroll_restoration = none
	navigation.cancel_page_preload()
	navigation.navigation_preloaded_resources = map[string]PreloadedResource{}
}

fn (mut app BrowserApp) history_go(delta int) {
	if app.navigation_work_depth > 0 {
		previous := app.deferred_navigation_input or { DeferredNavigationInput{} }
		app.deferred_navigation_input = DeferredNavigationInput{
			history_delta: previous.history_delta + delta
			is_history:    true
		}
		return
	}
	traversal := app.NavigationController.history_traversal(delta) or { return }
	app.save_history_scroll_position()
	app.history_index = traversal.target_index
	app.NavigationController.cancel_pending_navigation()
	app.page_model.traverse_the_history_by_delta(delta)
	if app.traverse_to_a_fragment(traversal.from_index, traversal.target_index) { return }
	if app.restore_back_forward_cached_page(traversal.from_index, traversal.target_index) { return }
	app.start_history_scroll_restoration(voidptr(app.document))
	app.install_loaded_page(traversal.response, false)
}
