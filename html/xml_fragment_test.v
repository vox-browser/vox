module html

import dom

fn test_xml_fragment_inherits_default_and_prefixed_namespaces() {
	document := dom.Document.create(dom.url_about_blank())
	mut context := document.create_element_ns('urn:default', 'context')!
	context.set_attribute_ns_for_bindings('http://www.w3.org/2000/xmlns/', 'xmlns', 'urn:default')!
	context.set_attribute_ns_for_bindings('http://www.w3.org/2000/xmlns/', 'xmlns:q', 'urn:child')!
	nodes := parse_xml_fragment_with_options(context, '<q:item>ok</q:item><plain/>', false)!
	assert nodes.len == 2
	item := nodes[0].as_element() or { panic('not element') }
	plain := nodes[1].as_element() or { panic('not element') }
	assert item.namespace_uri()? == 'urn:child'
	assert item.as_node().text_content()? == 'ok'
	assert plain.namespace_uri()? == 'urn:default'
	// The upstream algorithm returns the temporary document's actual children;
	// adoption occurs later if callers insert them into the context document.
	assert item.as_node().document() != context.document()
	assert item.as_node().document().allow_declarative_shadow_roots() == false
}

fn test_xml_fragment_sets_declarative_shadow_root_mode_on_temporary_document() {
	document := dom.Document.create(dom.url_about_blank())
	context := document.create_element_ns(none, 'context')!
	nodes := parse_xml_fragment_with_options(context, '<child/>', true)!
	assert nodes[0].document().allow_declarative_shadow_roots()
}

fn test_xml_fragment_rejects_not_well_formed_input() {
	document := dom.Document.create(dom.url_about_blank())
	context := document.create_element_ns(none, 'context')!
	if _ := parse_xml_fragment_with_options(context, '<a></b>', false) {
		assert false
	} else {
		assert err.str().contains('SyntaxError')
	}
}
