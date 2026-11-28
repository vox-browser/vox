module main

import browsernet
import mimesniff

// Bound the work before publishing the main-resource response, including a
// scan that has to fall back to the detached parser near the end of the page.
const max_early_stylesheet_markup_bytes = 256 * 1024

struct NavigationStylesheetPreloads {
	count   int
	results chan PreloadedResource
}

// Run the normal stylesheet preload batch on the fetch thread while the first
// native window opens. Only the tokenized path avoids building a detached DOM
// or needing the viewport. A failed eligibility check leaves discovery to the
// navigation owner as usual.
fn start_early_navigation_stylesheets(loaded LoadedPage, policy BrowserScriptPolicy,
	scope &browsernet.RequestScope) ?NavigationStylesheetPreloads {
	if policy == .disabled || scope.is_cancelled() || loaded.markup.len > max_early_stylesheet_markup_bytes
		|| !browser_scripting_enabled(loaded.url, policy) {
		return none
	}
	if !loaded.url.starts_with('http://') && !loaded.url.starts_with('https://') { return none }
	mime := mimesniff.MimeType.parse(loaded.content_type) or { return none }
	if mime.essence() != 'text/html' { return none }
	discovery := tokenized_navigation_preloads(loaded) or { return none }
	urls := discovery.urls.filter((discovery.types[it] or { 'image' }) == 'stylesheet')
	mut pending := PendingPagePreload{
		loaded:   loaded
		requests: scope
		results:  chan PreloadedResource{cap: urls.len}
	}
	queue_navigation_preloads(mut pending, urls, discovery.types, map[string]PreloadedResource{})
	return NavigationStylesheetPreloads{ count: pending.remaining, results: pending.results }
}
