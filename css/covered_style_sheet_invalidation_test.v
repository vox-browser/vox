module css

import dom

fn covered_sheet_test_fixture() (&dom.Document, &CSSStyleSheet, &dom.Element, &dom.Element) {
	mut document := dom.Document.create(dom.url_about_blank())
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic(err) }
	mut style := document.create_element_ns('http://www.w3.org/1999/xhtml', 'style') or { panic(err) }
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	target.set_attribute_value('class', 'target')
	mut child := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or { panic(err) }
	mut document_node := document.as_node()
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(style.as_node()) or { panic(err) }
	root_node.append_child(target.as_node()) or { panic(err) }
	mut target_node := target.as_node()
	target_node.append_child(child.as_node()) or { panic(err) }
	mut sheet := parse_css_stylesheet_with_parser('', none)
	sheet.set_owner_node(style)
	sheet.add_owning_document_or_shadow_root(document_node)
	holder := css_author_style_sheets_for(document)
	unsafe { holder.sheets << sheet }
	_ = css_style_computer_for(document)
	_ = update_style_for_document_from_upstream(document)
	document.set_needs_full_style_update(false)
	covered_sheet_test_clear(document_node)
	return document, sheet, target, child
}

fn covered_sheet_test_clear(node &dom.Node) {
	mut mutable_node := unsafe { &dom.Node(node) }
	mutable_node.set_needs_style_update_internal(false)
	mutable_node.set_child_needs_style_update(false)
	mutable_node.set_entire_subtree_needs_style_update(false)
	for child in node.children { covered_sheet_test_clear(child) }
}

fn covered_sheet_test_flush(document &dom.Document) {
	mut document_node := unsafe { &dom.Node(document) }
	if document.needs_full_style_update() { document_node.set_entire_subtree_needs_style_update(true) }
	_ = update_style_for_document_from_upstream(document)
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_needs_full_style_update(false)
}

fn covered_sheet_test_color(element &dom.Element) Color {
	bridge := dom.AbstractElement.new(element, none).computed_properties() or { panic('computed style') }
	style := computed_properties_from_dom(bridge) or { panic('CSS style') }
	return resolve_computed_values_for_document(style, element.as_node().document()).color()
}

fn test_pending_full_cascade_covers_primary_sheet_insert_and_resolves_new_rule() {
	mut document, mut sheet, target, child := covered_sheet_test_fixture()
	defer { document.finalize() }
	document.set_needs_full_style_update(true)
	assert sheet.insert_rule('.target { color:red }', 0)! == 0
	assert sheet.insert_rule('.target::before { content:"x";color:blue }', 1)! == 1
	assert target.needs_style_update() == retain_covered_style_sheet_walk
	assert document.element_needs_style_update(target)
	assert document.element_needs_style_update(child)
	covered_sheet_test_flush(document)
	assert covered_sheet_test_color(target) == Color{255, 0, 0, 255}
	assert covered_sheet_test_color(child) == Color{255, 0, 0, 255}
	before_bridge := dom.AbstractElement.new(target, dom.PseudoElement.before).computed_properties() or { panic('before style') }
	before_style := computed_properties_from_dom(before_bridge) or { panic('before CSS style') }
	before_values := resolve_computed_values_for_document(before_style, document)
	assert before_values.color() == Color{0, 0, 255, 255}
}

fn test_partial_cascade_still_marks_matching_stylesheet_targets() {
	mut document, mut sheet, target, child := covered_sheet_test_fixture()
	defer { document.finalize() }
	assert !document.needs_full_style_update()
	assert sheet.insert_rule('.target { color:red }', 0)! == 0
	assert target.needs_style_update()
	assert !child.needs_style_update()
	covered_sheet_test_flush(document)
	assert covered_sheet_test_color(target) == Color{255, 0, 0, 255}
	assert covered_sheet_test_color(child) == Color{255, 0, 0, 255}
}

fn test_pending_full_cascade_keeps_anchor_and_trailing_universal_walks() {
	for selector in ['.target ::before', '.target > *'] {
		mut document, mut sheet, target, child := covered_sheet_test_fixture()
		defer { document.finalize() }
		document.set_needs_full_style_update(true)
		assert sheet.insert_rule('${selector} { color:red;content:"x" }', 0)! == 0
		if selector.ends_with('*') {
			assert child.needs_style_update()
			covered_sheet_test_flush(document)
			assert covered_sheet_test_color(child) == Color{255, 0, 0, 255}
		} else {
			assert target.needs_style_update()
		}
	}
}

fn test_active_style_batch_and_non_document_roots_keep_primary_walks() {
	mut document, mut sheet, target, _ := covered_sheet_test_fixture()
	defer { document.finalize() }
	document.set_needs_full_style_update(true)
	computer := css_style_computer_for(document)
	computer.begin_computed_property_page_batch()
	assert sheet.insert_rule('.target { color:red }', 0)! == 0
	assert target.needs_style_update()
	computer.end_computed_property_page_batch()
	assert !style_sheet_primary_invalidation_is_covered(target.as_node(), &StyleSheetInvalidationSet{})
	covered_sheet_test_flush(document)
	assert covered_sheet_test_color(target) == Color{255, 0, 0, 255}
}
