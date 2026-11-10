module html

import dom
import namespace_

const xs_html_ns = 'http://www.w3.org/1999/xhtml'

fn serialize(node &dom.Node) string {
	return serialize_node_to_xml_string(node, .no) or { panic('serialize: ${err}') }
}

fn test_element_with_text_child_and_escaping() {
	doc := dom.Document.create(dom.url_about_blank())
	mut div := doc.create_element_ns(xs_html_ns, 'div') or { panic('${err}') }
	mut div_node := div.as_node()
	div_node.append_child(doc.create_text_node('a & b < c > d').as_node()) or { panic('${err}') }
	// A non-void HTML element keeps an explicit end tag; text escapes &, <, >.
	assert serialize(div_node) == '<div xmlns="http://www.w3.org/1999/xhtml">a &amp; b &lt; c &gt; d</div>'
}

fn test_void_html_element_is_self_closing() {
	doc := dom.Document.create(dom.url_about_blank())
	br := doc.create_element_ns(xs_html_ns, 'br') or { panic('${err}') }
	assert serialize(br.as_node()) == '<br xmlns="http://www.w3.org/1999/xhtml" />'
}

fn test_attribute_serialization_and_escaping() {
	doc := dom.Document.create(dom.url_about_blank())
	mut div := doc.create_element_ns(xs_html_ns, 'div') or { panic('${err}') }
	div.set_attribute_value('class', 'a"b&c')
	assert serialize(div.as_node()) == '<div xmlns="http://www.w3.org/1999/xhtml" class="a&quot;b&amp;c"></div>'
}

fn test_non_html_namespace_declares_default_namespace_and_self_closes() {
	doc := dom.Document.create(dom.url_about_blank())
	root := doc.create_element_ns('http://example.com/ns', 'root') or { panic('${err}') }
	assert serialize(root.as_node()) == '<root xmlns="http://example.com/ns"/>'
}

fn test_nested_elements() {
	doc := dom.Document.create(dom.url_about_blank())
	mut parent := doc.create_element_ns(xs_html_ns, 'p') or { panic('${err}') }
	mut parent_node := parent.as_node()
	child := doc.create_element_ns(xs_html_ns, 'span') or { panic('${err}') }
	parent_node.append_child(child.as_node()) or { panic('${err}') }
	assert serialize(parent_node) == '<p xmlns="http://www.w3.org/1999/xhtml"><span></span></p>'
}

fn test_comment_node() {
	doc := dom.Document.create(dom.url_about_blank())
	comment := doc.create_comment('hello')
	assert serialize(comment.as_node()) == '<!--hello-->'
}

fn test_standalone_text_node() {
	doc := dom.Document.create(dom.url_about_blank())
	text := doc.create_text_node('x < y & z')
	assert serialize(text.as_node()) == 'x &lt; y &amp; z'
}

fn test_xmlserializer_wrapper() {
	doc := dom.Document.create(dom.url_about_blank())
	div := doc.create_element_ns(xs_html_ns, 'div') or { panic('${err}') }
	serializer := XMLSerializer.construct_impl()
	out := serializer.serialize_to_string(div.as_node()) or { panic('${err}') }
	assert out == '<div xmlns="http://www.w3.org/1999/xhtml"></div>'
}

fn test_require_well_formed_rejects_bad_comment() {
	doc := dom.Document.create(dom.url_about_blank())
	comment := doc.create_comment('a -- b')
	// require_well_formed = .yes rejects "--" in comment data.
	if _ := serialize_node_to_xml_string(comment.as_node(), .yes) {
		assert false, 'expected well-formedness error'
	}
	// The same comment serializes fine when well-formedness is not required.
	assert serialize(comment.as_node()) == '<!--a -- b-->'
}

fn test_xml_well_formed_character_and_name_productions() {
	assert matches_xml_name('valid-name.2')
	assert matches_xml_name('Élément')
	assert !matches_xml_name('2invalid')
	assert !matches_xml_name('has space')
	assert is_valid_xml_public_id('Public ID -()+,./:=?;!*#@$_%')
	assert !is_valid_xml_public_id('tab\tis-not-pubid')

	if _ := xml_serialize_an_attribute_value(some_name('bad\vvalue'), .yes) {
		assert false, 'expected invalid XML character in attribute value to be rejected'
	}
	if _ := xml_serialize_comment('bad\vcomment', .yes) {
		assert false, 'expected invalid XML character in comment to be rejected'
	}
	if _ := xml_serialize_document_type('html', 'bad\tpublic-id', '', .yes) {
		assert false, 'expected invalid XML PubidChar to be rejected'
	}
	if _ := xml_serialize_processing_instruction('target', 'bad\vdata', .yes) {
		assert false, 'expected invalid XML character in processing instruction to be rejected'
	}
	if _ := xml_serialize_cdata_section('bad\vdata', .yes) {
		assert false, 'expected invalid XML character in CDATA to be rejected'
	}
}

