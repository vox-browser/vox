module css

import dom

fn test_leaf_queries_read_elements_before_skipping_empty_descendant_walks() {
	for xml in [false, true] {
		for quirks in [false, true] {
			mut document := dom.Document.create(dom.url_about_blank())
			defer { document.finalize() }
			document.set_document_type(if xml { dom.DocumentType_.xml } else { dom.DocumentType_.html })
			if quirks { document.set_quirks_mode(.yes) }
			root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'main')!
			independent_query_append(document.as_node(), root.as_node())
			for i in 0 .. 17 {
				independent_query_append(root.as_node(), document.create_text_node('text ${i}').as_node())
				element := document.create_element_ns(if i % 2 == 0 { 'http://www.w3.org/1999/xhtml' } else { 'http://www.w3.org/2000/svg' }, 'Thing')!
				mut mutable_element := unsafe { &dom.Element(element) }
				mutable_element.set_attribute_value('id', if i % 3 == 0 { 'DUPLICATE' } else { 'item-${i}' })
				mutable_element.set_attribute_value('class', if i % 2 == 0 { 'PICK' } else { 'other' })
				mutable_element.set_attribute_value('data-index', '${i}')
				independent_query_append(root.as_node(), element.as_node())
			}
			for selector in ['Thing', '*|Thing', 'thing', '#DUPLICATE', '#duplicate', '.PICK', '.pick', '[data-index]', '[data-index="8"]', '[data-index="absent"]', '.other, [data-index], #DUPLICATE', '#item-16, #item-0', 'main', '*'] {
				independent_query_compare(document.as_node(), selector)
				independent_query_compare(root.as_node(), selector)
			}
		}
	}
}

fn test_leaf_queries_observe_new_children_removal_and_reparenting_each_call() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	root := document.create_element('main')!
	independent_query_append(document.as_node(), root.as_node())
	leaf := document.create_element('section')!
	independent_query_append(root.as_node(), leaf.as_node())
	for selector in ['section', 'span', '[data-live]'] { independent_query_compare(root.as_node(), selector) }
	mut child := document.create_element('span')!
	child.set_attribute_value('data-live', 'yes')
	independent_query_append(leaf.as_node(), child.as_node())
	for selector in ['section', 'span', '[data-live]'] { independent_query_compare(root.as_node(), selector) }
	mut leaf_node := leaf.as_node()
	leaf_node.remove_child(child.as_node())!
	for selector in ['section', 'span', '[data-live]'] { independent_query_compare(root.as_node(), selector) }
	independent_query_append(root.as_node(), child.as_node())
	child.set_attribute_value('class', 'moved')
	for selector in ['section', 'span', '[data-live]', '.moved'] { independent_query_compare(root.as_node(), selector) }
	assert query_selector_all(root.as_node(), 'span, .moved').len == 1
}

fn test_leaf_queries_preserve_fragment_shadow_and_detached_scope_boundaries() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	host := document.create_element('main')!
	independent_query_append(document.as_node(), host.as_node())
	shadow := host.attach_shadow(dom.ShadowRootInit{mode: .open})!
	shadow_node := unsafe { &dom.Node(shadow) }
	fragment := document.create_document_fragment()
	fragment_node := unsafe { &dom.Node(fragment) }
	detached := document.create_element('section')!
	for root in [host.as_node(), shadow_node, fragment_node, detached.as_node()] {
		independent_query_append(root, document.create_text_node(' ').as_node())
		for name in ['a', 'b', 'a'] {
			mut element := document.create_element(name)!
			element.set_attribute_value('class', 'hit')
			independent_query_append(root, element.as_node())
		}
		for selector in ['a', 'b, a', '.hit', '[missing]', 'main'] { independent_query_compare(root, selector) }
		assert query_selector_all(root, '.hit').len == 3
	}
	assert query_selector_all(document.as_node(), '.hit').len == 3
	independent_query_append(host.as_node(), fragment_node)
	assert query_selector_all(document.as_node(), '.hit').len == 6
	assert query_selector_all(fragment_node, '.hit').len == 0
}

fn test_leaf_queries_keep_first_match_and_group_order_on_mixed_depth_trees() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	root := document.create_element('main')!
	independent_query_append(document.as_node(), root.as_node())
	mut branch := root
	for depth in 0 .. 20 {
		mut first := document.create_element('span')!
		first.set_attribute_value('data-depth', '${depth}')
		independent_query_append(branch.as_node(), first.as_node())
		independent_query_append(branch.as_node(), document.create_text_node('text').as_node())
		nested := document.create_element('div')!
		independent_query_append(branch.as_node(), nested.as_node())
		branch = nested
	}
	for selector in ['span', 'div', 'span, div', '[data-depth="19"], [data-depth="0"]', 'div[data-absent]', '[data-depth]'] { independent_query_compare(root.as_node(), selector) }
	first := query_selector(root.as_node(), '[data-depth="19"], [data-depth="0"]') or { panic('first missing') }
	assert first.get_attribute_value('data-depth') == '0'
	assert query_selector_all(root.as_node(), 'span').len == 20
}
