module css

import dom

fn absence_compare_query(document &dom.Document, selector string) {
	root := document.as_node()
	selectors := parse_query_selector_list(selector) or { panic('invalid selector') }
	mut expected := []&dom.Element{}
	query_selector_all_in(root, selectors, mut expected)
	actual := query_selector_all(root, selector)
	assert actual.len == expected.len, selector
	for index, element in actual { assert voidptr(element) == voidptr(expected[index]), selector }
	if first := query_selector(root, selector) {
		assert expected.len > 0
		assert voidptr(first) == voidptr(expected[0])
	} else { assert expected.len == 0 }
	install_document_selector_query_hook(document)
	hook := document.selector_query_hook() or { panic('missing selector hook') }
	mut owner := unsafe { &dom.Document(document) }
	owner.set_selector_query_hook(dom.DocumentSelectorQueryHook{...hook, scope_query:unsafe { nil }})
	expected_dom := unsafe { &dom.ParentNode(root) }.query_selector_all(selector) or { panic(err) }
	owner.set_selector_query_hook(hook)
	dom_nodes := unsafe { &dom.ParentNode(root) }.query_selector_all(selector) or { panic(err) }
	assert dom_nodes.nodes.len == expected_dom.nodes.len, selector
	for index, node in dom_nodes.nodes { assert voidptr(node) == voidptr(expected_dom.nodes[index]), selector }
}

fn test_document_tag_absence_query_observes_fragments_cloning_and_adoption() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	mut root := document.create_element('main')!
	mut root_node := root.as_node()
	mut document_node := document.as_node()
	_ = document_node.append_child(root_node)!
	_ = root_node.append_child(document.create_element('p')!.as_node())!
	for selector in ['audio, video', 'use', 'p', 'VIDEO, p'] {
		absence_compare_query(document, selector)
	}
	assert !document.has_seen_element_local_name('video')
	media_selectors := parse_query_selector_list('audio, video')?
	media_compounds := independent_query_compounds(media_selectors)?
	assert !independent_query_may_match_document(document.as_node(), media_compounds)
	root_node.remove_all_children(false)
	mut fragment := document.create_document_fragment()
	mut fragment_node := unsafe { &dom.Node(fragment) }
	mut video := document.create_element('video')!
	video.set_attribute_value('controls', '')
	_ = fragment_node.append_child(video.as_node())!
	use_element := document.create_element_ns('http://www.w3.org/2000/svg', 'use')!
	_ = fragment_node.append_child(use_element.as_node())!
	_ = root_node.append_child(fragment_node)!
	assert document.has_seen_element_local_name('video')
	assert document.has_seen_element_local_name('use')
	assert independent_query_may_match_document(document.as_node(), media_compounds)
	for selector in ['audio, video', 'use', 'VIDEO', 'video[controls]'] { absence_compare_query(document, selector) }
	mut foreign := dom.Document.create(dom.url_about_blank())
	defer { foreign.finalize() }
	adopted := document.adopt_node_binding(foreign.create_element('audio')!.as_node())!
	_ = root_node.append_child(adopted)!
	assert document.has_seen_element_local_name('audio')
	mut copy := adopted.clone_node_binding(true)!
	_ = root_node.pre_insert(copy, root_node.first_child())!
	absence_compare_query(document, 'audio, video')
	root_node.remove_all_children(false)
	_ = root_node.append_child(document.create_text_node('plain text').as_node())!
	assert document.has_seen_element_local_name('audio')
	assert document.has_seen_element_local_name('video')
	absence_compare_query(document, 'audio, video, use')
}

fn test_document_tag_absence_query_preserves_xml_case_namespaces_and_other_scopes() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.xml)
	mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'section')!
	mut document_node := document.as_node()
	_ = document_node.append_child(host.as_node())!
	mut host_node := host.as_node()
	for namespace in ['http://www.w3.org/2000/svg', 'http://www.w3.org/1999/xhtml', ''] {
		element := document.create_element_ns(namespace, 'linearGradient')!
		_ = host_node.append_child(element.as_node())!
		unicode_element := dom.Element.new(document, dom.QualifiedName{local_name:'Élément', namespace_:namespace})
		_ = host_node.append_child(unicode_element.as_node())!
	}
	for selector in ['linearGradient', 'lineargradient', '*|linearGradient', '|linearGradient', 'Élément', 'élément', 'absent, *', 'section.missing', ':scope > *', 'section > *'] {
		absence_compare_query(document, selector)
	}
	mut detached := document.create_element('div')!
	mut detached_node := detached.as_node()
	_ = detached_node.append_child(document.create_element('unknown')!.as_node())!
	assert query_selector_all(detached.as_node(), '*').len == 1
	shadow := host.attach_shadow(dom.ShadowRootInit{mode:.open})!
	mut shadow_node := unsafe { &dom.Node(shadow) }
	video := document.create_element('video')!
	_ = shadow_node.append_child(video.as_node())!
	assert query_selector_all(shadow_node, 'video').len == 1
	absence_compare_query(document, 'video')
	// The DOM entrypoint must validate named namespaces before the shortcut.
	_ = unsafe { &dom.ParentNode(document.as_node()) }.query_selector_all('missing|never') or {
		assert err.msg().contains('SyntaxError')
		return
	}
	assert false
}

