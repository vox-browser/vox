// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

module html

import dom
import encoding.xml as vxml
import platform
import xmlcompat

// The prealloc parser tree lives in scratch. DOM fields retain string buffers,
// so publish a copy in the caller's restored owner before scratch is retired.
@[inline]
fn xml_dom_owned_string(value string) string {
	$if prealloc {
		return value.clone()
	}
	return value
}

struct XMLPublishedStrings {
mut:
	short_text [16]string
	element_names [2]string
	attribute_name string
}

// Reuse small immediate text values, including repeated indentation. DOM
// mutations replace the value, so nodes can share these document-owned bytes.
fn (mut copies XMLPublishedStrings) owned_text(value string) string {
	$if prealloc {
		if value.len > 0 && value.len <= 32 {
			index := (value.len * 3 + int(value[0]) * 31 + int(value[value.len - 1])
				+ int(value[value.len / 2]) * 7) & 15
			previous := copies.short_text[index]
			if previous == value {
				return previous
			}
			owned := value.clone()
			copies.short_text[index] = owned
			return owned
		}
	}
	return xml_dom_owned_string(value)
}

// Repeated names have immutable, document-owned bytes after leaving scratch.
@[inline]
fn (mut copies XMLPublishedStrings) owned_element_name(value string) string {
	$if prealloc {
		if copies.element_names[0] == value {
			return copies.element_names[0]
		}
		if copies.element_names[1] == value {
			return copies.element_names[1]
		}
		owned := value.clone()
		copies.element_names[1] = copies.element_names[0]
		copies.element_names[0] = owned
		return owned
	}
	return value
}

fn (mut copies XMLPublishedStrings) owned_attribute_name(value string) string {
	$if prealloc {
		if value != copies.attribute_name {
			copies.attribute_name = value.clone()
		}
		return copies.attribute_name
	}
	return value
}

fn xml_append_doctype(document &dom.Document, type_ vxml.DocumentType) ! {
	mut doctype := dom.DocumentType.create(document)
	doctype.set_name(xml_dom_owned_string(type_.name))
	// These identifier slices are created after leaving parser scratch and
	// already belong to the same allocation owner as the DOM being built.
	mut identifiers := []string{}
	mut position := 0
	for position < type_.external_id.len {
		quote := type_.external_id[position]
		position++
		if quote !in [`'`, `"`] { continue }
		start := position
		for position < type_.external_id.len && type_.external_id[position] != quote { position++ }
		identifiers << type_.external_id[start..position]
		position++
	}
	if type_.external_id.starts_with('PUBLIC') && identifiers.len == 2 {
		doctype.set_public_id(identifiers[0])
		doctype.set_system_id(identifiers[1])
	} else if identifiers.len == 1 {
		doctype.set_system_id(identifiers[0])
	}
	mut parent := document.as_node()
	parent.append_child(doctype.as_node())!
}

// Keep the inherited default separate from explicit prefix bindings. Most
// XML/SVG elements need only the default and share the parent's scope.
struct XMLNamespaces {
mut:
	default_uri string
	prefixes ?map[string]string
}

fn (scope XMLNamespaces) uri_for_prefix(prefix string) !string {
	if prefix == '' {
		return scope.default_uri
	}
	if prefix == 'xml' {
		return xml_namespace_uri
	}
	if prefixes := scope.prefixes {
		if uri := prefixes[prefix] {
			return uri
		}
	}
	return error('unbound XML namespace prefix ${prefix}')
}

