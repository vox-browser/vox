module html

import platform
import dom

fn test_xml_entity_free_tokens_do_not_duplicate_owned_input() {
	source := 'M 0 0 L 1 1 '.repeat(65536) + 'café 文 😀'
	before := platform.thread_arena_usage().used
	decoded := xml_decode_references(source)!
	assert decoded == source
	$if prealloc {
		assert platform.thread_arena_usage().used == before
	}
	assert xml_decode_references('')! == ''
	assert xml_decode_references('plain < > " text')! == 'plain < > " text'
	assert xml_decode_references('café&amp;文&#x1F600;')! == 'café&文😀'
}

fn test_xml_prefix_probes_do_not_allocate_substrings() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut parser := SimpleXMLDocumentParser{ source: 'text<!--next--><![CDATA[data]]><item/>', document: document }
	before := platform.thread_arena_usage().used
	for _ in 0 .. 1024 {
		parser.position = 4
		assert parser.starts_with('<!--')
		assert !parser.starts_with('<![CDATA[')
		parser.position = 15
		assert parser.starts_with('<![CDATA[')
		assert !parser.starts_with('</')
		parser.position = parser.source.len
		assert parser.starts_with('')
		assert !parser.starts_with('>')
	}
	$if prealloc {
		assert platform.thread_arena_usage().used == before
	}
}

fn test_xml_namespace_declarations_are_local_to_the_element_subtree() {
	parser := DOMParser.create(dom.Document.create(dom.url_about_blank()))
	mut document := parser.parse_from_string('<root xmlns="urn:outer" xmlns:p="urn:p"><nested xmlns="urn:inner" xmlns:p="urn:inner-p"><p:child p:attr="value"/></nested><p:sibling/><tail/></root>', .application_xml)!
	defer { document.finalize() }
	root := document.document_element()?
	nested := root.as_node().children[0].as_element()?
	inner := nested.as_node().children[0].as_element()?
	sibling := root.as_node().children[1].as_element()?
	tail := root.as_node().children[2].as_element()?
	assert root.namespace_uri()? == 'urn:outer'
	assert nested.namespace_uri()? == 'urn:inner'
	assert inner.namespace_uri()? == 'urn:inner-p'
	assert inner.get_attribute_ns('urn:inner-p', 'attr')? == 'value'
	assert sibling.namespace_uri()? == 'urn:p'
	assert tail.namespace_uri()? == 'urn:outer'
}

fn test_xml_duplicate_attributes_are_rejected_for_small_and_large_elements() {
	parser := DOMParser.create(dom.Document.create(dom.url_about_blank()))
	for count in [1, 15, 16, 17, 40] {
		mut attributes := ''
		for index in 0 .. count { attributes += ' a' + index.str() + '="' + index.str() + '"' }
		mut valid := parser.parse_from_string('<root' + attributes + '/>', .application_xml)!
		defer { valid.finalize() }
		root := valid.document_element()?
		assert root.local_name() == 'root'
		assert root.get_attribute('a' + (count - 1).str())? == (count - 1).str()
		for duplicate in [0, count - 1] {
			mut invalid := parser.parse_from_string('<root' + attributes + ' a' + duplicate.str() + '="duplicate"/>', .application_xml)!
			assert invalid.document_element()?.local_name() == 'parsererror'
			invalid.finalize()
		}
	}
}
