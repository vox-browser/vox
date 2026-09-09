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
pub struct XMLDocumentBuilder {
pub:
	document          &dom.Document
	scripting_support ScriptingSupport
mut:
	has_error_     bool
	source         string
	current_node   &dom.Node
	namespace_stack []XMLNamespaceStackEntry
}

pub type DocumentBuilder = XMLDocumentBuilder

pub struct XMLExternalID {
pub:
	system_id string
	public_id ?string
}

pub struct XMLDoctype {
pub:
	type_       string
	external_id ?XMLExternalID
}

struct XMLNamespaceAndPrefix {
	namespace_ string
	prefix     ?string
}

struct XMLNamespaceStackEntry {
mut:
	namespaces []XMLNamespaceAndPrefix
	depth      int
}

fn xml_prefixes_equal(left ?string, right ?string) bool {
	if left_value := left {
		if right_value := right {
			return left_value == right_value
		}
		return false
	}
	if _ := right {
		return false
	}
	return true
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

pub fn XMLDocumentBuilder.create(document &dom.Document, scripting_support ScriptingSupport) &XMLDocumentBuilder {
	return &XMLDocumentBuilder{
		document:          document
		scripting_support: scripting_support
		current_node:      unsafe { &dom.Node(document) }
		namespace_stack:   [XMLNamespaceStackEntry{
			depth: 1
		}]
	}
}

pub fn (builder &XMLDocumentBuilder) has_error() bool {
	return builder.has_error_
}

pub fn (mut builder XMLDocumentBuilder) set_source(source string) ! {
	builder.source = source
	mut document := builder.document
	document.set_source(source)
}

pub fn (mut builder XMLDocumentBuilder) set_doctype(doctype XMLDoctype) {
	if builder.document.doctype() != none {
		return
	}
	mut document_type := dom.DocumentType.create(builder.document)
	document_type.set_name(doctype.type_)
	if external_id := doctype.external_id {
		document_type.set_system_id(external_id.system_id)
		if public_id := external_id.public_id {
			document_type.set_public_id(public_id)
		}
	}
	mut document_node := unsafe { &dom.Node(builder.document) }
	document_node.insert_before(document_type.as_node(), document_node.first_child(), false)
}

pub fn (builder &XMLDocumentBuilder) namespace_for_name(name string) ?string {
	parts := name.split(':')
	if parts.len > 2 || (parts.len == 2 && (parts[0] == '' || parts[1] == '')) {
		return none
	}
	prefix := if parts.len == 2 { ?string(parts[0]) } else { none }
	for index := builder.namespace_stack.len - 1; index >= 0; index-- {
		for entry in builder.namespace_stack[index].namespaces {
			if xml_prefixes_equal(entry.prefix, prefix) {
				return entry.namespace_
			}
		}
	}
	return none
}

pub fn (mut builder XMLDocumentBuilder) element_start(name string, attributes map[string]string) {
	if builder.has_error_ {
		return
	}
	mut namespaces := []XMLNamespaceAndPrefix{}
	for attribute_name, value in attributes {
		if attribute_name == 'xmlns' || attribute_name.starts_with('xmlns:') {
			parts := attribute_name.split_nth(':', 2)
			prefix := if parts.len == 2 { ?string(parts[1]) } else { none }
			if namespaces.any(xml_prefixes_equal(it.prefix, prefix)) {
				continue
			}
			namespaces << XMLNamespaceAndPrefix{
				namespace_: value
				prefix:     prefix
			}
		}
	}
	if namespaces.len > 0 {
		builder.namespace_stack << XMLNamespaceStackEntry{
			namespaces: namespaces
			depth:      1
		}
	} else {
		builder.namespace_stack[builder.namespace_stack.len - 1].depth++
	}

	mut element := builder.document.create_element_ns(builder.namespace_for_name(name), name) or {
		builder.has_error_ = true
		return
	}
	if builder.current_node == unsafe { nil } {
		builder.has_error_ = true
		return
	}
	mut current_node := unsafe { &dom.Node(builder.current_node) }
	current_node.append_child(element.as_node()) or {
		builder.has_error_ = true
		return
	}
	for attribute_name, value in attributes {
		if attribute_name == 'xmlns' || attribute_name.starts_with('xmlns:') {
			element.set_attribute_ns_for_bindings('http://www.w3.org/2000/xmlns/', attribute_name,
				value) or { builder.has_error_ = true }
		} else if attribute_name.contains(':') {
			mut namespace_ := builder.namespace_for_name(attribute_name)
			if attribute_name.starts_with('xml:') {
				namespace_ = 'http://www.w3.org/XML/1998/namespace'
			}
			if namespace_ == none {
				builder.has_error_ = true
				continue
			}
			element.set_attribute_ns_for_bindings(namespace_, attribute_name, value) or {
				builder.has_error_ = true
			}
		} else {
			element.set_attribute_value(attribute_name, value)
		}
	}
	builder.current_node = element.as_node()
}

pub fn (mut builder XMLDocumentBuilder) element_end(name string) {
	if builder.has_error_ || builder.current_node == unsafe { nil } {
		return
	}
	last_index := builder.namespace_stack.len - 1
	builder.namespace_stack[last_index].depth--
	if builder.namespace_stack[last_index].depth == 0 {
		builder.namespace_stack.delete(last_index)
	}
	if builder.current_node.node_name().to_lower() != name.to_lower() {
		builder.has_error_ = true
		return
	}
	builder.current_node = builder.current_node.parent_node() or { unsafe { nil } }
}

pub fn (mut builder XMLDocumentBuilder) text(data string) {
	if builder.has_error_ || builder.current_node == unsafe { nil } || data == '' {
		return
	}
	if last_child := builder.current_node.last_child() {
		if last_child.is_exclusive_text() {
			mut text_node := unsafe { &dom.Text(last_child) }
			text_node.append_data(data) or { builder.has_error_ = true }
			return
		}
	}
	mut current_node := unsafe { &dom.Node(builder.current_node) }
	current_node.append_child(builder.document.create_text_node(data).as_node()) or {
		builder.has_error_ = true
	}
}

pub fn (mut builder XMLDocumentBuilder) comment(data string) {
	if builder.has_error_ || builder.current_node == unsafe { nil } {
		return
	}
	mut current_node := unsafe { &dom.Node(builder.current_node) }
	current_node.append_child(builder.document.create_comment(data).as_node()) or {
		builder.has_error_ = true
	}
}

pub fn (mut builder XMLDocumentBuilder) cdata_section(data string) {
	if builder.has_error_ || builder.current_node == unsafe { nil } {
		return
	}
	section := builder.document.create_cdata_section(data) or {
		builder.has_error_ = true
		return
	}
	mut current_node := unsafe { &dom.Node(builder.current_node) }
	current_node.append_child(section.as_node()) or { builder.has_error_ = true }
}

pub fn (mut builder XMLDocumentBuilder) processing_instruction(target string, data string) {
	if builder.has_error_ || builder.current_node == unsafe { nil } {
		return
	}
	instruction := builder.document.create_processing_instruction(target, data) or {
		builder.has_error_ = true
		return
	}
	mut current_node := unsafe { &dom.Node(builder.current_node) }
	current_node.append_child(instruction.as_node()) or { builder.has_error_ = true }
}

pub fn (mut builder XMLDocumentBuilder) document_end() {
	builder.current_node = unsafe { nil }
	builder.namespace_stack.clear()
	mut document := builder.document
	document.update_readiness(.interactive)

	// Documents parsed by DOMParser and decoded SVG images have no browsing
	// lifecycle to wait for.
	if document.get_browsing_context() == none || document.is_decoded_svg() {
		document.update_readiness(.complete)
		return
	}

	// Deferred parser-inserted scripts execute in document order once both the
	// script and its blocking style sheets are ready.
	scripts := document.take_scripts_to_execute_when_parsing_has_finished()
	for index, script in scripts {
		mut event_loop := html.main_thread_event_loop()
		event_loop.spin_until(fn [document, script] () bool {
			return html.html_script_element_is_ready_to_be_parser_executed(script)
				&& !document.has_a_style_sheet_that_is_blocking_scripts()
		})
		if !html.html_script_element_is_ready_to_be_parser_executed(script)
			|| document.has_a_style_sheet_that_is_blocking_scripts() {
			// A browser host keeps spinning here. Preserve the unexecuted tail so
			// the standalone embedding can resume document_end after host work.
			for pending_script in scripts[index..] {
				document.add_script_to_execute_when_parsing_has_finished(pending_script)
			}
			return
		}
		html.html_script_element_parser_execute_ready_script(script)
	}

	html.queue_a_task(.dom_manipulation, html.main_thread_event_loop(), document, fn [document] () {
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.mark_dom_content_loaded_event_start()
		mutable_document.dispatch_event_simple('DOMContentLoaded', true)
		mutable_document.mark_dom_content_loaded_event_end()
	})

	mut event_loop := html.main_thread_event_loop()
	event_loop.spin_until(fn [document] () bool {
		return !document.has_scripts_to_execute_as_soon_as_possible()
	})
	if document.has_scripts_to_execute_as_soon_as_possible() {
		return
	}
	event_loop.spin_until(fn [document] () bool {
		return !document.anything_is_delaying_the_load_event()
	})
	if document.anything_is_delaying_the_load_event() {
		return
	}

	html.queue_a_task(.dom_manipulation, html.main_thread_event_loop(), document, fn [document] () {
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.update_readiness(.complete)
		window := document.get_window() or { return }
		mutable_document.mark_load_event_start()
		window.dispatch_event_simple('load', false)
		mutable_document.mark_load_event_end()
		if !document.document_page_showing() {
			mutable_document.set_page_showing(true)
		}
		window.fire_a_page_transition_event('pageshow', false)
		mutable_document.completely_finish_loading()
	})

	document.set_ready_for_post_load_tasks(true)
}

// parse_with_listener is the V boundary corresponding to LibXML's listener
// callbacks. It retains the upstream builder's source/readiness behavior and
// builds namespace-aware DOM nodes through LibWeb's shared XML tokenizer.
pub fn (mut builder XMLDocumentBuilder) parse_with_listener() ! {
	mut document := builder.document
	document.set_document_type(.xml)
	document.update_readiness(.loading)
	doctype := parse_document_doctype(builder.source) or {
		builder.has_error_ = true
		return err
	}
	if doctype.found && document.doctype() == none {
		mut document_type := dom.DocumentType.create(document)
		document_type.set_name(doctype.name)
		document_type.set_public_id(doctype.public_id)
		document_type.set_system_id(doctype.system_id)
		mut document_node := unsafe { &dom.Node(document) }
		document_node.append_child(document_type.as_node()) or {
			builder.has_error_ = true
			return err
		}
	}
	html.parse_xml_document_source(document, builder.source) or {
		builder.has_error_ = true
		return err
	}
	builder.document_end()
}

pub fn build_document(source string, url dom.URL, scripting_support ScriptingSupport) !&dom.Document {
	mut document := dom.Document.create(url)
	mut builder := XMLDocumentBuilder.create(document, scripting_support)
	builder.set_source(source)!
	builder.parse_with_listener()!
	return document
}