fn absence_compare_scoped_query(root &dom.Node, selector string) {
	selectors := parse_query_selector_list(selector) or { panic('invalid selector') }
	mut expected := []&dom.Element{}
	query_selector_all_in(root, selectors, mut expected)
	actual := query_selector_all(root, selector)
	assert actual.len == expected.len, selector
	for index, element in actual { assert voidptr(element) == voidptr(expected[index]), selector }
	if first := query_selector(root, selector) {
		assert expected.len > 0, selector
		assert voidptr(first) == voidptr(expected[0]), selector
	} else { assert expected.len == 0, selector }
}

// Connected elements and shadow roots use the document's name history like
// the document itself; detached subtrees, whose descendants may never have
// been inserted, keep the walk. Results always equal the plain traversal.
fn test_tag_absence_covers_connected_roots_and_spares_detached_ones() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	mut main := document.create_element('main')!
	mut main_node := main.as_node()
	mut document_node := document.as_node()
	_ = document_node.append_child(main_node)!
	mut section := document.create_element('section')!
	section.set_attribute_value('class', 'pane')
	mut section_node := section.as_node()
	_ = main_node.append_child(section_node)!
	_ = section_node.append_child(document.create_element('p')!.as_node())!
	mut host := document.create_element('div')!
	_ = main_node.append_child(host.as_node())!
	shadow := host.attach_shadow(dom.ShadowRootInit{mode: .open})!
	mut shadow_node := shadow.as_node()
	_ = shadow_node.append_child(document.create_element('span')!.as_node())!
	selectors := ['lazy-element', 'p', 'span', 'section.pane', 'p.missing', 'section[data-x]',
		'lazy-element, p', 'LAZY-ELEMENT', '*', 'main p']
	lazy := independent_query_compounds(parse_query_selector_list('lazy-element')?)?
	precise := !retain_document_only_absence_queries
	for root in [main_node, section_node, shadow_node] {
		assert independent_query_may_match_document(root, lazy) == !precise
		for selector in selectors { absence_compare_scoped_query(root, selector) }
	}
	// A detached subtree built without ever entering the document.
	mut detached := document.create_element('aside')!
	mut detached_node := detached.as_node()
	_ = detached_node.append_child(document.create_element('lazy-element')!.as_node())!
	assert independent_query_may_match_document(detached_node, lazy)
	for selector in selectors { absence_compare_scoped_query(detached_node, selector) }
	mut fragment := document.create_document_fragment()
	mut fragment_node := unsafe { &dom.Node(fragment) }
	_ = fragment_node.append_child(document.create_element('other-element')!.as_node())!
	other := independent_query_compounds(parse_query_selector_list('other-element')?)?
	assert independent_query_may_match_document(fragment_node, other)
	for selector in ['other-element', 'lazy-element'] { absence_compare_scoped_query(fragment_node, selector) }
	// Inserting the subtree publishes its names for every connected root, and
	// removing it leaves a harmless positive entry.
	_ = section_node.append_child(detached_node)!
	for root in [main_node, section_node, detached_node] {
		assert independent_query_may_match_document(root, lazy)
		for selector in selectors { absence_compare_scoped_query(root, selector) }
	}
	assert independent_query_may_match_document(shadow_node, lazy)
	for selector in selectors { absence_compare_scoped_query(shadow_node, selector) }
	_ = section_node.remove_child(detached_node)!
	for root in [main_node, section_node, detached_node, shadow_node] {
		for selector in selectors { absence_compare_scoped_query(root, selector) }
	}
	// A clone is detached until it is inserted, and then publishes its names.
	mut article := document.create_element('article')!
	mut article_node := article.as_node()
	mut later := document.create_element('later-element')!
	later.set_attribute_value('class', 'x')
	_ = article_node.append_child(later.as_node())!
	mut copy := article_node.clone_node_binding(true)!
	later_compounds := independent_query_compounds(parse_query_selector_list('later-element')?)?
	assert independent_query_may_match_document(copy, later_compounds)
	_ = main_node.append_child(copy)!
	assert independent_query_may_match_document(main_node, later_compounds)
	for root in [main_node, section_node, copy, article_node] {
		for selector in ['later-element', 'later-element.x', 'article later-element', 'lazy-element', 'never-element'] {
			absence_compare_scoped_query(root, selector)
		}
	}
}
