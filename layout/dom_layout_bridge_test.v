module layout

import dom

// After layout, attach_layout_nodes wires the real layout tree back onto the DOM: node.layout_node()
// returns real data (its DOM node, parent layout node, and computed display) instead of the old stubs.
fn test_dom_layout_bridge() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
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
	// html's layout parent is the Viewport (the layout root), whose DOM node is the Document.
	html_layout_parent := html_layout.parent() or {
		panic('html layout node should have the viewport as parent')
	}
	viewport_dom := html_layout_parent.dom_node() or {
		panic('viewport layout node has no dom node')
	}
	assert viewport_dom.is_document()

	// The div's layout node parent is the html layout node.
	div_layout := div.as_node().layout_node() or { panic('div has no layout node') }
	div_layout_parent := div_layout.parent() or { panic('div layout node has no parent') }
	assert voidptr(div_layout_parent) == voidptr(html_layout)
	div_layout_dom := div_layout.dom_node() or { panic('div layout node has no dom node') }
	assert voidptr(div_layout_dom) == voidptr(div.as_node())

	// Element/AbstractElement's styled-layout view is backed by the same attached tree rather than
	// the former always-null placeholder.
	html_with_style := html_el.el_layout_node() or { panic('html has no styled layout view') }
	div_with_style := div.el_layout_node() or { panic('div has no styled layout view') }
	assert voidptr(html_with_style.dom_node() or { panic('missing html DOM node') }) == voidptr(html_el.as_node())
	assert html_with_style.is_before(div_with_style)
	assert !div.not_rendered()
}

fn test_document_update_layout_runs_registered_layout_engine() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut child := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	child.set_attribute_value('style',
		'width: 100px; height: 40px; padding: 10px; border: 2px solid')
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(child.as_node()) or { panic('${err}') }

	install_document_layout_hook(doc)
	doc.needs_full_layout_tree_update = true
	doc.update_layout(.debugging)
	assert doc.layout_engine_handle() != unsafe { nil }
	assert html_el.el_layout_node() != none
	assert child.el_layout_node() != none
	assert doc.layout_is_up_to_date()
	assert child.client_left() == 2
	assert child.client_top() == 2
	assert child.client_width() == 120
	assert child.client_height() == 60
	rect := child.get_bounding_client_rect()
	assert rect.width == 124
	assert rect.height == 64
}
