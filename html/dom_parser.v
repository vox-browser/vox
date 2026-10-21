// Copyright (c) 2021, Luke Wilde <lukew@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of DOMParser.{h,cpp}. HTML parsing delegates to HTMLParser and XML parsing implements the XML
// document-builder path used by DOMParser.
module html

import dom
import strconv

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

struct XMLAttributeToken {
	name  string
	value string
}

struct SimpleXMLDocumentParser {
	source   string
	document &dom.Document
mut:
	position int
}

fn xml_is_space(byte u8) bool {
	return byte in [` `, `\t`, `\n`, `\r`]
}

fn xml_is_name_start(byte u8) bool {
	return byte == `:` || byte == `_` || (byte >= `A` && byte <= `Z`) || (byte >= `a` && byte <= `z`) || byte >= 0x80
}

fn xml_is_name_character(byte u8) bool {
	return xml_is_name_start(byte) || (byte >= `0` && byte <= `9`) || byte in [`-`, `.`]
}

fn (mut parser SimpleXMLDocumentParser) skip_space() {
	for parser.position < parser.source.len && xml_is_space(parser.source[parser.position]) {
		parser.position++
	}
}

fn (parser &SimpleXMLDocumentParser) starts_with(value string) bool {
	if parser.position + value.len > parser.source.len { return false }
	for index, byte in value {
		if parser.source[parser.position + index] != byte { return false }
	}
	return true
}

fn (mut parser SimpleXMLDocumentParser) consume(value string) ! {
	if !parser.starts_with(value) {
		return error("expected '${value}' at byte ${parser.position}")
	}
	parser.position += value.len
}

fn (mut parser SimpleXMLDocumentParser) parse_name() !string {
	if parser.position >= parser.source.len || !xml_is_name_start(parser.source[parser.position]) {
		return error('expected an XML name at byte ${parser.position}')
	}
	start := parser.position
	parser.position++
	for parser.position < parser.source.len && xml_is_name_character(parser.source[parser.position]) {
		parser.position++
	}
	name := parser.source[start..parser.position]
	if name.count(':') > 1 || name.starts_with(':') || name.ends_with(':') {
		return error('invalid qualified XML name ${name}')
	}
	return name
}

fn xml_decode_references(value string) !string {
	// The parser already owns the substring for this token. Most SVG/XML
	// attributes and text have no references and need no second byte buffer.
	if !value.contains('&') { return value }
	mut output := []u8{cap: value.len}
	mut position := 0
	for position < value.len {
		if value[position] != `&` {
			start := position
			for position < value.len && value[position] != `&` {
				position++
			}
			output << value[start..position].bytes()
			continue
		}
		semicolon := value.index_after(';', position + 1) or {
			return error('unterminated XML entity reference')
		}
		entity := value[position + 1..semicolon]
		decoded := match entity {
			'amp' {
				'&'
			}
			'lt' {
				'<'
			}
			'gt' {
				'>'
			}
			'quot' {
				'"'
			}
			'apos' {
				"'"
			}
			else {
				if entity.len > 0 && entity[0] == `#` {
					is_hexadecimal := entity.len > 1 && entity[1] in [`x`, `X`]
					digits := if is_hexadecimal { entity[2..] } else { entity[1..] }
					radix := if is_hexadecimal { 16 } else { 10 }
					code_point := u32(strconv.parse_uint(digits, radix, 32) or {
						kind := if is_hexadecimal { 'hexadecimal' } else { 'decimal' }
						return error('invalid ${kind} character reference &${entity};')
					})
					if code_point == 0 || code_point > 0x10ffff || (code_point >= 0xd800 && code_point <= 0xdfff) {
						return error('invalid XML character reference')
					}
					rune(code_point).str()
				} else {
					resolved := resolve_named_character_reference(entity) or {
						return error('unknown XML entity &${entity};')
					}
					resolved
				}
			}
		}
		output << decoded.bytes()
		position = semicolon + 1
	}
	return output.bytestr()
}

fn (mut parser SimpleXMLDocumentParser) parse_quoted_value() !string {
	if parser.position >= parser.source.len || parser.source[parser.position] !in [`'`, `"`] {
		return error('expected a quoted XML attribute value')
	}
	quote := parser.source[parser.position]
	parser.position++
	start := parser.position
	for parser.position < parser.source.len && parser.source[parser.position] != quote {
		if parser.source[parser.position] == `<` {
			return error('XML attribute values may not contain <')
		}
		parser.position++
	}
	if parser.position >= parser.source.len {
		return error('unterminated XML attribute value')
	}
	value := xml_decode_references(parser.source[start..parser.position])!
	parser.position++
	return value
}

