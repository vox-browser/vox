module main

import css
import html

fn test_capture_focus_uses_live_dom_state_without_rewriting_author_markup() {
	mut document := html.parse_document('<!doctype html><style>#banner:focus-visible{outline:2px solid}</style><div id="banner" tabindex="-1">Consent</div>')
	defer { document.finalize() }
	css.install_document_selector_query_hook(document)
	target := document.get_element_by_id('banner') or { panic('target') }
	before := target.as_node().serialize_fragment(.no, .outer) or { panic('serialize') }
	assert restore_capture_focus(document, 'banner')!
	assert target.is_focused() && target.should_indicate_focus()
	assert !restore_capture_focus(document, 'banner')!
	assert before == (target.as_node().serialize_fragment(.no, .outer) or { panic('serialize') })
	assert !restore_capture_focus(document, '')!
}

fn test_capture_focus_rejects_missing_duplicate_and_nonfocusable_targets() {
	for markup in ['<div></div>', '<div id="target"></div>',
		'<button id="target">One</button><button id="target">Two</button>'] {
		mut document := html.parse_document('<!doctype html>${markup}')
		defer { document.finalize() }
		css.install_document_selector_query_hook(document)
		mut rejected := false
		restore_capture_focus(document, 'target') or { rejected = true }
		assert rejected
	}
}
