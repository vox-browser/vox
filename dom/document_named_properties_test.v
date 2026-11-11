module dom

const document_named_properties_test_html_namespace = 'http://www.w3.org/1999/xhtml'

fn document_named_properties_test_element(document &Document, local_name string) &Element {
	return document.create_element_ns(document_named_properties_test_html_namespace, local_name) or {
		panic(err)
	}
}

fn append_named_property_test_node(mut parent Node, child &Node) {
	parent.append_child(child) or { panic(err) }
}

fn test_document_named_properties_follow_upstream_element_filter_and_result_types() {
	mut document := Document.create(url_about_blank())
	mut document_node := unsafe { &Node(document) }
	mut root := document_named_properties_test_element(document, 'html')
	append_named_property_test_node(mut document_node, root.as_node())
	mut root_node := root.as_node()

	mut ordinary := document_named_properties_test_element(document, 'div')
	append_named_property_test_node(mut root_node, ordinary.as_node())
	ordinary.set_attribute_value('id', 'not-exposed')
	ordinary.set_attribute_value('name', 'also-not-exposed')

	mut first := document_named_properties_test_element(document, 'img')
	append_named_property_test_node(mut root_node, first.as_node())
	first.set_attribute_value('name', 'shared')
	first.set_attribute_value('id', 'first-id')

	mut second := document_named_properties_test_element(document, 'form')
	append_named_property_test_node(mut root_node, second.as_node())
	second.set_attribute_value('name', 'shared')

	assert 'not-exposed' !in document.supported_property_names()
	assert 'also-not-exposed' !in document.supported_property_names()
	assert document.supported_property_names() == ['first-id', 'shared']

	single := document.named_item_value('first-id')
	assert single.element? == first
	assert single.collection == none

	multiple := document.named_item_value('shared')
	collection := multiple.collection or { panic('expected a live HTMLCollection') }
	assert collection.length() == 2
	assert collection.item(0)? == first
	assert collection.item(1)? == second
	assert multiple.to_js_value().kind == .object
}

fn document_named_properties_test_window_proxy(_ voidptr) ?&WindowProxy {
	return &WindowProxy{}
}

fn test_document_named_iframe_returns_active_window_proxy() {
	mut document := Document.create(url_about_blank())
	mut iframe := document_named_properties_test_element(document, 'iframe')
	iframe.set_attribute_value('name', 'child')
	document.insert_in_potentially_named_elements(iframe)
	mut iframe_node := iframe.as_node()
	iframe_node.set_active_window_proxy_hook(NodeActiveWindowProxyHook{
		callback: document_named_properties_test_window_proxy
	})

	result := document.named_item_value('child')
	assert result.window_proxy != none
	assert result.element == none
	assert result.to_js_value().kind == .object
}
