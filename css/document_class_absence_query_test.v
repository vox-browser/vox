module css

import dom

fn class_absence_compare(document &dom.Document, selector string) {
	parsed := parse_query_selector_list(selector) or { panic(selector) }
	mut expected := []&dom.Element{}
	query_selector_all_in(document.as_node(), parsed, mut expected)
	actual := query_selector_all(document.as_node(), selector)
	assert actual.len == expected.len, selector
	for index, element in expected { assert voidptr(actual[index]) == voidptr(element), selector }
	if first := query_selector(document.as_node(), selector) {
		assert expected.len > 0 && voidptr(first) == voidptr(expected[0]), selector
	} else { assert expected.len == 0, selector }
}

fn test_document_class_absence_observes_live_attributes_static_lists_adoption_and_fragments() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	mut root := document.create_element('main')!
	mut docnode := document.as_node()
	docnode.append_child(root.as_node())!
	mut rootnode := root.as_node()
	mut target := document.create_element('section')!
	rootnode.append_child(target.as_node())!
	before := query_selector_all(document.as_node(), '.future')
	assert !document.may_have_element_class('future') && before.len == 0
	target.set_attribute_value('class', 'ready future')
	assert document.may_have_element_class('future')
	class_absence_compare(document, '.ready.future')
	assert query_selector_all(document.as_node(), '.future').len == 1 && before.len == 0
	target.remove_attribute('class')
	assert document.may_have_element_class('future')
	assert query_selector_all(document.as_node(), '.future').len == 0
	class_absence_compare(document, '.future, main')
	mut foreign := dom.Document.create(dom.url_about_blank())
	defer { foreign.finalize() }
	mut incoming := foreign.create_element('article')!
	incoming.set_attribute_value('class', 'adopted')
	assert !document.may_have_element_class('adopted')
	adopted := document.adopt_node_binding(incoming.as_node())!
	mut fragment := document.create_document_fragment()
	mut fragmentnode := unsafe { &dom.Node(fragment) }
	fragmentnode.append_child(adopted)!
	rootnode.append_child(fragmentnode)!
	rootnode.append_child(adopted.clone_node_binding(true)!)!
	assert query_selector_all(document.as_node(), '.adopted').len == 2
	class_absence_compare(document, '.adopted, .future')
}

fn test_document_class_absence_preserves_case_whitespace_namespaces_and_shadow_scopes() {
	for quirks in [false, true] {
		mut document := dom.Document.create(dom.url_about_blank())
		defer { document.finalize() }
		document.set_document_type(.xml)
		if quirks { document.set_quirks_mode(.yes) }
		mut host := document.create_element_ns(dom.namespace_html_uri, 'div')!
		mut docnode := document.as_node()
		docnode.append_child(host.as_node())!
		mut hostnode := host.as_node()
		for namespace in [dom.namespace_html_uri, 'http://www.w3.org/2000/svg', ''] {
			mut element := document.create_element_ns(namespace, 'item')!
			element.set_attribute_value_ns('class', 'foreign', 'q', 'urn:classes')
			element.set_attribute_value('class', 'ITEM\talpha\nÉtiquette\rjoined\fform-feed')
			hostnode.append_child(element.as_node())!
		}
		for selector in ['.ITEM', '.item', '.Étiquette', '.étiquette', '.alpha.joined',
			'.form-feed', r'.ITEM\9 alpha\a Étiquette\d joined\c form-feed', '.foreign', '.missing, *', '.missing, .ITEM', ':not(.missing)'] {
			class_absence_compare(document, selector)
		}
		shadow := host.attach_shadow(dom.ShadowRootInit{mode:.open})!
		mut shadownode := unsafe { &dom.Node(shadow) }
		mut inner := document.create_element('span')!
		inner.set_attribute_value('class', 'shadow-only')
		shadownode.append_child(inner.as_node())!
		assert query_selector_all(shadownode, '.shadow-only').len == 1
		class_absence_compare(document, '.shadow-only')
		mut detached := document.create_element('div')!
		mut detachednode := detached.as_node()
		mut child := document.create_element('p')!
		child.set_attribute_value('class', 'detached-only')
		detachednode.append_child(child.as_node())!
		assert query_selector_all(detachednode, '.detached-only').len == 1
		class_absence_compare(document, '.detached-only')
	}
}

fn test_document_class_absence_keeps_queries_live_after_the_summary_is_full() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut target := document.create_element('main')!
	mut classes := []string{}
	for index in 0 .. 600 { classes << 'token_${index}' }
	target.set_attribute_value('class', classes.join(' '))
	mut node := document.as_node()
	node.append_child(target.as_node())!
	for selector in ['.token_0', '.token_599', '.missing', '.missing, .token_599'] {
		class_absence_compare(document, selector)
	}
	assert query_selector_all(document.as_node(), '.token_599').len == 1
	target.set_attribute_value('class', 'new-after-capacity')
	assert query_selector_all(document.as_node(), '.new-after-capacity').len == 1
	mut large_document := dom.Document.create(dom.url_about_blank())
	defer { large_document.finalize() }
	mut large := large_document.create_element('main')!
	name := 'x'.repeat(40000)
	large.set_attribute_value('class', name)
	mut large_node := large_document.as_node()
	large_node.append_child(large.as_node())!
	assert query_selector_all(large_document.as_node(), '.' + name).len == 1
	large.set_attribute_value('class', 'after-large-token')
	assert query_selector_all(large_document.as_node(), '.after-large-token').len == 1
}