fn xml_append_vlib_node(parent &dom.Node, node vxml.XMLNode, inherited_namespaces XMLNamespaces, prepared xmlcompat.Document, mut copies XMLPublishedStrings) ! {
	colon := xmlcompat.check_name_colon(node.name)!
	mut namespaces := unsafe { inherited_namespaces }
	mut owns_prefixes := false
	for name, raw_value in node.attributes {
		if name == 'xmlns' || name.starts_with('xmlns:') {
			xmlcompat.check_name(name)!
			value := prepared.attribute_value(raw_value)!
			// Map insertion owns its key; this prefix is only a temporary view.
			prefix := if name == 'xmlns' { '' } else { name.substr_unsafe(6, name.len) }
			if prefix == 'xmlns' || value == xmlns_namespace_uri || (prefix == 'xml' && value != xml_namespace_uri)
				|| (prefix != 'xml' && value == xml_namespace_uri) || (prefix != '' && value == '') {
				return error('invalid XML namespace declaration ${name}')
			}
			if prefix == '' {
				namespaces.default_uri = xml_dom_owned_string(value)
			} else if prefix != 'xml' {
				mut prefixes := if owns_prefixes {
					unsafe { namespaces.prefixes or { map[string]string{} } }
				} else if inherited_prefixes := inherited_namespaces.prefixes {
					inherited_prefixes.clone()
				} else {
					map[string]string{}
				}
				prefixes[prefix] = xml_dom_owned_string(value)
				namespaces.prefixes = unsafe { prefixes }
				owns_prefixes = true
			}
		}
	}
	// Prefix and local-name views are used only for lookups and validation.
	// DOM constructors receive their own string in the restored document owner.
	namespace_ := if colon < 0 {
		namespaces.default_uri
	} else {
		namespaces.uri_for_prefix(node.name.substr_unsafe(0, colon))!
	}
	document := parent.document()
	element_name := copies.owned_element_name(node.name)
	namespace_option := if namespace_ == '' { ?string(none) } else { ?string(namespace_) }
	// The XML name scan already validated the unprefixed ASCII name. The
	// exception for xmlns and namespace validation still use the DOM path.
	mut element := if colon < 0 && node.name[0] < 0x80 && element_name != 'xmlns'
		&& namespace_ != xmlns_namespace_uri {
		dom.create_element_with_registry(document, element_name, namespace_option, none, none, true,
			document.custom_element_registry())!
	} else {
		document.create_element_ns(namespace_option, element_name)!
	}
	if node.attributes.len > 4 { element.ensure_attribute_capacity(node.attributes.len) }
	mut expanded_names := ?map[string]bool(none)
	for name, raw_value in node.attributes {
		value := prepared.attribute_value(raw_value)!
		is_declaration := name == 'xmlns' || name.starts_with('xmlns:')
		// Namespace declarations were checked before building the scope.
		attribute_colon := if is_declaration {
			if name == 'xmlns' { -1 } else { 5 }
		} else {
			xmlcompat.check_name_colon(name)!
		}
		attribute_prefix := if attribute_colon < 0 {
			''
		} else {
			name.substr_unsafe(0, attribute_colon)
		}
		attribute_namespace := if is_declaration {
			xmlns_namespace_uri
		} else if attribute_prefix != '' {
			namespaces.uri_for_prefix(attribute_prefix)!
		} else {
			''
		}
		// vlib already rejects duplicate raw names. Only two author prefixes
		// bound to the same namespace can introduce an additional collision.
		if attribute_prefix !in ['', 'xml', 'xmlns'] {
			local_name := name.substr_unsafe(attribute_colon + 1, name.len)
			expanded_name := '${attribute_namespace}\x00${local_name}'
			// Even an empty map allocates a header. Create it only for author
			// prefixes, aliasing and restoring our private map without cloning.
			mut names := unsafe { expanded_names or { map[string]bool{} } }
			if expanded_name in names { return error('duplicate XML attribute ${name}') }
			names[expanded_name] = true
			expanded_names = unsafe { names }
		}
		owned_name := copies.owned_attribute_name(name)
		owned_value := xml_dom_owned_string(value)
		if attribute_colon < 0 && !is_declaration {
			// Unprefixed XML attributes have no namespace and passed the
			// narrower XML name check above. Apply the same Trusted Types
			// policy as setAttributeNS before publishing the value.
			verified := document.trusted_types_compliant_attribute_value(element, owned_name,
				none, owned_value)!
			element.set_attribute_value(owned_name, verified)
		} else {
			element.set_attribute_ns_for_bindings(?string(attribute_namespace), owned_name,
				owned_value)!
		}
	}
	mut mutable_parent := unsafe { &dom.Node(parent) }
	mutable_parent.append_child(element.as_node())!
	if node.children.len > 0 {
		xml_append_vlib_children(element.as_node(), node.children, namespaces, prepared, mut copies)!
	}
}

fn xml_append_vlib_children(parent &dom.Node, children []vxml.XMLNodeContents, namespaces XMLNamespaces, prepared xmlcompat.Document, mut copies XMLPublishedStrings) ! {
	mut mutable_parent := unsafe { &dom.Node(parent) }
	document := parent.document()
	for child in children {
		match child {
			vxml.XMLNode { xml_append_vlib_node(parent, child, namespaces, prepared, mut copies)! }
			string {
				mutable_parent.append_child(document.create_text_node(copies.owned_text(child)).as_node())!
			}
			vxml.XMLCData {
				mutable_parent.append_child(document.create_cdata_section(xml_dom_owned_string(child.text))!.as_node())!
			}
			vxml.XMLComment {
				if special := prepared.special_node(child) {
					if doctype := special.doctype {
						if !parent.is_document() { return error('doctype inside XML element') }
						xml_append_doctype(document, doctype)!
					} else if special.is_comment {
						mutable_parent.append_child(document.create_comment(xml_dom_owned_string(special.data)).as_node())!
					} else if special.is_text {
						mutable_parent.append_child(document.create_text_node(copies.owned_text(special.data)).as_node())!
					} else if special.is_cdata {
						mutable_parent.append_child(document.create_cdata_section(xml_dom_owned_string(special.data))!.as_node())!
					} else {
						mutable_parent.append_child(document.create_processing_instruction(xml_dom_owned_string(special.target), xml_dom_owned_string(special.data))!.as_node())!
					}
				} else {
					mutable_parent.append_child(document.create_comment(xml_dom_owned_string(child.text)).as_node())!
				}
			}
		}
	}
}

// The single XML parsing boundary for DOMParser, document loads, SVG and XHTML
// fragments. vlib owns element structure, attributes and reference decoding;
// this adapter supplies browser DOM namespaces and document-only node types.
pub fn parse_xml_document_source(document &dom.Document, source string) ! {
	mut copies := XMLPublishedStrings{}
	$if prealloc {
		scratch := platform.begin_thread_scratch('XML parse tree')
		defer { scratch.finish() }
		parsed := xmlcompat.parse(source, resolve_named_character_reference, borrow_text: true) or {
			// The error object and message may also live in parser scratch.
			// Restore the caller before copying the error that escapes this call.
			scratch.leave()
			return error_with_code(err.msg().clone(), err.code())
		}
		// Keep the temporary tree readable while all retained DOM allocations
		// and copied payloads go to the caller's original allocation owner.
		scratch.leave()
		xml_append_vlib_children(document.as_node(), parsed.children, XMLNamespaces{}, parsed, mut copies)!
		return
	}
	parsed := xmlcompat.parse(source, resolve_named_character_reference, xmlcompat.ParseOptions{})!
	xml_append_vlib_children(document.as_node(), parsed.children, XMLNamespaces{}, parsed, mut copies)!
}
