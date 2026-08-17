// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of XML/XMLFragmentParser.{h,cpp}.
module xml

import dom
import html

fn escape_attribute(value string) string {
	return value.replace('&', '&amp;').replace('"', '&quot;').replace('<', '&lt;')
}

fn qualified_name(element &dom.Element) string {
	if prefix := element.prefix() {
		if prefix != '' {
			return '${prefix}:${element.local_name()}'
		}
	}
	return element.local_name()
}

// Implements the XHTML fragment algorithm by wrapping the input in the
// context element with every in-scope namespace, parsing a temporary XML
// document, then cloning the wrapper's children into the context document.
pub fn parse_fragment(context &dom.Element, input string, allow_declarative_shadow_roots bool) ![]&dom.Node {
	name := qualified_name(context)
	mut feed := '<${name}'
	for prefix in context.as_node().get_in_scope_prefixes() {
		if prefix == '' || prefix == 'xmlns' {
			continue
		}
		if namespace_ := context.as_node().lookup_namespace_uri(prefix) {
			if namespace_ != '' {
				feed += ' xmlns:${prefix}="${escape_attribute(namespace_)}"'
			}
		}
	}
	if default_namespace := context.as_node().locate_a_namespace(none) {
		if default_namespace != '' {
			feed += ' xmlns="${escape_attribute(default_namespace)}"'
		}
	}
	feed += '>${input}</${name}>'

	mut temporary_document := dom.Document.create(dom.url_about_blank())
	temporary_document.set_document_type(.xml)
	temporary_document.set_allow_declarative_shadow_roots(allow_declarative_shadow_roots)
	html.parse_xml_document_source(temporary_document, feed) or {
		return error('SyntaxError: ${err}')
	}
	wrapper := temporary_document.document_element() or {
		return error('SyntaxError: XML fragment has no document element')
	}
	if wrapper.as_node().previous_sibling() != none || wrapper.as_node().next_sibling() != none {
		return error('SyntaxError: Document element has sibling nodes')
	}
	mut result := []&dom.Node{}
	for child in wrapper.as_node().children_as_vector() {
		result << child
	}
	return result
}
