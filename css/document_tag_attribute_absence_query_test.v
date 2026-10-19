module css

import dom

fn tag_attribute_test_document() &dom.Document {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.html)
	mut root := document.create_element('main') or { panic(err) }
	mut node := document.as_node()
	node.append_child(root.as_node()) or { panic(err) }
	mut sheet := document.create_element('style') or { panic(err) }
	sheet.set_attribute_value('id', 'sheet')
	mut rootnode := root.as_node()
	rootnode.append_child(sheet.as_node()) or { panic(err) }
	mut link := document.create_element('a') or { panic(err) }
	link.set_attribute_value('title', 'other')
	rootnode.append_child(link.as_node()) or { panic(err) }
	return document
}

fn tag_attribute_absence_compare(document &dom.Document, selector string) {
	parsed := parse_query_selector_list(selector) or { panic(selector) }
	mut expected := []&dom.Element{}
	query_selector_all_in(document.as_node(), parsed, mut expected)
	actual := query_selector_all(document.as_node(), selector)
	assert actual.len == expected.len, selector
	for index, element in expected {
		assert voidptr(actual[index]) == voidptr(element), selector
	}
	if first := query_selector(document.as_node(), selector) {
		assert expected.len > 0 && voidptr(first) == voidptr(expected[0]), selector
	} else {
		assert expected.len == 0, selector
	}
}

fn test_tag_attribute_absence_tracks_live_attributes_without_retaining_elements() {
	mut document := tag_attribute_test_document()
	defer { document.finalize() }
	mut sheet := document.get_element_by_id('sheet') or { panic('sheet') }
	assert document.has_seen_element_local_name('style')
	assert !document.may_have_tag_attribute('style', 'title')
	before := query_selector_all(document.as_node(), 'style[title]')
	assert before.len == 0
	sheet.set_attribute_value('title', 'Night')
	assert document.may_have_tag_attribute('style', 'title')
	assert before.len == 0
	for selector in ['style[title]', 'style[title=Night]', 'style[title=Day]',
		'link[rel][href][title], style[title]', 'a[title], style[title]'] {
		tag_attribute_absence_compare(document, selector)
	}
	sheet.set_attribute_value('title', 'Day')
	tag_attribute_absence_compare(document, 'style[title=Day]')
	sheet.remove_attribute('title')
	assert document.may_have_tag_attribute('style', 'title')
	tag_attribute_absence_compare(document, 'style[title]')
}

fn test_tag_attribute_absence_tracks_adopted_cloned_and_fragment_descendants() {
	mut document := tag_attribute_test_document()
	defer { document.finalize() }
	mut foreign := tag_attribute_test_document()
	defer { foreign.finalize() }
	assert !document.may_have_tag_attribute('style', 'title')
	incoming := foreign.document_element() or { panic('wrapper') }
	mut incoming_sheet := foreign.get_element_by_id('sheet') or { panic('sheet') }
	incoming_sheet.set_attribute_value('title', 'Incoming')
	adopted := document.adopt_node_binding(incoming.as_node())!
	mut fragment := document.create_document_fragment()
	mut fragmentnode := unsafe { &dom.Node(fragment) }
	fragmentnode.append_child(adopted)!
	fragmentnode.append_child(adopted.clone_node_binding(true)!)!
	host := document.document_element() or { panic('host') }
	mut hostnode := host.as_node()
	hostnode.append_child(fragmentnode)!
	assert query_selector_all(document.as_node(), 'style[title]').len == 2
	tag_attribute_absence_compare(document, 'style[title=Incoming]')
}

fn test_tag_attribute_absence_preserves_xml_case_namespaces_and_non_ascii_names() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.xml)
	mut host := document.create_element_ns('', 'Root')!
	mut node := document.as_node()
	node.append_child(host.as_node())!
	mut hostnode := host.as_node()
	for name in ['item', 'ITEM', 'élève'] {
		mut item := document.create_element_ns('', name)!
		item.set_attribute_ns_for_bindings('urn:test', 'p:TITLE', 'foreign')!
		item.set_attribute_value('title', 'plain')
		item.set_attribute_value('donnée', 'value')
		hostnode.append_child(item.as_node())!
	}
	for selector in ['item[title]', 'ITEM[TITLE]', 'item[*|TITLE]', 'item[|title]', 'item[donnée]',
		'élève[donnée]', 'item[absent], ITEM[title]', '*[title]'] {
		tag_attribute_absence_compare(document, selector)
	}
	mut shadowhost := document.create_element_ns(dom.namespace_html_uri, 'div')!
	hostnode.append_child(shadowhost.as_node())!
	shadow := shadowhost.attach_shadow(dom.ShadowRootInit{ mode: .open })!
	mut shadownode := unsafe { &dom.Node(shadow) }
	mut inner := document.create_element('style')!
	inner.set_attribute_value('title', 'shadow')
	shadownode.append_child(inner.as_node())!
	assert query_selector_all(shadownode, 'style[title]').len == 1
	tag_attribute_absence_compare(document, 'style[title]')
}

fn test_tag_attribute_absence_saturated_history_falls_back_to_live_matching() {
	mut document := tag_attribute_test_document()
	defer { document.finalize() }
	mut sheet := document.get_element_by_id('sheet') or { panic('sheet') }
	for index in 0 .. 512 { sheet.set_attribute_value('data-history-${index}', 'seen') }
	for index in 0 .. 512 { sheet.remove_attribute('data-history-${index}') }
	sheet.set_attribute_value('data-future', 'new')
	for selector in ['style[data-history-511]', 'style[data-future]', 'style[data-future=new]',
		'style[data-absent], style[data-future]'] {
		tag_attribute_absence_compare(document, selector)
	}
	assert query_selector_all(document.as_node(), 'style[data-future]').len == 1
}
