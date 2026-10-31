module css

import dom

fn has_settle_element(document &dom.Document, parent &dom.Node, tag string) &dom.Element {
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', tag) or { panic(err) }
	mut node := unsafe { &dom.Node(parent) }
	node.append_child(element.as_node()) or { panic(err) }
	return element
}

fn test_nested_has_fanout_finishes_without_scheduling_another_mutation() {
	for selector in [':where(.scope:has(.on) .target)', ':is(.scope:has(.on) .target)', '.scope:has(.on) .target'] {
		mut document := dom.Document.create(dom.url_about_blank())
		defer { document.finalize() }
		document.set_browsing_context(&dom.BrowsingContext{})
		root := has_settle_element(document, document.as_node(), 'html')
		mut scope := has_settle_element(document, root.as_node(), 'section')
		scope.set_attribute_value('class', 'scope')
		mut trigger := has_settle_element(document, scope.as_node(), 'i')
		mut target := has_settle_element(document, scope.as_node(), 'span')
		target.set_attribute_value('class', 'target')
		add_document_author_style_sheet(document, '.target {color:blue} ${selector} {color:red!important}')
		css_style_computer_for(document)
		document.update_style()
		assert computed_value_for(target, .color) or { '' } == 'rgb(0, 0, 255)'
		for on in [true, false, true] {
			trigger.set_attribute_value('class', if on { 'on' } else { '' })
			assert document.needs_invalidation_of_elements_affected_by_has
			document.update_style()
			expected := if on { 'rgb(255, 0, 0)' } else { 'rgb(0, 0, 255)' }
			actual := computed_value_for(target, .color) or { '' }
			assert actual == expected
			assert !document.needs_invalidation_of_elements_affected_by_has
			assert css_style_scope_for_document(document).pending_nodes_for_style_invalidation_due_to_presence_of_has.len == 0
			before := document.style_invalidation_counters()
			document.update_style()
			assert document.style_invalidation_counters().has_ancestor_walk_invocations == before.has_ancestor_walk_invocations
		}
	}
}

fn test_shadow_has_sibling_fallback_settles_and_keeps_later_mutations_live() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	root := has_settle_element(document, document.as_node(), 'html')
	mut host := has_settle_element(document, root.as_node(), 'div')
	shadow := host.attach_shadow(dom.ShadowRootInit{mode: .open}) or { panic(err) }
	mut anchor := has_settle_element(document, shadow.as_node(), 'section')
	anchor.set_attribute_value('class', 'scope')
	mut target := has_settle_element(document, anchor.as_node(), 'span')
	target.set_attribute_value('class', 'target')
	mut trigger := has_settle_element(document, shadow.as_node(), 'aside')
	add_shadow_root_author_style_sheet(shadow,
		'.target {color:blue} :is(.scope:has(+ .on) .target) {color:red}')
	css_style_computer_for(document)
	document.update_style()
	assert computed_value_for(target, .color) or { '' } == 'rgb(0, 0, 255)'
	for on in [true, false, true] {
		trigger.set_attribute_value('class', if on { 'on' } else { '' })
		document.update_style()
		expected := if on { 'rgb(255, 0, 0)' } else { 'rgb(0, 0, 255)' }
		actual := computed_value_for(target, .color) or { '' }
		assert actual == expected
		assert !document.needs_invalidation_of_elements_affected_by_has
		assert css_style_scope_for_shadow_root(shadow).pending_nodes_for_style_invalidation_due_to_presence_of_has.len == 0
	}
}
