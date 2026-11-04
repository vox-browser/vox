module css

import dom

fn first_style_element(document &dom.Document, parent &dom.Node, tag string) &dom.Element {
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', tag) or { panic(err) }
	mut node := unsafe { &dom.Node(parent) }
	node.append_child(element.as_node()) or { panic(err) }
	return element
}

fn first_style_color(element &dom.Element) string {
	placeholder := dom.AbstractElement.new(element, none).computed_properties() or {
		panic('missing computed properties')
	}
	computed := computed_properties_from_dom(placeholder) or { panic('missing typed properties') }
	return (computed.property(.color, .yes) or { panic('missing color') }).css_text
}

fn test_sheets_added_before_the_first_style_update_skip_invalidation_and_still_style_everything() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	root := first_style_element(document, document.as_node(), 'html')
	owner := first_style_element(document, root.as_node(), 'style')
	later_owner := first_style_element(document, root.as_node(), 'style')
	mut target := first_style_element(document, root.as_node(), 'div')
	target.set_attribute_value('class', 'target')
	bystander := first_style_element(document, root.as_node(), 'div')
	assert document_awaits_first_style_update(document)
	mut scope := css_style_scope_for_document(document)
	mut list := scope.style_sheet_list()
	document.reset_style_invalidation_counters()
	mut sheet := parse_css_stylesheet_with_parser('.target { color: rgb(255, 0, 0) } :root { color: rgb(0, 128, 0) }', none)
	sheet.set_owner_node(owner)
	list.add_sheet(sheet)
	counters := document.style_invalidation_counters()
	assert counters.style_invalidations == 0 && counters.full_style_invalidations == 0
	assert target.needs_style_update() && bystander.needs_style_update()
	css_style_computer_for(document)
	document.update_style()
	assert first_style_color(target) == 'rgb(255, 0, 0)'
	assert first_style_color(bystander) == 'rgb(0, 128, 0)'
	assert !document_awaits_first_style_update(document)

	// After that update, an added sheet invalidates only its targets again.
	mut later := parse_css_stylesheet_with_parser('.target { color: rgb(0, 0, 255) }', none)
	later.set_owner_node(later_owner)
	list.add_sheet(later)
	assert target.needs_style_update()
	assert !bystander.needs_style_update()
	document.update_style()
	assert first_style_color(target) == 'rgb(0, 0, 255)'
	assert first_style_color(bystander) == 'rgb(0, 128, 0)'
}
