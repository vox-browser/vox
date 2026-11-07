module main

import dom
import os

fn test_explicit_layout_font_selects_fixture_policies_before_navigation_and_preload() {
	previous := os.getenv_opt('LADYBIRD_LAYOUT_TEST_FONT')
	defer {
		if value := previous {
			os.setenv('LADYBIRD_LAYOUT_TEST_FONT', value, true)
		} else {
			os.unsetenv('LADYBIRD_LAYOUT_TEST_FONT')
		}
	}
	for configured in [false, true, false] {
		if configured {
			os.setenv('LADYBIRD_LAYOUT_TEST_FONT', '/canonical/layout-font.ttf', true)
		} else {
			os.unsetenv('LADYBIRD_LAYOUT_TEST_FONT')
		}
		address := dom.URL{ value: 'https://example.test/' }
		mut navigation := create_browser_navigation_document(address, address.origin(), none, none)!
		defer { navigation.finalize() }
		assert navigation.document_element() == none
		loaded := LoadedPage{ url: address.value, markup: '<!doctype html><p>font policy</p>' }
		mut preload := parse_page_preload_document(loaded, true)
		defer { preload.finalize() }
		for document in [navigation, preload] {
			if configured {
				assert document.font_size_keyword_policy() == .libweb
				assert document.font_rendering_policy() == .libweb
			} else {
				assert document.font_size_keyword_policy() == .chromium
				assert document.font_rendering_policy() == .chromium
			}
		}
	}
}
