// Copyright (c) 2021, Luke Wilde <lukew@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of DOMParser.{h,cpp}. Parsing delegates to HTMLParser or the
// namespace-aware DOM adapter for vlib encoding.xml.
module html

import dom

const xml_namespace_uri = 'http://www.w3.org/XML/1998/namespace'
const xmlns_namespace_uri = 'http://www.w3.org/2000/xmlns/'
const parser_error_namespace_uri = 'http://www.mozilla.org/newlayout/xml/parsererror.xml'

pub enum DOMParserSupportedType {
	text_html
	text_xml
	application_xml
	application_xhtml_xml
	image_svg_xml
}

pub fn (type_ DOMParserSupportedType) content_type() string {
	return match type_ {
		.text_html { 'text/html' }
		.text_xml { 'text/xml' }
		.application_xml { 'application/xml' }
		.application_xhtml_xml { 'application/xhtml+xml' }
		.image_svg_xml { 'image/svg+xml' }
	}
}

@[heap]
pub struct DOMParser {
pub:
	associated_document &dom.Document
}

pub fn DOMParser.create(associated_document &dom.Document) &DOMParser {
	return &DOMParser{
		associated_document: associated_document
	}
}

pub fn DOMParser.construct_impl(associated_document &dom.Document) !&DOMParser {
	return DOMParser.create(associated_document)
}

fn xml_fragment_escape_attribute(value string) string {
	return value.replace('&', '&amp;').replace('"', '&quot;').replace('<', '&lt;')
}

fn xml_fragment_qualified_name(element &dom.Element) string {
	if prefix := element.prefix() {
		if prefix != '' {
			return '${prefix}:${element.local_name()}'
		}
	}
	return element.local_name()
}

// https://html.spec.whatwg.org/multipage/xhtml.html#parsing-xhtml-fragments
// XMLFragmentParser and DOM's fragment-parsing hook share this implementation.
pub fn parse_xml_fragment_with_options(context &dom.Element, input string, allow_declarative_shadow_roots bool) ![]&dom.Node {
	name := xml_fragment_qualified_name(context)
	mut feed := '<${name}'
	for prefix in context.as_node().get_in_scope_prefixes() {
		if prefix == '' || prefix == 'xmlns' {
			continue
		}
		if namespace_ := context.as_node().lookup_namespace_uri(prefix) {
			if namespace_ != '' {
				feed += ' xmlns:${prefix}="${xml_fragment_escape_attribute(namespace_)}"'
			}
		}
	}
	if default_namespace := context.as_node().locate_a_namespace(none) {
		if default_namespace != '' {
			feed += ' xmlns="${xml_fragment_escape_attribute(default_namespace)}"'
		}
	}
	feed += '>${input}</${name}>'

	mut temporary_document := dom.Document.create(dom.url_about_blank())
	temporary_document.set_document_type(.xml)
	temporary_document.set_allow_declarative_shadow_roots(allow_declarative_shadow_roots)
	parse_xml_document_source(temporary_document, feed) or {
		return error('SyntaxError: ${err}')
	}
	wrapper := temporary_document.document_element() or {
		return error('SyntaxError: XML fragment has no document element')
	}
	if wrapper.as_node().previous_sibling() != none || wrapper.as_node().next_sibling() != none {
		return error('SyntaxError: Document element has sibling nodes')
	}
	return wrapper.as_node().children_as_vector()
}

pub fn (parser &DOMParser) parse_from_string(input string, type_ DOMParserSupportedType) !&dom.Document {
	compliant_string := parser.associated_document.trusted_types_compliant_html(input,
		'dom-parser-parse-from-string')!
	mut document := dom.Document.create(dom.URL{ value: parser.associated_document.url_string() })
	install_document_fragment_parsing_hook(document)
	document.set_content_type(type_.content_type())
	if type_ == .text_html {
		document.set_document_type(.html)
		mut html_parser := HTMLParser.create(document, compliant_string)
		html_parser.run()
	} else {
		document.set_document_type(.xml)
		parse_xml_document_source(document, compliant_string) or {
			mut document_node := unsafe { &dom.Node(document) }
			document_node.remove_all_children(true)
			parser_error := document.create_element_ns(parser_error_namespace_uri, 'parsererror')!
			document_node.append_child(parser_error.as_node())!
		}
	}
	document.set_origin(parser.associated_document.origin())
	return document
}
