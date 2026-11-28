module css

import dom

fn property_rule_scan_element(document &dom.Document, name string, class string) &dom.Element {
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', name) or {
		panic('${err}')
	}
	if class != '' { element.set_attribute_value('class', class) }
	return element
}

// A sheet without @property rules is not walked for registrations in every
// style pass, and a sheet with some keeps them until its rules change;
// inserting rules afterwards still registers them.
fn test_inserted_property_rules_register_after_a_sheet_had_none() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{})
	mut root := property_rule_scan_element(document, 'html', '')
	mut parent := property_rule_scan_element(document, 'div', 'parent')
	mut child := property_rule_scan_element(document, 'span', 'child')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node()) or { panic('${err}') }
	mut root_node := root.as_node()
	root_node.append_child(parent.as_node()) or { panic('${err}') }
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node()) or { panic('${err}') }
	add_document_author_style_sheet(document, '.parent { --accent: red; } .child { color: var(--accent); }')
	css_style_computer_for(document)
	document.needs_full_style_update = true
	document.update_style()
	assert computed_value_for(child, .color) or { '' } == 'rgb(255, 0, 0)'
	sheets := css_style_scope_for_document(document).stylesheets_for_cascade_origin(.author)
	mut sheet := unsafe { &CSSStyleSheet(sheets[sheets.len - 1]) }
	assert !sheet.may_have_property_rules()
	sheet.insert_rule('@property --accent { syntax: "<color>"; inherits: false; initial-value: green; }',
		0) or { panic('${err}') }
	assert sheet.may_have_property_rules()
	document.needs_full_style_update = true
	document.update_style()
	assert computed_value_for(child, .color) or { '' } == 'rgb(0, 128, 0)'
	// A sheet with registrations collects them again when its rules change.
	sheet.insert_rule('@property --accent { syntax: "<color>"; inherits: false; initial-value: blue; }',
		1) or { panic('${err}') }
	document.needs_full_style_update = true
	document.update_style()
	assert computed_value_for(child, .color) or { '' } == 'rgb(0, 0, 255)'
}
