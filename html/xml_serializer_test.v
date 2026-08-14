module html

import dom

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
