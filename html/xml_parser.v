// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

module html

import dom
import encoding.xml as vxml
import xmlcompat

fn xml_qualified_name_parts(name string) (string, string) {
	if colon := name.index(':') { return name[..colon], name[colon + 1..] }
	return '', name
}

fn xml_append_doctype(document &dom.Document, type_ vxml.DocumentType) ! {
	mut doctype := dom.DocumentType.create(document)
	doctype.set_name(type_.name)
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

fn xml_append_vlib_node(parent &dom.Node, node vxml.XMLNode, inherited_namespaces map[string]string, prepared xmlcompat.Document) ! {
	xmlcompat.check_name(node.name)!
	mut namespaces := unsafe { inherited_namespaces }
	mut owns_namespaces := false
	for name, raw_value in node.attributes {
		xmlcompat.check_name(name)!
		if name == 'xmlns' || name.starts_with('xmlns:') {
			value := prepared.attribute_value(raw_value)!
			prefix := if name == 'xmlns' { '' } else { name[6..] }
			if prefix == 'xmlns' || value == xmlns_namespace_uri || (prefix == 'xml' && value != xml_namespace_uri)
				|| (prefix != 'xml' && value == xml_namespace_uri) || (prefix != '' && value == '') {
				return error('invalid XML namespace declaration ${name}')
			}
			if !owns_namespaces {
				namespaces = inherited_namespaces.clone()
				owns_namespaces = true
			}
			namespaces[prefix] = value
		}
	}
	prefix, _ := xml_qualified_name_parts(node.name)
	if prefix != '' && prefix !in namespaces {
		return error('unbound XML namespace prefix ${prefix}')
	}
	namespace_ := namespaces[prefix] or { '' }
	mut element := parent.document().create_element_ns(if namespace_ == '' {
		none
	} else {
		?string(namespace_)
	}, node.name)!
	mut expanded_names := map[string]bool{}
	for name, raw_value in node.attributes {
		value := prepared.attribute_value(raw_value)!
		attribute_prefix, local_name := xml_qualified_name_parts(name)
		attribute_namespace := if name == 'xmlns' || attribute_prefix == 'xmlns' {
			xmlns_namespace_uri
		} else if attribute_prefix != '' {
			namespaces[attribute_prefix] or { return error('unbound XML namespace prefix ${attribute_prefix}') }
		} else {
			''
		}
		// vlib already rejects duplicate raw names. Only two author prefixes
		// bound to the same namespace can introduce an additional collision.
		if attribute_prefix !in ['', 'xml', 'xmlns'] {
			expanded_name := '${attribute_namespace}\x00${local_name}'
			if expanded_name in expanded_names { return error('duplicate XML attribute ${name}') }
			expanded_names[expanded_name] = true
		}
		element.set_attribute_ns_for_bindings(if attribute_namespace == '' {
			none
		} else {
			?string(attribute_namespace)
		}, name, value)!
	}
	mut mutable_parent := unsafe { &dom.Node(parent) }
	mutable_parent.append_child(element.as_node())!
	xml_append_vlib_children(element.as_node(), node.children, namespaces, prepared)!
}

fn xml_append_vlib_children(parent &dom.Node, children []vxml.XMLNodeContents, namespaces map[string]string, prepared xmlcompat.Document) ! {
	mut mutable_parent := unsafe { &dom.Node(parent) }
	document := parent.document()
	for child in children {
		match child {
			vxml.XMLNode { xml_append_vlib_node(parent, child, namespaces, prepared)! }
			string { mutable_parent.append_child(document.create_text_node(child).as_node())! }
			vxml.XMLCData {
				mutable_parent.append_child(document.create_cdata_section(child.text)!.as_node())!
			}
			vxml.XMLComment {
				if special := prepared.special_node(child) {
					if doctype := special.doctype {
						if !parent.is_document() { return error('doctype inside XML element') }
						xml_append_doctype(document, doctype)!
					} else if special.is_comment {
						mutable_parent.append_child(document.create_comment(special.data).as_node())!
					} else if special.is_text {
						mutable_parent.append_child(document.create_text_node(special.data).as_node())!
					} else if special.is_cdata {
						mutable_parent.append_child(document.create_cdata_section(special.data)!.as_node())!
					} else {
						mutable_parent.append_child(document.create_processing_instruction(special.target, special.data)!.as_node())!
					}
				} else {
					mutable_parent.append_child(document.create_comment(child.text).as_node())!
				}
			}
		}
	}
}

// The single XML parsing boundary for DOMParser, document loads, SVG and XHTML
// fragments. vlib owns element structure, attributes and reference decoding;
// this adapter supplies browser DOM namespaces and document-only node types.
pub fn parse_xml_document_source(document &dom.Document, source string) ! {
	parsed := xmlcompat.parse(source, resolve_named_character_reference)!
	xml_append_vlib_children(document.as_node(), parsed.children, {
		'xml': xml_namespace_uri
	}, parsed)!
}
