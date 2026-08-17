// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of XML/XMLDocumentBuilder.{h,cpp}.
module xml

import dom
import html

pub enum ScriptingSupport {
	disabled
	enabled
}

// LibXML asks the document builder to resolve named HTML references which are
// outside XML's five predefined entities. Delegate to the complete generated
// table used by the HTML tokenizer.
pub fn resolve_named_html_entity(name string) ?string {
	return html.resolve_named_character_reference(name)
}

@[heap]
pub struct DocumentBuilder {
pub:
	document          &dom.Document
	scripting_support ScriptingSupport
pub mut:
	has_error bool
	source    string
}

struct ParsedDoctype {
	found     bool
	name      string
	public_id string
	system_id string
}

fn skip_xml_space(source string, position int) int {
	mut next := position
	for next < source.len && source[next] in [` `, `\t`, `\n`, `\r`] {
		next++
	}
	return next
}

fn parse_quoted_doctype_literal(source string, position int) !(string, int) {
	if position >= source.len || source[position] !in [`'`, `"`] {
		return error('expected a quoted XML doctype identifier')
	}
	quote := source[position]
	mut next := position + 1
	start := next
	for next < source.len && source[next] != quote {
		next++
	}
	if next >= source.len {
		return error('unterminated XML doctype identifier')
	}
	return source[start..next], next + 1
}

fn parse_document_doctype(source string) !ParsedDoctype {
	mut position := if source.starts_with('\xef\xbb\xbf') { 3 } else { 0 }
	for {
		position = skip_xml_space(source, position)
		if position + 4 <= source.len && source[position..position + 4] == '<!--' {
			end := source.index_after('-->', position + 4) or {
				return error('unterminated XML comment')
			}
			position = end + 3
			continue
		}
		if position + 2 <= source.len && source[position..position + 2] == '<?' {
			end := source.index_after('?>', position + 2) or {
				return error('unterminated XML processing instruction')
			}
			position = end + 2
			continue
		}
		break
	}
	if position + '<!DOCTYPE'.len > source.len
		|| source[position..position + '<!DOCTYPE'.len] != '<!DOCTYPE' {
		return ParsedDoctype{}
	}
	position += '<!DOCTYPE'.len
	if position >= source.len || source[position] !in [` `, `\t`, `\n`, `\r`] {
		return error('XML doctype name must be preceded by whitespace')
	}
	position = skip_xml_space(source, position)
	name_start := position
	for position < source.len && source[position] !in [` `, `\t`, `\n`, `\r`, `>`, `[`] {
		position++
	}
	if position == name_start {
		return error('XML doctype has no name')
	}
	name := source[name_start..position]
	position = skip_xml_space(source, position)
	mut public_id := ''
	mut system_id := ''
	if position + 'SYSTEM'.len <= source.len
		&& source[position..position + 'SYSTEM'.len] == 'SYSTEM' {
		position += 'SYSTEM'.len
		if position >= source.len || source[position] !in [` `, `\t`, `\n`, `\r`] {
			return error('SYSTEM identifier must be preceded by whitespace')
		}
		position = skip_xml_space(source, position)
		system_id, position = parse_quoted_doctype_literal(source, position)!
	} else if position + 'PUBLIC'.len <= source.len
		&& source[position..position + 'PUBLIC'.len] == 'PUBLIC' {
		position += 'PUBLIC'.len
		if position >= source.len || source[position] !in [` `, `\t`, `\n`, `\r`] {
			return error('PUBLIC identifier must be preceded by whitespace')
		}
		position = skip_xml_space(source, position)
		public_id, position = parse_quoted_doctype_literal(source, position)!
		position = skip_xml_space(source, position)
		system_id, position = parse_quoted_doctype_literal(source, position)!
	}
	return ParsedDoctype{
		found:     true
		name:      name
		public_id: public_id
		system_id: system_id
	}
}

pub fn DocumentBuilder.create(document &dom.Document, scripting_support ScriptingSupport) &DocumentBuilder {
	return &DocumentBuilder{
		document:          document
		scripting_support: scripting_support
	}
}

pub fn (mut builder DocumentBuilder) set_source(source string) ! {
	builder.source = source
	mut document := builder.document
	document.set_source(source)
}

// parse_with_listener is the V boundary corresponding to LibXML's listener
// callbacks. It retains the upstream builder's source/readiness behavior and
// builds namespace-aware DOM nodes through LibWeb's shared XML tokenizer.
pub fn (mut builder DocumentBuilder) parse_with_listener() ! {
	mut document := builder.document
	document.set_document_type(.xml)
	document.update_readiness(.loading)
	doctype := parse_document_doctype(builder.source) or {
		builder.has_error = true
		return err
	}
	if doctype.found && document.doctype() == none {
		mut document_type := dom.DocumentType.create(document)
		document_type.set_name(doctype.name)
		document_type.set_public_id(doctype.public_id)
		document_type.set_system_id(doctype.system_id)
		mut document_node := unsafe { &dom.Node(document) }
		document_node.append_child(document_type.as_node()) or {
			builder.has_error = true
			return err
		}
	}
	html.parse_xml_document_source(document, builder.source) or {
		builder.has_error = true
		return err
	}
	document.update_readiness(.interactive)
	document.update_readiness(.complete)
}

pub fn build_document(source string, url dom.URL, scripting_support ScriptingSupport) !&dom.Document {
	mut document := dom.Document.create(url)
	mut builder := DocumentBuilder.create(document, scripting_support)
	builder.set_source(source)!
	builder.parse_with_listener()!
	return document
}
