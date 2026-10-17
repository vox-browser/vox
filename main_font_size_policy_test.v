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
		assert document.font_rendering_policy() == if address.contains('evil') || address.contains('example') {
			dom.FontRenderingPolicy.libweb
		} else { dom.FontRenderingPolicy.chromium }
		document.finalize()
	}
	mut saved := parse_loaded_browser_navigation_document(LoadedPage{
		url: 'file:///tmp/reddit.html'
		markup: '<!doctype html><base href="https://old.reddit.com/r/worldnews/"><p>saved page</p>'
	}, dom.URL{value: 'file:///tmp/reddit.html'}, none, none, none, false)
	assert saved.font_size_keyword_policy() == .chromium
	assert saved.font_rendering_policy() == .chromium
	saved.finalize()
}

fn test_wikipedia_hosts_select_chromium_rendering() {
	for host in ['wikipedia.org', 'www.wikipedia.org', 'en.wikipedia.org', 'EN.M.WIKIPEDIA.ORG.'] {
		assert browser_host_uses_chromium_rendering(host)
	}
	for host in ['wikipedia.org.evil.test', 'notwikipedia.org', 'wikimedia.org', 'example.com'] {
		assert !browser_host_uses_chromium_rendering(host)
	}
}

fn test_cnn_hosts_and_saved_documents_select_chromium_rendering() {
	for host in ['cnn.com', 'www.cnn.com', 'edition.cnn.com', 'EDITION.CNN.COM.'] {
		assert browser_host_uses_chromium_rendering(host)
	}
	for host in ['cnn.com.example.test', 'notcnn.com', 'cnn.test'] {
		assert !browser_host_uses_chromium_rendering(host)
	}
	mut saved := parse_loaded_browser_navigation_document(LoadedPage{
		url: 'file:///tmp/cnn.html'
		markup: '<!doctype html><base href="https://edition.cnn.com/"><p>CNN capture</p>'
	}, dom.URL{value: 'file:///tmp/cnn.html'}, none, none, none, true)
	defer { saved.finalize() }
	assert saved.font_size_keyword_policy() == .chromium
	assert saved.font_rendering_policy() == .chromium
	assert saved.as_node().is_scripting_enabled()
}

fn test_4chan_hosts_and_saved_boards_select_chromium_rendering() {
	for host in ['4chan.org', 'boards.4chan.org', 'BOARDS.4CHAN.ORG.'] {
		assert browser_host_uses_chromium_rendering(host)
	}
	for host in ['4chan.org.example.test', 'not4chan.org', '4channel.example'] {
		assert !browser_host_uses_chromium_rendering(host)
	}
	mut saved := parse_loaded_browser_navigation_document(LoadedPage{
		url: 'file:///tmp/pol.html'
		markup: '<!doctype html><base href="https://boards.4chan.org/pol/"><p>board capture</p>'
	}, dom.URL{value: 'file:///tmp/pol.html'}, none, none, none, true)
	defer { saved.finalize() }
	assert saved.font_size_keyword_policy() == .chromium
	assert saved.font_rendering_policy() == .chromium
}