// Ladybird's November 1, 2026 XMLSerializer fixes. Exercise the public
// serializer and parse representative results to check namespace/value identity.
fn xml_serializer_parse(source string) !&dom.Document {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.xml)
	parse_xml_document_source(document, source)!
	return document
}

fn test_xml_serializer_keeps_local_namespace_declarations() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut root := document.create_element_ns('urn:a', 'p:root')!
	root.set_attribute_ns_for_bindings(namespace_.xmlns, 'xmlns:p', 'urn:a')!
	root.set_attribute_ns_for_bindings('urn:a', 'p:attr', 'value')!
	markup := serialize(root.as_node())
	assert markup == '<p:root xmlns:p="urn:a" p:attr="value"/>'
	mut parsed := xml_serializer_parse(markup)!
	defer { parsed.finalize() }
	parsed_root := parsed.document_element()?
	assert parsed_root.namespace_uri()? == 'urn:a'
	assert parsed_root.get_attribute_ns('urn:a', 'attr')? == 'value'
}

fn test_xml_serializer_omits_redundant_ancestor_namespace_declaration() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut root := document.create_element_ns(none, 'root')!
	root.set_attribute_ns_for_bindings(namespace_.xmlns, 'xmlns:p', 'urn:a')!
	mut child := document.create_element_ns(none, 'child')!
	child.set_attribute_ns_for_bindings(namespace_.xmlns, 'xmlns:p', 'urn:a')!
	child.set_attribute_ns_for_bindings('urn:a', 'p:attr', 'value')!
	mut root_node := root.as_node()
	root_node.append_child(child.as_node())!
	assert serialize(root_node) == '<root xmlns:p="urn:a"><child p:attr="value"/></root>'
}

fn test_xml_serializer_preserves_xml_space_without_rebinding_xml_namespace() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut root := document.create_element_ns(namespace_.svg, 'svg')!
	root.set_attribute_ns_for_bindings(namespace_.xml, 'xml:space', 'preserve')!
	markup := serialize(root.as_node())
	assert markup == '<svg xmlns="http://www.w3.org/2000/svg" xml:space="preserve"/>'
	mut parsed := xml_serializer_parse(markup)!
	defer { parsed.finalize() }
	assert parsed.document_element()?.get_attribute_ns(namespace_.xml, 'space')? == 'preserve'
}

fn test_xml_serializer_preserves_a_free_attribute_prefix_and_reuses_it() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut root := document.create_element_ns(none, 'root')!
	root.set_attribute_ns_for_bindings('urn:a', 'free:first', '1')!
	root.set_attribute_ns_for_bindings('urn:a', 'second', '2')!
	assert serialize(root.as_node()) == '<root xmlns:free="urn:a" free:first="1" free:second="2"/>'
}

fn test_xml_serializer_uses_the_nearest_declared_prefix_for_attributes_and_end_tags() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut root := document.create_element_ns(none, 'root')!
	root.set_attribute_ns_for_bindings(namespace_.xmlns, 'xmlns:p1', 'urn:a')!
	mut child := document.create_element_ns(none, 'child')!
	child.set_attribute_ns_for_bindings(namespace_.xmlns, 'xmlns:p2', 'urn:a')!
	child.set_attribute_ns_for_bindings('urn:a', 'attr', 'value')!
	mut grandchild := document.create_element_ns('urn:a', 'grandchild')!
	mut grandchild_node := grandchild.as_node()
	grandchild_node.append_child(document.create_text_node('text').as_node())!
	mut child_node := child.as_node()
	child_node.append_child(grandchild_node)!
	mut root_node := root.as_node()
	root_node.append_child(child_node)!
	assert serialize(root_node) == '<root xmlns:p1="urn:a"><child xmlns:p2="urn:a" p2:attr="value"><p2:grandchild>text</p2:grandchild></child></root>'
}

