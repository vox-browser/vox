module css

import dom

fn compare_independent_dom_entrypoint(mut document dom.Document, root &dom.ParentNode, text string) {
	install_document_selector_query_hook(document)
	hook := document.selector_query_hook() or { panic("missing selector hook") }
	document.set_selector_query_hook(dom.DocumentSelectorQueryHook{...hook, scope_query:unsafe { nil }})
	expected := root.query_selector_all(text) or { panic(err) }
	expected_first := root.query_selector(text)
	document.set_selector_query_hook(hook)
	actual := root.query_selector_all(text) or { panic(err) }
	assert actual.nodes.len == expected.nodes.len, text
	for index, node in actual.nodes { assert voidptr(node) == voidptr(expected.nodes[index]), text }
	actual_first := root.query_selector(text)
	if first := expected_first {
		assert voidptr(actual_first or { panic("missing first match") }) == voidptr(first), text
	} else { assert actual_first == none, text }
}

fn test_independent_dom_entrypoint_preserves_scope_order_namespaces_and_live_mutations() {
	for is_html in [false, true] {
		for quirks in [false, true] {
			mut document := dom.Document.create(dom.url_about_blank())
			defer { document.finalize() }
			document.set_document_type(if is_html { dom.DocumentType_.html } else { dom.DocumentType_.xml })
			if quirks { document.set_quirks_mode(.yes) }
			mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'section')!
			mut root_node := root.as_node()
			mut document_node := document.as_node()
			_ = document_node.append_child(root_node)!
			root.set_attribute_value('class', 'target')
			for namespace in ['http://www.w3.org/1999/xhtml', 'http://www.w3.org/2000/svg', ''] {
				mut child := document.create_element_ns(namespace, 'linearGradient')!
				child.set_attribute_value('id', 'DUPLICATE')
				child.set_attribute_value('class', 'target ITEM')
				child.set_attribute_value('data-label', 'Value two')
				_ = root_node.append_child(child.as_node())!
			}
			for selector in ['*', '*|*', '|*', 'linearGradient', 'lineargradient', '#DUPLICATE', '#duplicate', '.target', '.item', '[data-label~=two]', '[data-label="value two" i]', '.target, [id], *', 'section > *', ':scope > *', ':not(.missing)'] {
				compare_independent_dom_entrypoint(mut document, unsafe { &dom.ParentNode(root) }, selector)
			}
			install_document_selector_query_hook(document)
			hook := document.selector_query_hook()?
			assert (hook.scope_query(hook.target, '.target', unsafe { &dom.ParentNode(root) }, false)?).len == 3
			assert hook.scope_query(hook.target, ':scope > *', unsafe { &dom.ParentNode(root) }, false) == none
			saved := unsafe { &dom.ParentNode(root) }.query_selector_all('.target')!
			mut first := root_node.first_child()?.as_element()?
			first.set_attribute_value('class', 'changed')
			compare_independent_dom_entrypoint(mut document, unsafe { &dom.ParentNode(root) }, '.target, .changed')
			assert saved.nodes.len == 3
			mut first_node := first.as_node()
			first_node.remove(false)
			compare_independent_dom_entrypoint(mut document, unsafe { &dom.ParentNode(root) }, '*')
			assert saved.nodes.len == 3
			shadow := root.attach_shadow(dom.ShadowRootInit{mode:.open})!
			mut shadow_node := unsafe { &dom.Node(shadow) }
			child := document.create_element('aside')!
			_ = shadow_node.append_child(child.as_node())!
			compare_independent_dom_entrypoint(mut document, unsafe { &dom.ParentNode(root) }, '*')
			compare_independent_dom_entrypoint(mut document, unsafe { &dom.ParentNode(shadow) }, '*')
			_ = unsafe { &dom.ParentNode(root) }.query_selector_all('named|tag') or {
				assert err.msg().contains('SyntaxError')
				continue
			}
			assert false
		}
	}
}
