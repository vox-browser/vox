module main

import css
import dom
import html
import page

@[heap]
struct DocumentOwnerConstructionCounter {
mut:
	calls int
}

fn test_native_navigation_page_exists_during_font_and_dom_construction_before_parser() {
	owner := page.Page.create(1)!
	calls := &DocumentOwnerConstructionCounter{}
	dom.install_document_font_face_set_factory(fn [owner, calls] (document &dom.Document) dom.FontFaceSet {
		mut count := unsafe { &DocumentOwnerConstructionCounter(calls) }
		count.calls++
		assert document.has_page()
		assert voidptr(document.page()) == voidptr(owner)
		assert document.document_element() == none
		assert document.url.serialize() == 'https://final.example/path/page'
		assert document.relevant_settings_object() != unsafe { nil }
		return css.css_style_computer_for(document).font_face_set_
	})
	defer {
		dom.install_document_font_face_set_factory(fn (document &dom.Document) dom.FontFaceSet {
			return css.css_style_computer_for(document).font_face_set_
		})
	}
	document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><base href="../assets/"><p>created</p>', dom.URL{value: 'https://final.example/path/page'}, none, none, unsafe { &dom.Page(owner) }, 123456700000)
	assert calls.calls == 1
	assert document.base_url().serialize() == 'https://final.example/assets/'
	assert document.url.serialize() == 'https://final.example/path/page'
	assert document.load_timing_info.navigation_start_time == 123456.7
}

fn test_install_loaded_page_parser_observes_owning_page_preference_and_final_url() {
	$if !darwin {
		return
	}
	mut owner := page.Page.create(1)!
	owner.set_is_scripting_enabled(false)
	mut app := BrowserApp{ page_model: owner, layout_tree_only: true, viewport_width: 320, viewport_height: 200 }
	app.install_loaded_page(LoadedPage{
		url:          'https://final.example/path/page'
		content_type: 'text/html'
		markup:       '<!doctype html><base href="../assets/"><body><noscript><b id="fallback">disabled</b></noscript>'
	}, false)
	mut document := app.document
	defer { document.finalize() }
	assert voidptr(document.page()) == voidptr(owner)
	assert document.get_element_by_id('fallback') != none
	assert document.as_node().is_scripting_disabled()
	assert document.url.serialize() == 'https://final.example/path/page'
	assert document.base_url().serialize() == 'https://final.example/assets/'
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert html.is_scripting_disabled_for_settings(settings)
	assert app.js_messages == []
}
