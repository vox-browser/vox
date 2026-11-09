module html

import dom
import platform

fn vlib_xml_parse_document(source string) !&dom.Document {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.xml)
	parse_xml_document_source(document, source)!
	return document
}

fn test_vlib_xml_preserves_mixed_content_and_whitespace_only_text() {
	mut document := vlib_xml_parse_document('<root> before <item/> between <blank> \t\n </blank> after </root>')!
	defer { document.finalize() }
	root := document.document_element()?
	children := root.as_node().children_as_vector()
	assert children.len == 5
	assert children[0].is_exclusive_text()
	assert children[0].character_data()?.data() == ' before '
	assert children[1].as_element()?.local_name() == 'item'
	assert children[2].character_data()?.data() == ' between '
	blank := children[3].as_element()?
	blank_text := blank.as_node().first_child()?
	assert blank_text.is_exclusive_text()
	assert blank_text.character_data()?.data() == ' \t\n '
	assert children[4].character_data()?.data() == ' after '
}

fn test_vlib_xml_preserves_comment_cdata_and_processing_instruction_order() {
	mut document := vlib_xml_parse_document('<!--before--><?xml-stylesheet href="sheet.css"?><root>A<!--&amp;--><![CDATA[ <raw>&amp; ]]><?inside &amp;?>B</root><?after data?><!--tail-->')!
	defer { document.finalize() }
	document_children := document.as_node().children_as_vector()
	assert document_children.len == 5
	assert document_children[0].is_comment()
	assert document_children[0].character_data()?.data() == 'before'
	assert document_children[1].as_processing_instruction()?.target() == 'xml-stylesheet'
	assert document_children[1].as_processing_instruction()?.data() == 'href="sheet.css"'
	assert document_children[3].as_processing_instruction()?.target() == 'after'
	assert document_children[4].is_comment()
	assert document_children[4].character_data()?.data() == 'tail'
	root := document_children[2].as_element()?
	children := root.as_node().children_as_vector()
	assert children.len == 5
	assert children[0].character_data()?.data() == 'A'
	assert children[1].is_comment()
	assert children[1].character_data()?.data() == '&amp;'
	assert children[2].is_cdata_section()
	assert children[2].character_data()?.data() == ' <raw>&amp; '
	assert children[3].as_processing_instruction()?.target() == 'inside'
	assert children[3].as_processing_instruction()?.data() == '&amp;'
	assert children[4].character_data()?.data() == 'B'
}

fn test_vlib_xml_accepts_xml_attribute_and_end_tag_spacing() {
	mut document := vlib_xml_parse_document('<root left = "a > b" right\t=\n"c &gt; d"><item></item \t></root >')!
	defer { document.finalize() }
	root := document.document_element()?
	assert root.get_attribute('left')? == 'a > b'
	assert root.get_attribute('right')? == 'c > d'
	assert root.as_node().first_child()?.as_element()?.local_name() == 'item'
}

fn test_vlib_xml_decodes_references_once_and_preserves_unicode() {
	mut document := vlib_xml_parse_document('<root value="&amp;amp; &AElig; &NotEqualTilde;">Привет 文 😀 &amp;amp; &AElig; &NotEqualTilde; &#65; &#x1F600;</root>')!
	defer { document.finalize() }
	root := document.document_element()?
	assert root.get_attribute('value')? == '&amp; Æ ≂̸'
	assert root.as_node().text_content()? == 'Привет 文 😀 &amp; Æ ≂̸ A 😀'
}

