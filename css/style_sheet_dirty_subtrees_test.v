module css

import dom

fn test_inserted_rule_uses_existing_subtree_invalidation_and_still_updates_style() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	mut document_node := document.as_node()
	mut root := style_sheet_invalidation_test_element(document, 'html')
	style := style_sheet_invalidation_test_element(document, 'style')
	mut branch := style_sheet_invalidation_test_element(document, 'section')
	mut target := style_sheet_invalidation_test_element(document, 'div')
	mut peer := style_sheet_invalidation_test_element(document, 'div')
	target.set_attribute_value('class', 'target')
	peer.set_attribute_value('class', 'target')
	document_node.append_child(root.as_node())!
	mut root_node := root.as_node()
	root_node.append_child(style.as_node())!
	root_node.append_child(branch.as_node())!
	root_node.append_child(peer.as_node())!
	mut branch_node := branch.as_node()
	branch_node.append_child(target.as_node())!
	mut sheet := parse_css_stylesheet_with_parser('.target { color:red }', none)
	install_inline_style_sheet_for_invalidation_test(mut sheet, style, document_node)
	css_style_computer_for(document)
	document.update_style()
	clear_style_sheet_invalidation_test_flags(document_node, root_node, style.as_node(), branch_node, target.as_node(), peer.as_node())
	document.set_needs_full_style_update(false)
	branch_node.set_entire_subtree_needs_style_update(true)
	branch_node.set_needs_style_update(true)
	assert sheet.insert_rule('.target { color:blue }', 1)! == 1
	assert branch.entire_subtree_needs_style_update()
	assert target.needs_style_update() == retain_dirty_stylesheet_traversal
	assert peer.needs_style_update()
	css_style_computer_for(document)
	document.update_style()
	assert computed_value_for(target, .color)? == 'rgb(0, 0, 255)'
	assert computed_value_for(peer, .color)? == 'rgb(0, 0, 255)'
	assert !branch.entire_subtree_needs_style_update()
	assert sheet.insert_rule('.target { color:green }', 2)! == 2
	assert target.needs_style_update()
	css_style_computer_for(document)
	document.update_style()
	assert computed_value_for(target, .color)? == 'rgb(0, 128, 0)'
}

fn test_dirty_subtree_does_not_hide_trailing_sibling_anchor_effects() {
	for combinator in ['+', '~'] {
		mut document := dom.Document.create(dom.url_about_blank())
		defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
		mut document_node := document.as_node()
		mut root := style_sheet_invalidation_test_element(document, 'html')
		style := style_sheet_invalidation_test_element(document, 'style')
		mut anchor := style_sheet_invalidation_test_element(document, 'div')
		target := style_sheet_invalidation_test_element(document, 'div')
		anchor.set_attribute_value('class', 'anchor')
		document_node.append_child(root.as_node())!
		mut root_node := root.as_node()
		root_node.append_child(style.as_node())!
		root_node.append_child(anchor.as_node())!
		root_node.append_child(target.as_node())!
		mut sheet := parse_css_stylesheet_with_parser('', none)
		install_inline_style_sheet_for_invalidation_test(mut sheet, style, document_node)
		clear_style_sheet_invalidation_test_flags(document_node, root_node, style.as_node(), anchor.as_node(), target.as_node())
		document.set_needs_full_style_update(false)
		mut anchor_node := anchor.as_node()
		anchor_node.set_entire_subtree_needs_style_update(true)
		assert sheet.insert_rule('.anchor ${combinator} * { color:blue }', 0)! == 0
		assert target.needs_style_update()
	}
}

fn test_dirty_subtree_pseudo_element_rule_is_applied_by_the_pending_cascade() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	mut document_node := document.as_node()
	mut root := style_sheet_invalidation_test_element(document, 'html')
	style := style_sheet_invalidation_test_element(document, 'style')
	mut target := style_sheet_invalidation_test_element(document, 'div')
	target.set_attribute_value('class', 'target')
	document_node.append_child(root.as_node())!
	mut root_node := root.as_node()
	root_node.append_child(style.as_node())!
	root_node.append_child(target.as_node())!
	mut sheet := parse_css_stylesheet_with_parser('', none)
	install_inline_style_sheet_for_invalidation_test(mut sheet, style, document_node)
	css_style_computer_for(document)
	document.update_style()
	clear_style_sheet_invalidation_test_flags(document_node, root_node, style.as_node(), target.as_node())
	document.set_needs_full_style_update(false)
	mut target_node := target.as_node()
	target_node.set_entire_subtree_needs_style_update(true)
	target_node.set_needs_style_update(true)
	assert sheet.insert_rule('.target::before { content:"fresh";color:blue }', 0)! == 0
	css_style_computer_for(document)
	document.update_style()
	pseudo := dom.AbstractElement.new(target, .before)
	bridge := pseudo.computed_properties() or { panic('missing updated pseudo style') }
	computed := computed_properties_from_dom(bridge) or { panic('missing typed pseudo style') }
	assert computed.property(.color, .no)?.css_text == 'rgb(0, 0, 255)'
}
