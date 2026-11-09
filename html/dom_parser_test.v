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

fn test_dom_parser_places_processing_instructions_at_their_parse_location() {
	parser := DOMParser.create(dom.Document.create(dom.url_about_blank()))
	document := parser.parse_from_string('<?before document?><!DOCTYPE root [<?ignored subset?>]><root><?inside element?></root><?after document?>', .text_xml) or { panic(err) }
	children := unsafe { &dom.Node(document) }.children_as_vector()
	assert children.len == 4
	assert children[0].as_processing_instruction()?.target() == 'before'
	assert children[1].is_document_type()
	root := children[2].as_element() or { panic('missing document element') }
	inside := root.as_node().first_child() or { panic('missing element processing instruction') }
	assert inside.as_processing_instruction()?.target() == 'inside'
	assert children[3].as_processing_instruction()?.target() == 'after'
}

fn test_dom_parser_preserves_processing_instruction_targets_starting_with_xml() {
	parser := DOMParser.create(dom.Document.create(dom.url_about_blank()))
	for target in ['xml-stylesheet', 'xml-model', 'xmlfoo'] {
		for declaration in ['', '<?xml version="1.0"?>'] {
			mut document := parser.parse_from_string(declaration + '<?' + target +
				' href="sheet.css"?><root/>', .application_xml) or { panic(err) }
			children := document.as_node().children_as_vector()
			assert children.len == 2
			instruction := children[0].as_processing_instruction() or { panic('missing instruction') }
			assert instruction.target() == target
			assert instruction.data() == 'href="sheet.css"'
			root := children[1].as_element() or { panic('missing root') }
			assert root.local_name() == 'root'
			document.finalize()
		}
	}
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
