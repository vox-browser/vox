module layout

import dom

// After layout, attach_layout_nodes wires the real layout tree back onto the DOM: node.layout_node()
// returns real data (its DOM node, parent layout node, and computed display) instead of the old stubs.
fn test_dom_layout_bridge() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic('${err}') }
	mut div := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(div.as_node()) or { panic('${err}') }

	result := run_document_layout(doc, 800.0, 600.0) or { panic('no layout result') }
	attach_layout_nodes(result.root)

	// <html> now has a layout node pointing back at its DOM node, with a real (non-none, non-anonymous) display.
	html_layout := html_el.as_node().layout_node() or { panic('html has no layout node') }
	html_layout_dom := html_layout.dom_node() or { panic('html layout node has no dom node') }
	assert voidptr(html_layout_dom) == voidptr(html_el.as_node())
	assert !html_layout.is_anonymous()
	assert !html_layout.is_text_node()
	assert !html_layout.display().is_none()
	// html has no layout parent (it's the root box).
	if _ := html_layout.parent() {
		panic('root layout node should have no parent')
	}

	// The div's layout node parent is the html layout node.
	div_layout := div.as_node().layout_node() or { panic('div has no layout node') }
	div_layout_parent := div_layout.parent() or { panic('div layout node has no parent') }
	assert voidptr(div_layout_parent) == voidptr(html_layout)
	div_layout_dom := div_layout.dom_node() or { panic('div layout node has no dom node') }
	assert voidptr(div_layout_dom) == voidptr(div.as_node())
}
