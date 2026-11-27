module html

import dom

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

fn test_xml_default_namespace_reset_and_reused_text_stay_local_to_each_node() {
	parser := DOMParser.create(dom.Document.create(dom.url_about_blank()))
	mut document := parser.parse_from_string('<root xmlns="urn:outer"><first> repeated </first><second xmlns=""> repeated </second><third> repeated </third></root>', .application_xml)!
	defer { document.finalize() }
	root := document.document_element()?
	first := root.as_node().children[0].as_element()?
	second := root.as_node().children[1].as_element()?
	third := root.as_node().children[2].as_element()?
	assert first.namespace_uri()? == 'urn:outer'
	assert second.namespace_uri() == none
	assert third.namespace_uri()? == 'urn:outer'
	mut first_text := first.as_node().children[0].as_character_data()?
	second_text := second.as_node().children[0].as_character_data()?
	third_text := third.as_node().children[0].as_character_data()?
	assert first_text.data() == ' repeated '
	first_text.set_data('changed')
	assert first_text.data() == 'changed'
	assert second_text.data() == ' repeated '
	assert third_text.data() == ' repeated '
}
