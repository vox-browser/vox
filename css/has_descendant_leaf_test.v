module css

import dom

fn has_leaf_element(document &dom.Document, parent &dom.Node, tag string, class_name string) &dom.Element {
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', tag) or { panic(err) }
	element.set_attribute_value('class', class_name)
	mut node := unsafe { &dom.Node(parent) }
	node.append_child(element.as_node()) or { panic(err) }
	return element
}

fn has_leaf_match(element &dom.Element, source string) bool {
	selector_list := parse_selector_with_parser(source, map[string]bool{}) or { panic(source) }
	mut context := MatchContext{
		collect_per_element_selector_involvement_metadata: true
		has_result_cache: unsafe { nil }
	}
	return matches(selector_list.selectors[0], element, none, mut context, none, none, .normal, none)
}

fn test_has_descendant_search_preserves_tree_order_and_early_match_metadata() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	root := has_leaf_element(document, document.as_node(), 'html', '')
	anchor := has_leaf_element(document, root.as_node(), 'section', 'anchor')
	first := has_leaf_element(document, anchor.as_node(), 'i', '')
	branch := has_leaf_element(document, anchor.as_node(), 'div', '')
	mut branch_node := branch.as_node()
	branch_node.append_child(document.create_text_node('text before match').as_node()) or { panic(err) }
	match_node := has_leaf_element(document, branch_node, 'span', 'flag')
	later := has_leaf_element(document, anchor.as_node(), 'span', 'flag')
	outside := has_leaf_element(document, root.as_node(), 'span', 'outside')
	assert has_leaf_match(anchor, '.anchor:has(.flag)')
	assert first.in_has_scope && branch.in_has_scope && match_node.in_has_scope
	assert !later.in_has_scope && !outside.in_has_scope
	assert !has_leaf_match(anchor, '.anchor:has(.outside)')
	assert later.in_has_scope && !outside.in_has_scope
	assert !has_leaf_match(anchor, '.anchor:has(.anchor)')
	assert has_leaf_match(anchor, '.anchor:has(> div > .flag)')
	assert has_leaf_match(anchor, '.anchor:has(i + div .flag)')
}

fn test_has_descendant_search_keeps_empty_and_shadow_boundaries_live() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut anchor := document.create_element_ns('http://www.w3.org/1999/xhtml', 'section') or { panic(err) }
	anchor.set_attribute_value('class', 'anchor')
	assert !has_leaf_match(anchor, '.anchor:has(*)')
	shadow := anchor.attach_shadow(dom.ShadowRootInit{mode: .open}) or { panic(err) }
	_ = has_leaf_element(document, shadow.as_node(), 'span', 'flag')
	assert !has_leaf_match(anchor, '.anchor:has(.flag)')
	mut anchor_node := anchor.as_node()
	anchor_node.append_child(document.create_text_node('text only').as_node()) or { panic(err) }
	assert !has_leaf_match(anchor, '.anchor:has(*)')
	mut branch := has_leaf_element(document, anchor_node, 'div', '')
	assert !has_leaf_match(anchor, '.anchor:has(.flag)')
	mut flag := has_leaf_element(document, branch.as_node(), 'span', 'flag')
	gc_collect()
	assert has_leaf_match(anchor, '.anchor:has(.flag)')
	flag.set_attribute_value('class', '')
	assert !has_leaf_match(anchor, '.anchor:has(.flag)')
	branch.set_attribute_value('class', 'flag')
	assert has_leaf_match(anchor, '.anchor:has(.flag)')
}

fn test_has_leaf_insertion_and_removal_preserve_later_selective_invalidation() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	root := has_leaf_element(document, document.as_node(), 'html', '')
	anchor := has_leaf_element(document, root.as_node(), 'section', 'anchor')
	branch := has_leaf_element(document, anchor.as_node(), 'div', '')
	add_document_author_style_sheet(document,
		'.anchor { color: blue } .anchor:has(.flag) { color: red }')
	css_style_computer_for(document)
	document.update_style()
	assert computed_value_for(anchor, .color) or { '' } == 'rgb(0, 0, 255)'
	mut flag := has_leaf_element(document, branch.as_node(), 'span', 'flag')
	document.update_style()
	assert computed_value_for(anchor, .color) or { '' } == 'rgb(255, 0, 0)'
	flag.set_attribute_value('class', '')
	document.update_style()
	assert computed_value_for(anchor, .color) or { '' } == 'rgb(0, 0, 255)'
	flag.set_attribute_value('class', 'flag')
	document.update_style()
	assert computed_value_for(anchor, .color) or { '' } == 'rgb(255, 0, 0)'
	mut flag_node := flag.as_node()
	flag_node.remove(false)
	document.update_style()
	assert computed_value_for(anchor, .color) or { '' } == 'rgb(0, 0, 255)'
}
