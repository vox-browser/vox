module html

import dom

fn test_html_rare_concrete_bases_clone_nonce_without_copying_transient_state() {
	mut document := dom.Document.create(dom.URL{value: 'https://origin.example/base/'})
	defer { document.finalize() }
	for name in ['html', 'head', 'title', 'div', 'a'] {
		mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', name) or { panic(err) }
		mut html_element := unsafe { &dom.HTMLElement(element) }
		html_element.set_cryptographic_nonce('private-nonce')
		html_element.set_popover_visibility_state(.showing)
		html_element.set_popover_toggle_task_id(97)
		html_element.set_opened_in_popover_mode('manual')
		element.set_scroll_offset(none, dom.CSSPixelPoint_{x_: 4, y_: 6})
		copy := element.as_node().clone_single_node(document) or { panic(err) }
		html_element_cloned(html_element, copy, false) or { panic(err) }
		mut cloned := unsafe { &dom.HTMLElement(copy.as_element() or { panic('missing clone') }) }
		assert cloned.local_name() == name
		assert cloned.cryptographic_nonce() == 'private-nonce'
		assert cloned.popover_visibility_state() == .hidden
		assert cloned.popover_toggle_task_id() == 0 && cloned.opened_in_popover_mode() == none
		assert cloned.el_scroll_offset() == dom.CSSPixelPoint_{}
		cloned.set_cryptographic_nonce('clone-nonce')
		assert html_element.cryptographic_nonce() == 'private-nonce'
	}
}

fn test_html_rare_hyperlink_cache_reinitializes_after_href_and_document_changes() {
	mut first := dom.Document.create(dom.URL{value: 'https://one.example/base/'})
	mut second := dom.Document.create(dom.URL{value: 'https://two.example/next/'})
	defer { first.finalize() }
	defer { second.finalize() }
	mut element := first.create_element_ns('http://www.w3.org/1999/xhtml', 'a') or { panic(err) }
	element.set_attribute_value('href', 'page?q=1#old')
	html_hyperlink_element_utils_set_the_url(element)
	mut html_element := unsafe { &dom.HTMLElement(element) }
	assert html_element.hyperlink_url_is_initialized()
	assert (html_element.cached_hyperlink_url() or { panic('missing first cache') }).serialize() == 'https://one.example/base/page?q=1#old'
	snapshot := *html_element
	element.set_attribute_value('href', 'replacement')
	assert html_hyperlink_element_utils_href(element) == 'https://one.example/base/replacement'
	assert (snapshot.cached_hyperlink_url() or { panic('lost copied URL') }).serialize() == 'https://one.example/base/page?q=1#old'
	second.adopt_node(element.as_node())
	assert html_hyperlink_element_utils_href(element) == 'https://two.example/next/replacement'
	element.set_attribute_value('href', 'http://[:::')
	assert html_hyperlink_element_utils_href(element) == 'http://[:::'
	assert html_element.cached_hyperlink_url() == none && html_element.hyperlink_url_is_initialized()
}
