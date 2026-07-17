module layout

import dom

// build_layout_tree walks the DOM and produces a real layout tree rooted at the Viewport (whose DOM node is
// the Document); the root element's box is the viewport's child. display:none elements (and their subtrees)
// get no box.
fn test_build_layout_tree() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic('${err}') }
	mut body := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'body') or { panic('${err}') }
	mut div := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	mut hidden := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'p') or { panic('${err}') }
	hidden.set_attribute_value('style', 'display: none')

	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('append html: ${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(body.as_node()) or { panic('append body: ${err}') }
	mut body_node := body.as_node()
	body_node.append_child(div.as_node()) or { panic('append div: ${err}') }
	body_node.append_child(hidden.as_node()) or { panic('append p: ${err}') }

	root := build_layout_tree(doc) or { panic('no layout tree') }
	// The root is the Viewport; its DOM node is the Document, and <html> is its single box child.
	assert root.is_viewport()
	assert root.child_count() == 1
	html_box := root.first_child() or { panic('no html box') }
	assert html_box.is_block_container()
	root_el := (html_box.dom_node() or { panic('html box has no dom node') }).as_element() or {
		panic('html box dom node not element')
	}
	assert root_el.local_name() == 'html'

	// html has one layout child: body.
	assert html_box.child_count() == 1
	body_box := html_box.first_child() or { panic('no body box') }

	// body's children: div is boxed, the display:none <p> is not.
	assert body_box.child_count() == 1
	div_box := body_box.first_child() or { panic('no div box') }
	div_el := (div_box.dom_node() or { panic('div box has no dom node') }).as_element() or {
		panic('div box dom node not element')
	}
	assert div_el.local_name() == 'div'
	assert div_box.is_block_container()
}

// run_document_layout packages tree-building + block layout into one document entry point.
fn test_run_document_layout() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic('${err}') }
	mut div1 := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	div1.set_attribute_value('style', 'height: 30px')
	mut div2 := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	div2.set_attribute_value('style', 'height: 40px')
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(div1.as_node()) or { panic('${err}') }
	html_node.append_child(div2.as_node()) or { panic('${err}') }

	result := run_document_layout(doc, 800.0, 600.0) or { panic('layout produced no result') }

	// The viewport's content box is pinned to the viewport rectangle.
	viewport_nws := result.root.as_node_with_style() or { panic('viewport not nws') }
	viewport_uv := result.used_values_for(viewport_nws) or { panic('no viewport used values') }
	assert viewport_uv.content_width().to_double() == 800.0
	assert viewport_uv.content_height().to_double() == 600.0

	// <html> fills the viewport width; its auto height = 30 + 40 = 70.
	html_box := result.root.first_child() or { panic('no html box') }
	html_nws := html_box.as_node_with_style() or { panic('html not nws') }
	html_uv := result.used_values_for(html_nws) or { panic('no html used values') }
	assert html_uv.content_width().to_double() == 800.0
	assert html_uv.content_height().to_double() == 70.0

	div2_nws := html_box.children()[1].as_node_with_style() or { panic('div2 not nws') }
	div2_uv := result.used_values_for(div2_nws) or { panic('no div2 used values') }
	assert div2_uv.content_height().to_double() == 40.0
	assert div2_uv.offset.y().to_double() == 30.0
}

// A DOM text node becomes a Layout::TextNode box carrying its whitespace-collapsed text.
fn test_text_node_layout() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic('${err}') }
	mut para := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'p') or { panic('${err}') }
	text := doc.create_text_node('  Hello    world  ')

	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(para.as_node()) or { panic('${err}') }
	mut para_node := para.as_node()
	para_node.append_child(text.as_node()) or { panic('${err}') }

	root := build_layout_tree(doc) or { panic('no layout tree') }
	html_box := root.first_child() or { panic('no html box') }
	para_box := html_box.first_child() or { panic('no p box') }
	assert para_box.is_block_container()

	text_box := para_box.first_child() or { panic('no text box') }
	assert text_box.is_text_node()
	assert !text_box.is_box()
	text_node := text_box.as_text_node() or { panic('text box is not a TextNode') }
	// Runs of whitespace collapse to single spaces.
	assert text_node.text_for_rendering() == ' Hello world '
	text_dom := text_box.dom_node() or { panic('text box has no dom node') }
	assert text_dom.is_text()

	// The bridge marks it as a text node on the DOM side too.
	result := run_document_layout(doc, 800.0, 600.0) or { panic('no layout result') }
	attach_layout_nodes(result.root)
	text_layout := text.as_node().layout_node() or { panic('text has no layout node') }
	assert text_layout.is_text_node()
}

