module main

import dom

fn test_asgard_live_and_saved_documents_select_chromium_rendering() {
	for address in ['https://asgardpvp.com/', 'file:///tmp/asgard.html'] {
		mut document := parse_loaded_browser_navigation_document(LoadedPage{
			url: address
			markup: '<!doctype html><base href="https://asgardpvp.com/"><p>font policy</p>'
		}, dom.URL{value: address}, none, none, none, false)
		assert document.font_size_keyword_policy() == .chromium
		assert document.font_rendering_policy() == .chromium
		document.finalize()
	}
}
