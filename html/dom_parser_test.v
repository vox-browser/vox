module html

import dom

fn test_dom_parser_parses_html_and_preserves_document_metadata() {
	mut associated := dom.Document.create(dom.URL{ value: 'https://example.test/page' })
	associated.set_origin(dom.Origin{ value: 'https://example.test' })
	parser := DOMParser.create(associated)
	document := parser.parse_from_string('<!doctype html><title>Hello</title><p>World</p>',
		.text_html) or { panic(err) }
	assert document.get_content_type() == 'text/html'
	assert document.document_type() == .html
	assert document.origin() == associated.origin()
	document_element := document.document_element() or { panic('missing document element') }
	assert document_element.local_name() == 'html'
}

fn test_dom_parser_parses_namespaced_xml_and_entities() {
	associated := dom.Document.create(dom.url_about_blank())
	parser := DOMParser.create(associated)
	document := parser.parse_from_string('<?xml version="1.0"?><root xmlns="urn:test" xmlns:x="urn:x"><x:item answer="42">A &amp; B<![CDATA[ <C> ]]></x:item></root>',
		.application_xml) or { panic(err) }
	root := document.document_element() or { panic('missing root') }
	assert root.local_name() == 'root'
	assert root.namespace_uri() or { '' } == 'urn:test'
	item_node := root.as_node().first_child() or { panic('missing item') }
	item := item_node.as_element() or { panic('item is not an element') }
	assert item.local_name() == 'item'
	assert item.namespace_uri() or { '' } == 'urn:x'
	assert item.get_attribute('answer') or { '' } == '42'
	assert item.as_node().text_content() or { '' } == 'A & B <C> '
}

fn test_dom_parser_returns_parsererror_for_malformed_xml() {
	associated := dom.Document.create(dom.url_about_blank())
	parser := DOMParser.create(associated)
	document := parser.parse_from_string('<root><child></root>', .text_xml) or { panic(err) }
	root := document.document_element() or { panic('missing parsererror') }
	assert root.local_name() == 'parsererror'
	assert root.namespace_uri() or { '' } == parser_error_namespace_uri
}

fn test_dom_parser_construct_impl() {
	associated := dom.Document.create(dom.url_about_blank())
	parser := DOMParser.construct_impl(associated) or { panic(err) }
	assert parser.associated_document == associated
}
