module html

import dom

fn test_form_owner_stops_at_first_matching_html_element_in_tree_order() {
	mut document := dom.Document.create_for_fragment_parsing()
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html')!
	mut blocker := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut form := document.create_element_ns('http://www.w3.org/1999/xhtml', 'form')!
	mut input := document.create_element_ns('http://www.w3.org/1999/xhtml', 'input')!
	blocker.set_attribute_value('id', 'owner')
	form.set_attribute_value('id', 'owner')
	input.set_attribute_value('form', 'owner')
	root.append_child(blocker)
	root.append_child(form)
	root.append_child(input)
	document.append_child(root)
	mut control := FormAssociatedElement.create(input)
	control.reset_form_owner()
	assert control.form() == none
	blocker.set_attribute_value('id', 'different')
	assert voidptr(control.form() or { panic('form owner') }) == voidptr(form)
	blocker.set_attribute_value('id', 'owner')
	assert control.form() == none
	root.as_node().remove_child(blocker.as_node())!
	assert voidptr(control.form() or { panic('form owner after removal') }) == voidptr(form)
}

fn test_form_owner_ignores_svg_ids_and_empty_ids() {
	mut document := dom.Document.create_for_fragment_parsing()
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html')!
	mut svg := document.create_element_ns('http://www.w3.org/2000/svg', 'svg')!
	mut form := document.create_element_ns('http://www.w3.org/1999/xhtml', 'form')!
	mut input := document.create_element_ns('http://www.w3.org/1999/xhtml', 'input')!
	svg.set_attribute_value('id', 'owner')
	form.set_attribute_value('id', 'owner')
	input.set_attribute_value('form', 'owner')
	root.append_child(svg)
	root.append_child(form)
	root.append_child(input)
	document.append_child(root)
	mut control := FormAssociatedElement.create(input)
	control.reset_form_owner()
	assert voidptr(control.form() or { panic('HTML form owner') }) == voidptr(form)
	form.set_attribute_value('id', '')
	input.set_attribute_value('form', '')
	control.reset_form_owner()
	// Both ports keep an empty ID attribute out of Element::id().
	assert control.form() == none
	assert form_element_find_form_by_id(document.as_node(), '') == none
}
