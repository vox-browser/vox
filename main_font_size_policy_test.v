module main

import css
import dom
import html
import page

fn test_browser_navigation_uses_chromium_rendering_for_all_urls() {
	for address in ['https://example.com/', 'http://localhost:8000/',
		'https://old.reddit.com/r/worldnews/', 'https://en.wikipedia.org/',
		'https://edition.cnn.com/', 'https://boards.4chan.org/pol/',
		'https://asgardpvp.com/', 'https://other.example.test/',
		'file:///tmp/page.html', 'about:blank', 'data:text/html,page'] {
		mut document := parse_loaded_browser_navigation_document(LoadedPage{
			url: address
			markup: '<!doctype html><p>font policy</p>'
			content_type: 'text/html;charset=utf-8'
		}, dom.URL{value: address}, none, none, none, false)
		assert document.font_size_keyword_policy() == .chromium, address
		assert document.font_rendering_policy() == .chromium, address
		document.finalize()
	}
}

fn test_saved_browser_documents_use_chromium_rendering_regardless_of_base_url() {
	for base in ['', '<base href="https://old.reddit.com/">',
		'<base href="https://unrelated.example/assets/">'] {
		mut document := parse_loaded_browser_navigation_document(LoadedPage{
			url: 'file:///tmp/saved.html'
			markup: '<!doctype html>${base}<p>saved page</p>'
		}, dom.URL{value: 'file:///tmp/saved.html'}, none, none, none, true)
		assert document.font_size_keyword_policy() == .chromium
		assert document.font_rendering_policy() == .chromium
		assert document.as_node().is_scripting_enabled()
		document.finalize()
	}
}

fn test_browser_document_creation_installs_chromium_rendering_before_parsing() {
	address := dom.URL{value: 'https://example.test/'}
	owner := page.Page.create(1.0)!
	for with_page in [false, true] {
		mut owner_page := ?&dom.Page(none)
		if with_page { owner_page = unsafe { &dom.Page(owner) } }
		mut document := create_browser_navigation_document(address, address.origin(), none,
			owner_page)!
		assert document.document_element() == none
		assert document.font_size_keyword_policy() == .chromium
		assert document.font_rendering_policy() == .chromium
		document.set_document_type(.html)
		html.parse_html_from_a_string(document,
			'<!doctype html><p id="small" style="font-size:x-small">small</p>')
		document.update_style()
		element := document.get_element_by_id('small')?
		bridge := dom.AbstractElement.new(element, none).computed_properties()?
		style := css.computed_properties_from_dom(bridge)?
		assert style.font_size() == css.CSSPixels.new(10)
		document.finalize()
	}
}

fn test_browser_navigation_entry_points_use_chromium_rendering() {
	address := dom.URL{value: 'https://example.test/'}
	markup := '<!doctype html><p>navigation</p>'
	mut documents := [parse_browser_navigation_document(markup, address, none),
		parse_browser_navigation_document_with_previous(markup, address, none, none),
		parse_browser_navigation_document_with_response_time(markup, address, none, none, 0),
		parse_browser_navigation_document_with_scripting(markup, address, none, none,
			none, 0, false)]
	for mut document in documents {
		assert document.font_size_keyword_policy() == .chromium
		assert document.font_rendering_policy() == .chromium
		document.finalize()
	}
}
