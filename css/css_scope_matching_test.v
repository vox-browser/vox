module css

import dom

fn scope_matching_element(document &dom.Document, local_name string, class_name string) &dom.Element {
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', local_name) or {
		panic(err)
	}
	element.set_attribute_value('class', class_name)
	return element
}

fn scope_matching_color(document &dom.Document, element &dom.Element) string {
	computer := css_style_computer_for(document)
	computed := computer.compute_style(dom.AbstractElement.new(element, none))
	return (computed.property(.color, .no) or { panic('computed color missing') }).css_text
}

fn test_scope_rule_only_applies_below_matching_scope_root() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut html := scope_matching_element(document, 'html', '')
	mut outer := scope_matching_element(document, 'section', 'outer')
	inside := scope_matching_element(document, 'span', 'target')
	outside := scope_matching_element(document, 'span', 'target')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(html.as_node()) or { panic(err) }
	mut html_node := html.as_node()
	html_node.append_child(outer.as_node()) or { panic(err) }
	mut outer_node := outer.as_node()
	outer_node.append_child(inside.as_node()) or { panic(err) }
	html_node.append_child(outside.as_node()) or { panic(err) }
	add_document_author_style_sheet(document, '.target { color: blue } @scope (.outer) { .target { color: red } }')

	assert scope_matching_color(document, inside) == 'rgb(255, 0, 0)'
	assert scope_matching_color(document, outside) == 'rgb(0, 0, 255)'
}

fn test_scope_limit_excludes_limit_subtree() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut html := scope_matching_element(document, 'html', '')
	mut outer := scope_matching_element(document, 'section', 'outer')
	before_limit := scope_matching_element(document, 'span', 'target')
	mut limit := scope_matching_element(document, 'div', 'limit')
	inside_limit := scope_matching_element(document, 'span', 'target')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(html.as_node()) or { panic(err) }
	mut html_node := html.as_node()
	html_node.append_child(outer.as_node()) or { panic(err) }
	mut outer_node := outer.as_node()
	outer_node.append_child(before_limit.as_node()) or { panic(err) }
	outer_node.append_child(limit.as_node()) or { panic(err) }
	mut limit_node := limit.as_node()
	limit_node.append_child(inside_limit.as_node()) or { panic(err) }
	add_document_author_style_sheet(document, '.target { color: blue } @scope (.outer) to (.limit) { .target { color: red } }')

	assert scope_matching_color(document, before_limit) == 'rgb(255, 0, 0)'
	assert scope_matching_color(document, inside_limit) == 'rgb(0, 0, 255)'
}

fn test_scope_relative_child_selector_uses_scope_root() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut html := scope_matching_element(document, 'html', '')
	mut outer := scope_matching_element(document, 'section', 'outer target')
	mut child := scope_matching_element(document, 'div', 'target')
	grandchild := scope_matching_element(document, 'span', 'target')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(html.as_node()) or { panic(err) }
	mut html_node := html.as_node()
	html_node.append_child(outer.as_node()) or { panic(err) }
	mut outer_node := outer.as_node()
	outer_node.append_child(child.as_node()) or { panic(err) }
	mut child_node := child.as_node()
	child_node.append_child(grandchild.as_node()) or { panic(err) }
	add_document_author_style_sheet(document, '.target { color: blue } @scope (.outer) { & > .target { color: red } }')

	assert scope_matching_color(document, outer) == 'rgb(0, 0, 255)'
	assert scope_matching_color(document, child) == 'rgb(255, 0, 0)'
	assert scope_matching_color(document, grandchild) == 'rgb(0, 0, 255)'
}

fn test_scope_direct_declarations_apply_to_root_with_zero_specificity() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut html := scope_matching_element(document, 'html', '')
	mut outer := scope_matching_element(document, 'section', 'outer')
	child := scope_matching_element(document, 'span', '')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(html.as_node()) or { panic(err) }
	mut html_node := html.as_node()
	html_node.append_child(outer.as_node()) or { panic(err) }
	mut outer_node := outer.as_node()
	outer_node.append_child(child.as_node()) or { panic(err) }
	add_document_author_style_sheet(document, '@scope (.outer) { left: 2px; opacity: 0.5 } .outer { opacity: 0.75 }')

	computer := css_style_computer_for(document)
	outer_style := computer.compute_style(dom.AbstractElement.new(outer, none))
	child_style := computer.compute_style(dom.AbstractElement.new(child, none))
	assert outer_style.opacity() == f32(0.75)
	assert child_style.opacity() == f32(1.0)
	assert (outer_style.property(.left, .no) or { panic('root left missing') }).css_text == '2px'
	assert (child_style.property(.left, .no) or { panic('child left missing') }).css_text == 'auto'
}

fn test_scope_proximity_wins_before_source_order() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut html := scope_matching_element(document, 'html', '')
	mut far := scope_matching_element(document, 'section', 'far')
	mut near := scope_matching_element(document, 'div', 'near')
	target := scope_matching_element(document, 'span', 'target')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(html.as_node()) or { panic(err) }
	mut html_node := html.as_node()
	html_node.append_child(far.as_node()) or { panic(err) }
	mut far_node := far.as_node()
	far_node.append_child(near.as_node()) or { panic(err) }
	mut near_node := near.as_node()
	near_node.append_child(target.as_node()) or { panic(err) }
	add_document_author_style_sheet(document, '@scope (.near) { .target { color: red } } @scope (.far) { .target { color: blue } }')

	assert scope_matching_color(document, target) == 'rgb(255, 0, 0)'
}