// A block whose content is inline (text) gets a single line box's height (line-height ~= 1.2 * font-size).
fn test_inline_content_height() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic('${err}') }
	mut para := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'p') or { panic('${err}') }
	text := doc.create_text_node('Hello world')
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(para.as_node()) or { panic('${err}') }
	mut para_node := para.as_node()
	para_node.append_child(text.as_node()) or { panic('${err}') }

	result := run_document_layout(doc, 800.0, 600.0) or { panic('no layout result') }
	html_box := result.root.first_child() or { panic('no html box') }
	para_box := html_box.first_child() or { panic('no p box') }
	para_nws := para_box.as_node_with_style() or { panic('p not nws') }
	para_uv := result.used_values_for(para_nws) or { panic('no p used values') }
	// Default font-size is 16px -> line-height 16 * 1.2 = 19.2 (a non-zero height from text content).
	// CSSPixels is fixed-point, so allow for its rounding.
	height := para_uv.content_height().to_double()
	assert height > 19.15 && height < 19.25
}

// Mixed inline + block content in one container: a text node beside a block element. The text is wrapped in
// an anonymous block box (CSS 2.1 §9.2.1.1) so the container's children are all block-level, and the block
// sibling is not dropped.
fn test_anonymous_block_wrapping_for_mixed_content() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic('${err}') }
	mut div := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	text := doc.create_text_node('hello')
	mut para := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'p') or { panic('${err}') }

	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(div.as_node()) or { panic('${err}') }
	mut div_node := div.as_node()
	div_node.append_child(text.as_node()) or { panic('${err}') }
	div_node.append_child(para.as_node()) or { panic('${err}') }

	// Build + lay out once, then navigate that single tree (build_layout_tree runs again internally, so a
	// tree built separately would hold different node pointers than the laid-out one).
	result := run_document_layout(doc, 800.0, 600.0) or { panic('no layout result') }
	html_box := result.root.first_child() or { panic('no html box') }
	div_box := html_box.first_child() or { panic('no div box') }

	// The div has mixed content, so it is block-level with two block children: an anonymous wrapper (holding
	// the text) followed by the <p> box.
	assert !div_box.children_are_inline()
	assert div_box.child_count() == 2

	wrapper := div_box.first_child() or { panic('no wrapper') }
	assert wrapper.is_anonymous()
	assert wrapper.children_are_inline()
	assert wrapper.child_count() == 1
	wrapper_child := wrapper.first_child() or { panic('no wrapper child') }
	assert wrapper_child.is_text_node()

	para_box := div_box.children()[1]
	assert !para_box.is_anonymous()
	para_el := (para_box.dom_node() or { panic('p box has no dom node') }).as_element() or {
		panic('p box dom node not element')
	}
	assert para_el.local_name() == 'p'

	// The block sibling is laid out (not dropped): it sits below the anonymous text line box (~19.2px).
	para_uv := result.used_values_for(para_box.as_node_with_style() or { panic('p not nws') }) or {
		panic('no p used values')
	}
	assert para_uv.offset.y().to_double() > 19.0
}

// The initial containing block is the viewport, so a root-level percentage height resolves against the
// viewport height (CSS 2.1 §10.5): `html { height: 50% }` in a 600px-tall viewport is 300px.
fn test_root_percentage_height_resolves_against_viewport() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic('${err}') }
	html_el.set_attribute_value('style', 'height: 50%')
	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('${err}') }

	result := run_document_layout(doc, 800.0, 600.0) or { panic('no layout result') }
	html_box := result.root.first_child() or { panic('no html box') }
	html_nws := html_box.as_node_with_style() or { panic('html not nws') }
	html_uv := result.used_values_for(html_nws) or { panic('no html used values') }
	// 50% of the 600px viewport height.
	assert html_uv.content_height().to_double() == 300.0
}
