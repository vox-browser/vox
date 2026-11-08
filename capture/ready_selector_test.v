module main

import dom

fn test_capture_ready_selector_is_optional_and_requires_a_document_when_set() {
	assert capture_ready_selector_matches(unsafe { nil }, '')
	assert !capture_ready_selector_matches(unsafe { nil }, '#ready')
}

fn test_capture_ready_selector_observes_async_attribute_and_tree_changes() {
	mut document := parse_browser_navigation_document('<!doctype html><button id="ready" aria-disabled="true">Sponsor</button>', dom.URL{value:'https://github.com/vlang/v'}, none)
	defer { document.finalize() }
	selector := '#ready:not([aria-disabled="true"])'
	assert !capture_ready_selector_matches(document, selector)
	mut button := document.get_element_by_id('ready')?
	button.set_attribute_value('aria-disabled', 'false')
	assert capture_ready_selector_matches(document, selector)
	button.as_node().remove(false)
	assert !capture_ready_selector_matches(document, selector)
}

fn test_capture_ready_selector_does_not_accept_missing_or_invalid_selectors() {
	mut document := parse_browser_navigation_document('<!doctype html><p>content</p>', dom.URL{value:'https://example.org/'}, none)
	defer { document.finalize() }
	assert !capture_ready_selector_matches(document, '.missing')
	assert !capture_ready_selector_matches(document, '[')
}
