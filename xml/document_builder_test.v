module xml

import dom

fn test_document_builder_builds_namespaces_character_data_and_readiness() {
	document := build_document('<?xml version="1.0"?><root xmlns="urn:root" xmlns:x="urn:x"><x:item a="1">A &amp; B<![CDATA[<c>]]></x:item><!--tail--></root>', dom.URL{
		value: 'https://example.test/data.xml'
	}, .enabled)!
	assert document.document_type() == .xml
	assert document.readiness() == .complete
	root := document.document_element() or { panic('missing root') }
	assert root.namespace_uri()? == 'urn:root'
	item := (root.as_node().first_child() or { panic('missing item') }).as_element() or {
		panic('not an element')
	}
	assert item.namespace_uri()? == 'urn:x'
	assert item.get_attribute('a')? == '1'
	assert item.as_node().text_content()? == 'A & B<c>'
}

fn test_document_builder_rejects_malformed_xml_and_resolves_named_entities() {
	if _ := build_document('<a><b></a>', dom.url_about_blank(), .disabled) {
		assert false
	}
	assert resolve_named_html_entity('nbsp')? == '\u00a0'
	assert resolve_named_html_entity('AElig')? == '\u00c6'
	assert resolve_named_html_entity('NotEqualTilde')? == '\u2242\u0338'
	assert resolve_named_html_entity('unknown') == none
}

fn test_document_builder_preserves_utf8_and_decodes_full_named_entity_table() {
	document := build_document('<root>Привет &AElig; &NotEqualTilde;</root>',
		dom.url_about_blank(), .disabled)!
	root := document.document_element() or { panic('missing root') }
	assert root.as_node().text_content()? == 'Привет Æ ≂̸'
}

fn test_document_builder_creates_doctype_external_identifiers() {
	document := build_document('<?xml version="1.0"?><!DOCTYPE root PUBLIC "-//TEST//DTD Root//EN" "root.dtd"><root/>',
		dom.url_about_blank(), .disabled)!
	doctype := document.doctype() or { panic('missing doctype') }
	assert doctype.name() == 'root'
	assert doctype.public_id() == '-//TEST//DTD Root//EN'
	assert doctype.system_id() == 'root.dtd'
}
