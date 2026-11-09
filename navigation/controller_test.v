module main

import page

fn test_history_traversal_reconstructs_the_selected_response_without_mutating_history() {
	navigation := NavigationController{
		history:               [
			HistoryEntry{ url: 'https://history.example/first', markup: '<p>first</p>' },
			HistoryEntry{ url: 'https://history.example/plain', markup: 'a < b', content_type: 'text/plain', scroll_y: 240 },
			HistoryEntry{ url: 'https://history.example/third', markup: '<p>third</p>' },
		]
		history_index:         2
		navigation_generation: 7
	}
	traversal := navigation.history_traversal(-1) or { panic('missing history traversal') }
	assert traversal.from_index == 2
	assert traversal.target_index == 1
	assert traversal.response.url == 'https://history.example/plain'
	assert traversal.response.markup == 'a < b'
	assert traversal.response.content_type == 'text/plain'
	assert traversal.response.status == 'History'
	assert traversal.response.monotonic_response_time_ns > 0
	assert navigation.history_index == 2
	assert navigation.navigation_generation == 7
	assert navigation.history[1].scroll_y? == 240
}

fn test_out_of_range_history_traversal_leaves_pending_navigation_untouched() {
	navigation := NavigationController{
		history:               [HistoryEntry{ url: 'https://history.example/only' }]
		history_index:         0
		navigation_generation: 3
		pending_navigation:    PendingNavigation{
			resolved:   'https://history.example/pending'
			generation: 3
		}
	}
	if _ := navigation.history_traversal(-1) {
		assert false
	}
	if _ := navigation.history_traversal(1) {
		assert false
	}
	assert navigation.history_index == 0
	assert navigation.navigation_generation == 3
	pending := navigation.pending_navigation or { panic('lost pending navigation') }
	assert pending.resolved == 'https://history.example/pending'
	assert pending.generation == 3
}

fn test_navigation_cancellation_retires_discovery_and_invalidates_queued_and_active_work() {
	discovery := parse_page_preload_document(LoadedPage{
		url:          'https://history.example/discovery'
		markup:       '<!doctype html><p>preload discovery</p>'
		content_type: 'text/html'
	}, false)
	mut navigation := NavigationController{
		history:                        [HistoryEntry{ url: 'https://history.example/kept' }]
		history_index:                  0
		navigation_generation:          9
		navigation_fetch_generation:    9
		pending_navigation:             PendingNavigation{
			resolved:   'https://history.example/abandoned'
			generation: 9
		}
		pending_native_navigation:      'https://history.example/native'
		pending_page_preload:           PendingPagePreload{
			generation:         9
			discovery_document: discovery
		}
		navigation_preloaded_resources: {
			'https://history.example/old.css': PreloadedResource{ url: 'https://history.example/old.css', body: 'p{color:red}' }
		}
	}
	navigation.cancel_pending_navigation()
	assert navigation.navigation_generation == 10
	assert navigation.navigation_fetch_generation == 0
	assert navigation.pending_navigation == none
	assert navigation.pending_native_navigation == none
	has_pending_preload := navigation.pending_page_preload != none
	assert !has_pending_preload
	assert navigation.navigation_preloaded_resources.len == 0
	assert discovery.has_been_destroyed()
	assert discovery.native_storage() == unsafe { nil }
	assert navigation.history_index == 0
	assert navigation.history.len == 1
	assert navigation.history[0].url == 'https://history.example/kept'
}

fn test_history_traversal_cancels_a_fetch_waiting_for_the_first_window_frame() {
	mut app := &BrowserApp{
		page_model:      page.Page.create(1) or { panic(err) }
		viewport_width:  320
		viewport_height: 200
	}
	defer { app.dispose_browser_tab() }
	for name in ['first', 'second'] {
		app.install_loaded_page(LoadedPage{
			url:          'https://history.example/${name}'
			markup:       '<!doctype html><p>${name}</p>'
			content_type: 'text/html'
		}, true)
	}
	generation := app.navigation_generation
	app.pending_navigation = PendingNavigation{
		resolved:    'https://history.example/not-started'
		generation:  generation
		add_history: true
	}
	app.navigation_fetch_generation = generation
	app.pending_native_navigation = 'https://history.example/not-dispatched'
	app.history_go(-1)
	assert app.history_index == 0
	assert app.document.url_string() == 'https://history.example/first'
	assert app.navigation_generation == generation + 1
	assert app.navigation_fetch_generation == 0
	assert app.pending_navigation == none
	assert app.pending_native_navigation == none
}