fn test_vlib_xml_preserves_default_namespace_undeclaration_and_attribute_namespaces() {
	mut document := vlib_xml_parse_document('<root xmlns="urn:outer" xmlns:p="urn:p"><plain xmlns="" ordinary="value" xml:lang="en"/><p:child xmlns:p="urn:inner" p:attr="inner"/><p:sibling p:attr="outer"/></root>')!
	defer { document.finalize() }
	root := document.document_element()?
	assert root.namespace_uri()? == 'urn:outer'
	children := root.as_node().children_as_vector()
	plain := children[0].as_element()?
	assert plain.namespace_uri() == none
	assert plain.get_attribute_ns(none, 'ordinary')? == 'value'
	assert plain.get_attribute_ns('http://www.w3.org/XML/1998/namespace', 'lang')? == 'en'
	inner := children[1].as_element()?
	assert inner.namespace_uri()? == 'urn:inner'
	assert inner.get_attribute_ns('urn:inner', 'attr')? == 'inner'
	sibling := children[2].as_element()?
	assert sibling.namespace_uri()? == 'urn:p'
	assert sibling.get_attribute_ns('urn:p', 'attr')? == 'outer'
}

fn test_vlib_xml_rejects_malformed_documents_through_dom_parser() {
	parser := DOMParser.create(dom.Document.create(dom.url_about_blank()))
	for source in [
		'<root/><second/>',
		'<root/>trailing',
		'leading<root/>',
		'<root><child></root>',
		'<root a="1" a="2"/>',
		'<missing:root/>',
		'<root missing:attribute="value"/>',
		'<root>&unknown;</root>',
		'<root value="a < b"/>',
		'<root/><?xml version="1.0"?>',
		'< root/>',
		'<root/ >',
		'<root xmlns:p="urn:same" xmlns:q="urn:same" p:a="1" q:a="2"/>',
		'</vox-xml-document><root/>',
		'<vox-xml-document><root/>',
	] {
		mut document := parser.parse_from_string(source, .application_xml)!
		root := document.document_element()?
		assert root.local_name() == 'parsererror', source
		assert root.namespace_uri()? == parser_error_namespace_uri, source
		document.finalize()
	}
}

fn test_vlib_xml_keeps_marker_like_author_comments_literal() {
	comment := 'vox-xml-special:not-an-index'
	mut document := vlib_xml_parse_document('<!--${comment}--><root><!--vox-xml-special:0--><?inside data?></root>')!
	defer { document.finalize() }
	first := document.as_node().first_child()?
	assert first.is_comment()
	assert first.character_data()?.data() == comment
	root := document.document_element()?
	children := root.as_node().children_as_vector()
	assert children.len == 2
	assert children[0].is_comment()
	assert children[0].character_data()?.data() == 'vox-xml-special:0'
	assert children[1].as_processing_instruction()?.target() == 'inside'
	assert children[1].as_processing_instruction()?.data() == 'data'
}

fn test_vlib_xml_keeps_author_element_with_the_internal_wrapper_name() {
	mut document := vlib_xml_parse_document('<vox-xml-document><item/></vox-xml-document>')!
	defer { document.finalize() }
	root := document.document_element()?
	assert root.local_name() == 'vox-xml-document'
	assert root.as_node().first_child()?.as_element()?.local_name() == 'item'
}

fn test_vlib_xml_preserves_doctype_identifiers_and_document_order() {
	mut document := vlib_xml_parse_document('<?xml version="1.0"?><!--before--><!DOCTYPE root PUBLIC "-//TEST//DTD Root//EN" "root.dtd"><root/><!--after-->')!
	defer { document.finalize() }
	doctype := document.doctype()?
	assert doctype.name() == 'root'
	assert doctype.public_id() == '-//TEST//DTD Root//EN'
	assert doctype.system_id() == 'root.dtd'
	children := document.as_node().children_as_vector()
	assert children.len == 4
	assert children[0].is_comment()
	assert children[1].is_document_type()
	assert children[2].as_element()?.local_name() == 'root'
	assert children[3].is_comment()
}

@[noinline]
fn vlib_xml_churn_parser_scratch() {
	// Reuse the parser's parent arena and scratch label. Under the native CI
	// poison setting, retiring this label also makes stale parser bytes fault.
	for index in 0 .. 8 {
		scratch := platform.begin_thread_scratch('XML parse tree')
		bytes := []u8{len: 256 * 1024, init: u8(index + 17)}
		assert bytes[0] == u8(index + 17)
		assert bytes[bytes.len - 1] == u8(index + 17)
		scratch.finish()
	}
}