fn (mut parser SimpleXMLDocumentParser) parse_comment(parent &dom.Node) ! {
	parser.consume('<!--')!
	end := parser.source.index_after('-->', parser.position) or {
		return error('unterminated XML comment')
	}
	data := parser.source[parser.position..end]
	if data.contains('--') || data.ends_with('-') {
		return error('invalid XML comment')
	}
	comment := parser.document.create_comment(data)
	mut mutable_parent := unsafe { &dom.Node(parent) }
	mutable_parent.append_child(unsafe { &dom.Node(comment) })!
	parser.position = end + 3
}

fn (mut parser SimpleXMLDocumentParser) parse_processing_instruction(parent &dom.Node) ! {
	parser.consume('<?')!
	target := parser.parse_name()!
	if target.to_lower() == 'xml' {
		return error('XML declaration is only permitted at the beginning of the document')
	}
	end := parser.source.index_after('?>', parser.position) or {
		return error('unterminated XML processing instruction')
	}
	data := parser.source[parser.position..end].trim_space()
	instruction := parser.document.create_processing_instruction(target, data)!
	mut mutable_parent := unsafe { &dom.Node(parent) }
	mutable_parent.append_child(unsafe { &dom.Node(instruction) })!
	parser.position = end + 2
}

fn (mut parser SimpleXMLDocumentParser) skip_doctype() ! {
	parser.consume('<!DOCTYPE')!
	mut quote := u8(0)
	mut subset_depth := 0
	for parser.position < parser.source.len {
		byte := parser.source[parser.position]
		if quote != 0 {
			if byte == quote {
				quote = 0
			}
		} else if byte in [`'`, `"`] {
			quote = byte
		} else if byte == `[` {
			subset_depth++
		} else if byte == `]` && subset_depth > 0 {
			subset_depth--
		} else if byte == `>` && subset_depth == 0 {
			parser.position++
			return
		}
		parser.position++
	}
	return error('unterminated XML doctype')
}

fn xml_qualified_name_parts(name string) (string, string) {
	if colon := name.index(':') {
		return name[..colon], name[colon + 1..]
	}
	return '', name
}

