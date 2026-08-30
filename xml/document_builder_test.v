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

fn test_xml_document_builder_listener_entry_points() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.xml)
	mut builder := XMLDocumentBuilder.create(document, .disabled)
	builder.set_source('<not parsed directly>')!
	builder.set_doctype(XMLDoctype{
		type_: 'root'
		external_id: XMLExternalID{
			system_id: 'root.dtd'
			public_id: '-//TEST//DTD Root//EN'
		}
	})
	builder.element_start('root', {
		'xmlns':   'urn:root'
		'xmlns:x': 'urn:item'
	})
	assert builder.namespace_for_name('root')? == 'urn:root'
	assert builder.namespace_for_name('x:item')? == 'urn:item'
	builder.element_start('x:item', {
		'xml:lang': 'en'
	})
	builder.text('hello')
	builder.text(' world')
	builder.cdata_section('<raw>')
	builder.element_end('x:item')
	builder.comment('tail')
	builder.processing_instruction('work', 'data')
	builder.element_end('root')
	builder.document_end()

	assert !builder.has_error()
	assert document.readiness() == .complete
	assert document.doctype()?.system_id() == 'root.dtd'
	root := document.document_element() or { panic('missing root') }
	assert root.namespace_uri()? == 'urn:root'
	item := root.as_node().first_child()?.as_element() or { panic('missing item') }
	assert item.namespace_uri()? == 'urn:item'
	assert item.get_attribute_ns('http://www.w3.org/XML/1998/namespace', 'lang')? == 'en'
	assert item.as_node().text_content()? == 'hello world<raw>'
}