fn test_vlib_xml_dom_payloads_survive_parser_scratch_retirement() {
	long_attribute := 'long-path-value '.repeat(256)
	source := '<?before document?><!DOCTYPE root PUBLIC "-//TEST//DTD Root//EN" "root.dtd"><root xmlns="urn:default" xmlns:p="urn:prefixed" plain="short" long="${long_attribute}&lt;tail&gt;" p:flag="namespace-value"><p:item> lead &amp; tail <![CDATA[ <raw>&amp; ]]><!--comment &amp;--><?work retained?><label>plain</label><nested xmlns="urn:inner"/></p:item><sibling/></root><?after document?>'
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.xml)
	document.enable_native_storage()
	mut owner_scope := document.enter_native_storage()
	defer {
		owner_scope.finish()
		document.destroy()
		document.finalize()
		document.release_native_storage()
	}
	parse_xml_document_source(document, source)!
	vlib_xml_churn_parser_scratch()
	owner_scope.finish()

	document_children := document.as_node().children_as_vector()
	assert document_children.len == 4
	assert document_children[0].as_processing_instruction()?.target() == 'before'
	assert document_children[0].as_processing_instruction()?.data() == 'document'
	doctype := document_children[1].as_document_type()?
	assert doctype.name() == 'root'
	assert doctype.public_id() == '-//TEST//DTD Root//EN'
	assert doctype.system_id() == 'root.dtd'
	assert document_children[3].as_processing_instruction()?.target() == 'after'
	assert document_children[3].as_processing_instruction()?.data() == 'document'

	root := document.document_element()?
	assert root.local_name() == 'root'
	assert root.namespace_uri()? == 'urn:default'
	assert root.get_attribute('xmlns')? == 'urn:default'
	assert root.get_attribute('xmlns:p')? == 'urn:prefixed'
	assert root.get_attribute('plain')? == 'short'
	assert root.get_attribute('long')? == long_attribute + '<tail>'
	assert root.get_attribute_ns('urn:prefixed', 'flag')? == 'namespace-value'
	item := root.as_node().children[0].as_element()?
	assert item.node_name() == 'p:item'
	assert item.prefix()? == 'p'
	assert item.local_name() == 'item'
	assert item.namespace_uri()? == 'urn:prefixed'
	children := item.as_node().children_as_vector()
	assert children.len == 6
	assert children[0].is_exclusive_text()
	assert children[0].character_data()?.data() == ' lead & tail '
	assert children[1].is_cdata_section()
	assert children[1].character_data()?.data() == ' <raw>&amp; '
	assert children[2].is_comment()
	assert children[2].character_data()?.data() == 'comment &amp;'
	assert children[3].as_processing_instruction()?.target() == 'work'
	assert children[3].as_processing_instruction()?.data() == 'retained'
	label := children[4].as_element()?
	assert label.local_name() == 'label'
	assert label.namespace_uri()? == 'urn:default'
	assert label.as_node().first_child()?.character_data()?.data() == 'plain'
	assert children[5].as_element()?.namespace_uri()? == 'urn:inner'
	sibling := root.as_node().children[1].as_element()?
	assert sibling.local_name() == 'sibling'
	assert sibling.namespace_uri()? == 'urn:default'
}

fn vlib_xml_captured_parse_error(document &dom.Document, source string) IError {
	parse_xml_document_source(document, source) or { return err }
	panic('expected malformed XML to fail')
}

fn test_vlib_xml_parse_errors_survive_parser_scratch_retirement() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.xml)
	document.enable_native_storage()
	mut owner_scope := document.enter_native_storage()
	defer {
		owner_scope.finish()
		document.destroy()
		document.finalize()
		document.release_native_storage()
	}
	entity_error := vlib_xml_captured_parse_error(document, '<root value="&missing;"/>')
	structure_error := vlib_xml_captured_parse_error(document, '<root><child/></wrong>')
	vlib_xml_churn_parser_scratch()
	owner_scope.finish()
	assert entity_error.msg().contains('unknown XML entity &missing;')
	assert structure_error.msg().contains('root')
	assert structure_error.msg().contains('not closed')
}