fn (mut parser SimpleXMLDocumentParser) parse_element(parent &dom.Node, inherited_namespaces map[string]string) ! {
	parser.consume('<')!
	qualified_name := parser.parse_name()!
	mut attributes := []XMLAttributeToken{}
	mut attribute_names := ?map[string]bool(none)
	mut namespaces := unsafe { inherited_namespaces }
	mut owns_namespaces := false
	mut self_closing := false
	for {
		parser.skip_space()
		if parser.starts_with('/>') {
			parser.position += 2
			self_closing = true
			break
		}
		if parser.starts_with('>') {
			parser.position++
			break
		}
		name := parser.parse_name()!
		// Most SVG elements have only a handful of attributes. Their token list
		// is already a duplicate-name index; large elements use a hash table.
		if attributes.len < 16 {
			for attribute in attributes {
				if attribute.name == name { return error('duplicate XML attribute ${name}') }
			}
		} else {
			mut names := unsafe { attribute_names or { map[string]bool{} } }
			if names.len == 0 {
				for attribute in attributes { names[attribute.name] = true }
			}
			if names[name] { return error('duplicate XML attribute ${name}') }
			names[name] = true
			attribute_names = unsafe { names }
		}
		parser.skip_space()
		parser.consume('=')!
		parser.skip_space()
		value := parser.parse_quoted_value()!
		attributes << XMLAttributeToken{name, value}
		if name == 'xmlns' || name.starts_with('xmlns:') {
			if !owns_namespaces {
				namespaces = inherited_namespaces.clone()
				owns_namespaces = true
			}
		}
		if name == 'xmlns' {
			namespaces[''] = value
		} else if name.starts_with('xmlns:') {
			namespaces[name.all_after(':')] = value
		}
	}
	prefix, _ := xml_qualified_name_parts(qualified_name)
	namespace_ := if prefix == 'xml' {
		xml_namespace_uri
	} else if prefix != '' {
		namespaces[prefix] or { return error('unbound XML namespace prefix ${prefix}') }
	} else {
		namespaces[''] or { '' }
	}
	mut element := if namespace_ == '' {
		parser.document.create_element_ns(none, qualified_name)!
	} else {
		parser.document.create_element_ns(namespace_, qualified_name)!
	}
	for attribute in attributes {
		attribute_prefix, _ := xml_qualified_name_parts(attribute.name)
		attribute_namespace := if attribute.name == 'xmlns' || attribute_prefix == 'xmlns' {
			xmlns_namespace_uri
		} else if attribute_prefix == 'xml' {
			xml_namespace_uri
		} else if attribute_prefix != '' {
			namespaces[attribute_prefix] or {
				return error('unbound XML namespace prefix ${attribute_prefix}')
			}
		} else {
			''
		}
		if attribute_namespace == '' {
			element.set_attribute_ns_for_bindings(none, attribute.name, attribute.value)!
		} else {
			element.set_attribute_ns_for_bindings(attribute_namespace, attribute.name,
				attribute.value)!
		}
	}
	mut mutable_parent := unsafe { &dom.Node(parent) }
	mutable_parent.append_child(element.as_node())!
	if self_closing {
		return
	}
	mut element_node := element.as_node()
	for {
		if parser.position >= parser.source.len {
			return error('unterminated XML element ${qualified_name}')
		}
		if parser.starts_with('</') {
			parser.position += 2
			closing_name := parser.parse_name()!
			parser.skip_space()
			parser.consume('>')!
			if closing_name != qualified_name {
				return error('mismatched XML closing tag ${closing_name}')
			}
			return
		}
		if parser.starts_with('<!--') {
			parser.parse_comment(element_node)!
			continue
		}
		if parser.starts_with('<![CDATA[') {
			parser.position += 9
			end := parser.source.index_after(']]>', parser.position) or {
				return error('unterminated CDATA section')
			}
			cdata := parser.document.create_cdata_section(parser.source[parser.position..end])!
			element_node.append_child(unsafe { &dom.Node(cdata) })!
			parser.position = end + 3
			continue
		}
		if parser.starts_with('<?') {
			parser.parse_processing_instruction(element_node)!
			continue
		}
		if parser.starts_with('<') {
			parser.parse_element(element_node, namespaces)!
			continue
		}
		start := parser.position
		for parser.position < parser.source.len && parser.source[parser.position] != `<` {
			parser.position++
		}
		text := xml_decode_references(parser.source[start..parser.position])!
		if text.len > 0 {
			text_node := parser.document.create_text_node(text)
			element_node.append_child(unsafe { &dom.Node(text_node) })!
		}
	}
}

fn (mut parser SimpleXMLDocumentParser) parse_document() ! {
	if parser.source.starts_with('﻿') {
		parser.position = 3
	}
	parser.skip_space()
	if parser.starts_with('<?xml') {
		end := parser.source.index_after('?>', parser.position + 5) or {
			return error('unterminated XML declaration')
		}
		parser.position = end + 2
	}
	mut saw_doctype := false
	for {
		parser.skip_space()
		if parser.starts_with('<!--') {
			parser.parse_comment(unsafe { &dom.Node(parser.document) })!
		} else if parser.starts_with('<?') {
			parser.parse_processing_instruction(unsafe { &dom.Node(parser.document) })!
		} else if parser.starts_with('<!DOCTYPE') && !saw_doctype {
			parser.skip_doctype()!
			saw_doctype = true
		} else {
			break
		}
	}
	parser.skip_space()
	if !parser.starts_with('<') || parser.starts_with('</') || parser.starts_with('<!') || parser.starts_with('<?') {
		return error('XML document has no document element')
	}
	mut initial_namespaces := map[string]string{}
	initial_namespaces['xml'] = xml_namespace_uri
	parser.parse_element(unsafe { &dom.Node(parser.document) }, initial_namespaces)!
	for {
		parser.skip_space()
		if parser.starts_with('<!--') {
			parser.parse_comment(unsafe { &dom.Node(parser.document) })!
		} else if parser.starts_with('<?') {
			parser.parse_processing_instruction(unsafe { &dom.Node(parser.document) })!
		} else {
			break
		}
	}
	parser.skip_space()
	if parser.position != parser.source.len {
		return error('content after the XML document element')
	}
}

// XMLDocumentBuilder and XMLFragmentParser use the same tokenizer/tree-builder
// as DOMParser. Keeping this entry point here avoids maintaining two subtly
// different XML grammars while the translated modules remain acyclic.
pub fn parse_xml_document_source(document &dom.Document, source string) ! {
	mut xml_parser := SimpleXMLDocumentParser{
		source: source
		document: document
	}
	xml_parser.parse_document()!
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
