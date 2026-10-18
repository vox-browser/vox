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
