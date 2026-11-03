module main

import browserbookmarks
import browsersettings
import optimizedsites

// All bar consumers read this fixed list. Keep its descriptor outside frame
// workspaces instead of materializing an identical array on each lookup.
const optimized_browser_bar_bookmarks = optimizedsites.bookmarked_sites.map(browserbookmarks.Bookmark{
	url: it.address
	title: it.title
})

fn (app &BrowserApp) optimized_sites_only() bool {
	return app.restrict_to_optimized_sites && !browsersettings.current().allow_any_site
}

fn (app &BrowserApp) address_bar_editable() bool {
	return !app.optimized_sites_only()
}

fn (app &BrowserApp) browser_destination_allowed(address string) bool {
	return !app.optimized_sites_only() || optimizedsites.allows(address)
		|| address in ['about:blank', 'about:home', browser_new_tab_url, browser_history_url]
}

fn (mut app BrowserApp) allow_browser_destination(address string) bool {
	if app.browser_destination_allowed(address) {
		app.navigation_restriction_notice = ''
		return true
	}
	app.navigation_restriction_notice = 'Use a bookmark, or enable “Allow opening any site” in Settings.'
	app.load_status = 'Navigation blocked'
	app.status = app.load_status
	app.cancel_address_bar()
	app.update_browser_chrome(app.browser_chrome.width, app.browser_chrome.height)
	request_browser_frame()
	return false
}

fn (app &BrowserApp) browser_bar_bookmarks() []browserbookmarks.Bookmark {
	if app.optimized_sites_only() {
		return optimized_browser_bar_bookmarks
	}
	return app.bookmarks.items
}
