module main

import dom

fn test_old_reddit_navigation_selects_browser_font_sizes_without_changing_other_sites() {
	for address in ['https://old.reddit.com/r/worldnews/', 'https://OLD.REDDIT.COM/r/news/',
		'https://example.com/', 'https://old.reddit.com.evil.test/'] {
		mut document := parse_loaded_browser_navigation_document(LoadedPage{
			url: address
			markup: '<!doctype html><p>font policy</p>'
			content_type: 'text/html;charset=utf-8'
		}, dom.URL{value: address}, none, none, none, false)
		assert document.font_size_keyword_policy() == if address.contains('evil') || address.contains('example') {
			dom.FontSizeKeywordPolicy.libweb
		} else { dom.FontSizeKeywordPolicy.chromium }
		document.finalize()
	}
	mut saved := parse_loaded_browser_navigation_document(LoadedPage{
		url: 'file:///tmp/reddit.html'
		markup: '<!doctype html><base href="https://old.reddit.com/r/worldnews/"><p>saved page</p>'
	}, dom.URL{value: 'file:///tmp/reddit.html'}, none, none, none, false)
	assert saved.font_size_keyword_policy() == .chromium
	saved.finalize()
}
