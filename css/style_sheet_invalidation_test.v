module css

import dom

const style_sheet_invalidation_html_namespace = 'http://www.w3.org/1999/xhtml'

fn style_sheet_invalidation_test_element(document &dom.Document, local_name string) &dom.Element {
	return document.create_element_ns(style_sheet_invalidation_html_namespace, local_name) or {
		panic(err)
	}
}

fn clear_style_sheet_invalidation_test_flags(nodes ...&dom.Node) {
	for node in nodes {
		mut mutable_node := unsafe { &dom.Node(node) }
		mutable_node.set_needs_style_update_internal(false)
		mutable_node.set_child_needs_style_update(false)
		mutable_node.set_entire_subtree_needs_style_update(false)
	}
}

fn install_inline_style_sheet_for_invalidation_test(mut sheet CSSStyleSheet, owner &dom.Element, root &dom.Node) {
	sheet.set_owner_node(owner)
	sheet.add_owning_document_or_shadow_root(root)
	if shadow_root := root.as_shadow_root() {
		mut scope := css_style_scope_for_shadow_root(shadow_root)
		scope.author_style_sheets << sheet
	} else {
		holder := css_author_style_sheets_for(root.document())
		unsafe {
			holder.sheets << sheet
		}
	}
}

fn test_insert_rule_targets_matching_elements_in_inline_style_sheet() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_invalidation_test_element(document, 'html')
	mut style := style_sheet_invalidation_test_element(document, 'style')
	mut target := style_sheet_invalidation_test_element(document, 'div')
	target.set_attribute_value('class', 'target')
	mut bystander := style_sheet_invalidation_test_element(document, 'div')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(style.as_node()) or { panic(err) }
	root_node.append_child(target.as_node()) or { panic(err) }
	root_node.append_child(bystander.as_node()) or { panic(err) }

	mut sheet := parse_css_stylesheet_with_parser('', none)
	install_inline_style_sheet_for_invalidation_test(mut sheet, style, document_node)
	clear_style_sheet_invalidation_test_flags(document_node, root.as_node(), style.as_node(), target.as_node(), bystander.as_node())
	document.set_needs_full_style_update(false)
	document.reset_style_invalidation_counters()

	assert sheet.insert_rule('.target { color: red }', 0)! == 0
	assert target.needs_style_update()
	assert !bystander.needs_style_update()
	assert !document.needs_full_style_update()
	counters := document.style_invalidation_counters()
	assert counters.full_style_invalidations == 0
	assert counters.style_invalidations == 1
}

fn test_insert_rule_uses_leading_anchor_for_trailing_universal_and_pseudo_element() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_invalidation_test_element(document, 'html')
	mut style := style_sheet_invalidation_test_element(document, 'style')
	mut anchor := style_sheet_invalidation_test_element(document, 'section')
	anchor.set_attribute_value('id', 'scope')
	anchor.set_attribute_value('class', 'anchor')
	mut child := style_sheet_invalidation_test_element(document, 'span')
	mut outside := style_sheet_invalidation_test_element(document, 'span')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(style.as_node()) or { panic(err) }
	root_node.append_child(anchor.as_node()) or { panic(err) }
	root_node.append_child(outside.as_node()) or { panic(err) }
	mut anchor_node := anchor.as_node()
	anchor_node.append_child(child.as_node()) or { panic(err) }

	mut sheet := parse_css_stylesheet_with_parser('', none)
	install_inline_style_sheet_for_invalidation_test(mut sheet, style, document_node)
	clear_style_sheet_invalidation_test_flags(document_node, root.as_node(), style.as_node(), anchor.as_node(), child.as_node(), outside.as_node())
	document.set_needs_full_style_update(false)

	assert sheet.insert_rule('#scope > * { color: red }', 0)! == 0
	assert child.needs_style_update()
	assert !outside.needs_style_update()
	assert !document.needs_full_style_update()

	clear_style_sheet_invalidation_test_flags(document_node, root.as_node(), style.as_node(), anchor.as_node(), child.as_node(), outside.as_node())
	assert sheet.insert_rule('.anchor::before { content: "x" }', 1)! == 1
	assert anchor.needs_style_update()
	assert !child.needs_style_update()
	assert !outside.needs_style_update()
	assert !document.needs_full_style_update()
}

fn test_insert_rule_targets_matching_elements_inside_shadow_root() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_invalidation_test_element(document, 'html')
	mut host := style_sheet_invalidation_test_element(document, 'div')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(host.as_node()) or { panic(err) }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	mut style := style_sheet_invalidation_test_element(document, 'style')
	mut target := style_sheet_invalidation_test_element(document, 'span')
	target.set_attribute_value('class', 'target')
	mut bystander := style_sheet_invalidation_test_element(document, 'span')
	shadow_node.append_child(style.as_node()) or { panic(err) }
	shadow_node.append_child(target.as_node()) or { panic(err) }
	shadow_node.append_child(bystander.as_node()) or { panic(err) }

	mut sheet := parse_css_stylesheet_with_parser('', none)
	install_inline_style_sheet_for_invalidation_test(mut sheet, style, shadow_node)
	clear_style_sheet_invalidation_test_flags(document_node, root.as_node(), host.as_node(), shadow_node, style.as_node(), target.as_node(), bystander.as_node())
	document.set_needs_full_style_update(false)
	document.reset_style_invalidation_counters()

	assert sheet.insert_rule('.target { color: green }', 0)! == 0
	assert target.needs_style_update()
	assert !bystander.needs_style_update()
	assert !document.needs_full_style_update()
	counters := document.style_invalidation_counters()
	assert counters.full_style_invalidations == 0
	assert counters.style_invalidations == 1
}

fn test_shadow_host_escape_selector_classification() {
	assert selector_text_may_match_light_dom_under_shadow_host('::slotted(.item)')
	assert selector_text_may_match_light_dom_under_shadow_host(':host > .item')
	assert !selector_text_may_match_light_dom_under_shadow_host(':host')
	assert !selector_text_may_match_light_dom_under_shadow_host('.item')
	assert !selector_text_may_match_light_dom_under_shadow_host('not[')
}
