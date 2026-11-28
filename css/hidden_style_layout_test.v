module css

import dom

fn hidden_layout_child(mut document dom.Document, mut parent dom.Element, tag string, class_name string) &dom.Element {
	mut element := document.create_element(tag) or { panic(err) }
	if class_name != '' { element.set_attribute_value('class', class_name) }
	mut parent_node := parent.as_node()
	parent_node.append_child(element.as_node()) or { panic(err) }
	return element
}

fn hidden_layout_clear_tree_flags(node &dom.Node) {
	mut mutable := unsafe { &dom.Node(node) }
	mutable.set_needs_layout_tree_update(false, .style_change)
	mutable.set_child_needs_layout_tree_update(false)
	for child in node.children { hidden_layout_clear_tree_flags(child) }
}

fn hidden_layout_tree_dirty(document &dom.Document) bool {
	node := document.as_node()
	return node.needs_layout_tree_update_() || node.child_needs_layout_tree_update_()
}

// Elements that render no box before or after a style update, and insertions
// below an element that renders none, leave the layout tree untouched; boxes
// that can appear still mark their parent.
fn test_boxless_insertions_and_styles_leave_the_layout_tree_clean() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	document.set_navigable(&dom.Navigable{ active_document_: document })
	document.set_viewport_rect(dom.Rect{ width: 800, height: 600 })
	mut html := document.create_element('html') or { panic(err) }
	mut document_node := document.as_node()
	document_node.append_child(html.as_node()) or { panic(err) }
	mut head := hidden_layout_child(mut document, mut html, 'head', '')
	mut body := hidden_layout_child(mut document, mut html, 'body', '')
	mut style := hidden_layout_child(mut document, mut head, 'style', '')
	mut style_node := style.as_node()
	style_node.append_child(document.create_text_node('.hidden { display: none }').as_node()) or { panic(err) }
	document.update_style()
	hidden_layout_clear_tree_flags(document.as_node())

	// A hidden container, laid out once (its insertion marks <body>).
	mut hidden := hidden_layout_child(mut document, mut body, 'div', 'hidden')
	document.update_style()
	hidden_layout_clear_tree_flags(document.as_node())

	// Metadata inserted into <head>, and children inserted into the hidden
	// container: neither parent renders a box.
	link := hidden_layout_child(mut document, mut head, 'link', '')
	script := hidden_layout_child(mut document, mut head, 'script', '')
	hidden_child := hidden_layout_child(mut document, mut hidden, 'span', '')
	document.update_style()
	_ = link
	_ = script
	_ = hidden_child
	assert !hidden_layout_tree_dirty(document)

	// A visible element marks its parent.
	visible := hidden_layout_child(mut document, mut body, 'div', '')
	document.update_style()
	assert body.as_node().needs_layout_tree_update_()
	assert hidden_layout_tree_dirty(document)
	_ = visible
	hidden_layout_clear_tree_flags(document.as_node())

	// Revealing the hidden container needs its box.
	hidden.remove_attribute('class')
	document.update_style()
	assert hidden_layout_tree_dirty(document)
}