fn test_xml_serializer_does_not_rebind_the_elements_prefix_for_an_attribute() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut root := document.create_element_ns('urn:a', 'p:root')!
	root.set_attribute_ns_for_bindings('urn:b', 'p:attr', 'value')!
	markup := serialize(root.as_node())
	assert markup == '<p:root xmlns:p="urn:a" xmlns:ns1="urn:b" ns1:attr="value"/>'
	mut parsed := xml_serializer_parse(markup)!
	defer { parsed.finalize() }
	parsed_root := parsed.document_element()?
	assert parsed_root.namespace_uri()? == 'urn:a'
	assert parsed_root.get_attribute_ns('urn:b', 'attr')? == 'value'
}

fn test_xml_serializer_generated_prefix_skips_a_preserved_attribute_prefix() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut root := document.create_element_ns(none, 'root')!
	root.set_attribute_ns_for_bindings('urn:a', 'ns1:a', '1')!
	root.set_attribute_ns_for_bindings('urn:b', 'b', '2')!
	assert serialize(root.as_node()) == '<root xmlns:ns1="urn:a" ns1:a="1" xmlns:ns2="urn:b" ns2:b="2"/>'
}

fn test_xml_serializer_generated_prefix_skips_explicit_local_declarations() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut root := document.create_element_ns(none, 'root')!
	root.set_attribute_ns_for_bindings(namespace_.xmlns, 'xmlns:ns1', 'urn:a')!
	root.set_attribute_ns_for_bindings('urn:b', 'attr', 'value')!
	assert serialize(root.as_node()) == '<root xmlns:ns1="urn:a" xmlns:ns2="urn:b" ns2:attr="value"/>'
}

fn test_xml_serializer_does_not_rebind_an_ancestor_prefix_for_a_child_attribute() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut parent := document.create_element_ns(none, 'parent')!
	parent.set_attribute_ns_for_bindings('urn:a', 'p:x', '1')!
	mut child := document.create_element_ns(none, 'child')!
	child.set_attribute_ns_for_bindings('urn:b', 'p:y', '2')!
	child.set_attribute_ns_for_bindings('urn:a', 'c', '3')!
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node())!
	markup := serialize(parent_node)
	assert markup == '<parent xmlns:p="urn:a" p:x="1"><child xmlns:ns1="urn:b" ns1:y="2" p:c="3"/></parent>'
	mut parsed := xml_serializer_parse(markup)!
	defer { parsed.finalize() }
	parsed_child := parsed.document_element()?.as_node().first_child()?.as_element()?
	assert parsed_child.get_attribute_ns('urn:b', 'y')? == '2'
	assert parsed_child.get_attribute_ns('urn:a', 'c')? == '3'
}

fn test_xml_serializer_attribute_whitespace_survives_a_round_trip() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut root := document.create_element_ns(none, 'root')!
	value := 'A\tB\nC\rD "<&> é'
	root.set_attribute_value('value', value)
	markup := serialize(root.as_node())
	assert markup == '<root value="A&#9;B&#xA;C&#xD;D &quot;&lt;&amp;&gt; é"/>'
	mut parsed := xml_serializer_parse(markup)!
	defer { parsed.finalize() }
	assert parsed.document_element()?.get_attribute('value')? == value
}

fn test_xml_serializer_quotes_doctype_ids_with_the_appropriate_delimiter() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	implementation := document.implementation()
	assert serialize(implementation.create_document_type('html', '', 's')!.as_node()) == '<!DOCTYPE html SYSTEM "s">'
	assert serialize(implementation.create_document_type('html', 'p', 's')!.as_node()) == '<!DOCTYPE html PUBLIC "p" "s">'
	assert serialize(implementation.create_document_type('html', "p'", "s'")!.as_node()) == '<!DOCTYPE html PUBLIC "p\'" "s\'">'
	assert serialize(implementation.create_document_type('html', 'p"', 's"')!.as_node()) == '<!DOCTYPE html PUBLIC \'p"\' \'s"\'>'

	// A system identifier containing a quotation mark remains parseable and
	// retains literal ampersands: doctype IDs do not use attribute escaping.
	doctype := implementation.create_document_type('root', '', 'a"&b')!
	markup := serialize_node_to_xml_string(doctype.as_node(), .yes)!
	mut parsed := xml_serializer_parse('${markup}<root/>')!
	defer { parsed.finalize() }
	assert parsed.doctype()?.system_id() == 'a"&b'
	if _ := xml_serialize_document_type('root', '', 'both"\'quotes', .yes) {
		assert false, 'well-formed system IDs cannot contain both quote delimiters'
	}
}
