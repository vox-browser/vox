module css

import dom

// Chromium matches focus pseudo-classes only in a focused, active frame; the
// LibWeb policy keeps matching the focused area regardless of the window.
fn test_chromium_focus_pseudo_classes_follow_the_embedder_window() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.html)
	mut wrapper := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	field := document.create_element_ns('http://www.w3.org/1999/xhtml', 'input') or { panic(err) }
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(wrapper.as_node()) or { panic(err) }
	mut wrapper_node := unsafe { &dom.Node(wrapper.as_node()) }
	wrapper_node.append_child(field.as_node()) or { panic(err) }
	document.set_focused_area(field.as_node())
	assert element_matches_selector(field, ':focus')
	assert element_matches_selector(wrapper, ':focus-within')
	document.set_embedder_window_active(false)
	assert document.shows_focus_state()
	assert element_matches_selector(field, ':focus')
	document.set_font_rendering_policy(.chromium)
	assert !document.shows_focus_state()
	assert !element_matches_selector(field, ':focus')
	assert !element_matches_selector(wrapper, ':focus-within')
	assert !element_matches_selector(field, ':focus-visible')
	document.set_embedder_window_active(true)
	assert element_matches_selector(field, ':focus')
	assert element_matches_selector(wrapper, ':focus-within')
}
