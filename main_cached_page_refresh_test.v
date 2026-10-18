module main

// A cached page is installed on the frame after the chrome-only first frame.
// Its network refresh starts with that first frame, so the response can
// arrive while the cached page is laid out rather than after it is painted.
fn test_cached_page_refresh_starts_with_the_chrome_only_frame() {
	mut app := BrowserApp{
		navigation_generation: 3
		navigation_results:    chan NavigationResult{cap: 1}
		pending_cached_page:   PendingCachedPage{
			loaded:     LoadedPage{
				url:    'about:blank'
				markup: '<p>cached</p>'
			}
			generation: 3
		}
		pending_navigation:    PendingNavigation{
			resolved:        'about:blank'
			generation:      3
			had_cached_page: true
		}
	}
	app.begin_deferred_cached_page()
	assert app.pending_navigation == none
	assert app.pending_cached_page != none
	result := <-app.navigation_results
	assert result.generation == 3
	assert result.had_cached_page
	loaded := result.loaded or { panic('missing refreshed page') }
	assert loaded.url == 'about:blank'
}

// A refreshed page that arrives with background resources queued replaces the
// cached document first. The outgoing document's resources stay queued until
// the next frame, which applies them to the replacement.
fn test_refreshed_page_installs_before_queued_background_resources() {
	mut app := BrowserApp{
		navigation_generation:       4
		navigation_results:          chan NavigationResult{cap: 1}
		background_resource_results: chan PreloadedResource{cap: 1}
		background_resource_pending: {
			'https://refresh-order.test/1s.jpg': true
		}
	}
	app.install_loaded_page(LoadedPage{
		url:          'https://refresh-order.test/catalog'
		content_type: 'text/html'
		markup:       '<!doctype html><p>cached</p>'
	}, false)
	cached := voidptr(app.document)
	app.document_presented = true
	app.navigation_results <- NavigationResult{
		generation:      4
		had_cached_page: true
		resolved:        'https://refresh-order.test/catalog'
		loaded:          LoadedPage{
			url:          'https://refresh-order.test/catalog'
			content_type: 'text/html'
			markup:       '<!doctype html><p>refreshed</p>'
		}
	}
	app.background_resource_results <- PreloadedResource{
		url:          'https://refresh-order.test/1s.jpg'
		error:        'not fetched'
		request_type: 'image'
	}
	app.poll_navigation_and_background_resources(true)
	assert voidptr(app.document) != cached
	assert app.markup.contains('refreshed')
	assert 'https://refresh-order.test/1s.jpg' in app.background_resource_pending
	assert app.background_resource_results.len == 1
	app.poll_navigation_and_background_resources(true)
	assert 'https://refresh-order.test/1s.jpg' !in app.background_resource_pending
	assert app.background_resource_results.len == 0
}
