module html

import dom

fn test_document_csp_hook_uses_translated_inline_checks() {
	document := parse_document('<!doctype html><style id="style">body { color: red }</style><button id="button"></button>')
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.enforce_meta_csp("style-src 'none'; script-src-attr 'none'")
	style := document.get_element_by_id('style') or { panic('missing style') }
	button := document.get_element_by_id('button') or { panic('missing button') }
	assert document.should_block_inline_content(style, 'style', style.as_node().child_text_content())
	assert document.should_block_inline_content(button, 'script-attribute', 'alert(1)')
}

fn test_dom_inline_style_and_event_handler_call_sites_use_csp_hook() {
	document := parse_document('<!doctype html><style id="style">body { color: red }</style><button id="button"></button>')
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.enforce_meta_csp("style-src 'none'; script-src-attr 'none'")
	style := document.get_element_by_id('style') or { panic('missing style') }
	button := document.get_element_by_id('button') or { panic('missing button') }

	mut style_base := html_style_element_base(unsafe { &dom.HTMLStyleElement(style) })
	style_base.update_a_style_block()
	assert style_base.sheet() == none

	event_target := unsafe { &dom.EventTarget(button.as_node()) }
	event_target.element_event_handler_attribute_changed('click', 'alert(1)')
	assert !event_target.has_event_listener('click')

	allowed_document := parse_document('<!doctype html><button id="allowed"></button>')
	allowed_button := allowed_document.get_element_by_id('allowed') or { panic('missing allowed button') }
	allowed_target := unsafe { &dom.EventTarget(allowed_button.as_node()) }
	allowed_target.element_event_handler_attribute_changed('click', 'alert(1)')
	assert allowed_target.has_event_listener('click')
}

fn test_document_csp_hook_preserves_nonce_matching() {
	document := parse_document('<!doctype html><style id="style" nonce="abc">body { color: red }</style>')
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.enforce_meta_csp("style-src 'nonce-abc'")
	style := document.get_element_by_id('style') or { panic('missing style') }
	assert !document.should_block_inline_content(style, 'style', style.as_node().child_text_content())
}
