// Copyright (c) 2022, Luke Wilde <lukew@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/XMLSerializer.cpp — the DOM-Parsing XML
// serialization algorithm (https://w3c.github.io/DOM-Parsing/).
//
// C++ uses Optional<FlyString> for nullable namespaces/prefixes. Since V map keys must be
// primitive and V has no ergonomic Optional equality, nullable names are modelled by the
// OptName struct, and the namespace-prefix map is keyed by the sentinel-encoded namespace
// (see ns_map_key). The `u64& prefix index` reference is threaded as PrefixIndexCounter
// (V forbids mutable primitive parameters). WebIDL::ExceptionOr<String> becomes `!string`.
module html

import dom
import namespace_

// A nullable FlyString: the DOM-Parsing "null" namespace/prefix vs a present value.
struct OptName {
	present bool
	value   string
}

fn some_name(value string) OptName {
	return OptName{
		present: true
		value:   value
	}
}

const none_name = OptName{
	present: false
	value:   ''
}

fn opt_name_from(value ?string) OptName {
	if v := value {
		return some_name(v)
	}
	return none_name
}

fn (a OptName) == (b OptName) bool {
	return a.present == b.present && (!a.present || a.value == b.value)
}

// Encode a nullable namespace as a map key so the null namespace never collides with a real one.
fn ns_map_key(namespace_value OptName) string {
	return if namespace_value.present { '\x01${namespace_value.value}' } else { '\x00' }
}

// The generated namespace prefix index, threaded by reference through the algorithm.
struct PrefixIndexCounter {
mut:
	value u64
}

pub enum RequireWellFormed {
	no
	yes
}

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#xmlserializer
@[heap]
pub struct XMLSerializer {}

pub fn XMLSerializer.construct_impl() &XMLSerializer {
	return &XMLSerializer{}
}

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-xmlserializer-serializetostring
pub fn (s &XMLSerializer) serialize_to_string(root &dom.Node) !string {
	// 1. Return the XML serialization of root given false.
	return serialize_node_to_xml_string(root, .no)
}

// https://w3c.github.io/DOM-Parsing/#dfn-add
fn xml_add_prefix_to_namespace_prefix_map(mut prefix_map map[string][]OptName, prefix OptName, namespace_value OptName) {
	key := ns_map_key(namespace_value)
	// 1-2. Retrieve the candidates list; if null, create a new list with prefix as its only item.
	if key in prefix_map {
		// 3. Otherwise, append prefix to the end of candidates list.
		prefix_map[key] << prefix
	} else {
		prefix_map[key] = [prefix]
	}
}

// https://w3c.github.io/DOM-Parsing/#dfn-retrieving-a-preferred-prefix-string
fn xml_retrieve_a_preferred_prefix_string(preferred_prefix OptName, prefix_map map[string][]OptName, namespace_value OptName) OptName {
	// 1. If there is no key matching ns, return the null value.
	candidates := prefix_map[ns_map_key(namespace_value)] or { return none_name }
	// 2. For each prefix in candidates list, from beginning to end:
	for prefix_index, prefix in candidates {
		// 1. If prefix matches preferred prefix, return prefix.
		if prefix == preferred_prefix {
			return prefix
		}
		// 2. If prefix is the last item in the candidates list, return prefix.
		if prefix_index == candidates.len - 1 {
			return prefix
		}
	}
	// Spec Note: there will always be at least one prefix value in the list.
	return none_name
}

fn xml_prefix_is_bound_in_prefix_map(prefix OptName, prefix_map map[string][]OptName) bool {
	for _, prefixes in prefix_map {
		if prefix in prefixes {
			return true
		}
	}
	return false
}

// https://w3c.github.io/DOM-Parsing/#dfn-generating-a-prefix
fn xml_generate_a_prefix(mut prefix_map map[string][]OptName, new_namespace OptName, mut counter PrefixIndexCounter) string {
	mut generated_prefix := ''
	// AD-HOC: Skip prefixes already bound in scope, including an attribute's
	// preserved prefix. See https://github.com/w3c/DOM-Parsing/issues/44.
	for {
		// 1. Let generated prefix be "ns" concatenated with the current prefix index.
		generated_prefix = 'ns${counter.value}'
		// 2. Increment prefix index.
		counter.value++
		if !xml_prefix_is_bound_in_prefix_map(some_name(generated_prefix), prefix_map) {
			break
		}
	}
	// 3. Add the generated prefix to map given new namespace.
	xml_add_prefix_to_namespace_prefix_map(mut prefix_map, some_name(generated_prefix),
		new_namespace)
	// 4. Return generated prefix.
	return generated_prefix
}

// https://w3c.github.io/DOM-Parsing/#dfn-found
fn xml_prefix_is_in_prefix_map(prefix string, prefix_map map[string][]OptName, namespace_value OptName) bool {
	// 1. If there is no key matching ns, return false.
	candidates := prefix_map[ns_map_key(namespace_value)] or { return false }
	// 2. Return whether prefix occurs at least once in candidates list.
	return some_name(prefix) in candidates
}

// https://w3c.github.io/DOM-Parsing/#dfn-xml-serialization
pub fn serialize_node_to_xml_string(root &dom.Node, require_well_formed RequireWellFormed) !string {
	// 1. Let namespace be a context namespace with value null.
	namespace_value := none_name
	// 2. Let prefix map be a new namespace prefix map.
	mut prefix_map := map[string][]OptName{}
	// 3. Add the XML namespace with prefix value "xml" to prefix map.
	xml_add_prefix_to_namespace_prefix_map(mut prefix_map, some_name('xml'),
		some_name(namespace_.xml))
	// 4. Let prefix index be a generated namespace prefix index with value 1.
	mut counter := PrefixIndexCounter{
		value: 1
	}
	// 5. Return the result of running the XML serialization algorithm on node.
	return serialize_node_to_xml_string_impl(root, namespace_value, prefix_map, mut counter,
		require_well_formed)
}

fn character_data_string(node &dom.Node) string {
	cd := node.as_character_data() or { return '' }
	return cd.data()
}

// https://w3c.github.io/DOM-Parsing/#dfn-xml-serialization-algorithm
fn serialize_node_to_xml_string_impl(root &dom.Node, namespace_value OptName, prefix_map map[string][]OptName, mut counter PrefixIndexCounter, require_well_formed RequireWellFormed) !string {
	// If node's interface is:
	match root.type_() {
		.element_node {
			element := root.as_element() or { return error('Not an element') }
			return xml_serialize_element(element, namespace_value, prefix_map, mut counter,
				require_well_formed)
		}
		.document_node {
			document := root.as_document() or { return error('Not a document') }
			return xml_serialize_document(document, namespace_value, prefix_map, mut counter,
				require_well_formed)
		}
		.comment_node {
			return xml_serialize_comment(character_data_string(root), require_well_formed)
		}
		.cdata_section_node {
			// Run the XML serialization algorithm for a CDATASection node.
			return xml_serialize_cdata_section(character_data_string(root), require_well_formed)
		}
		.text_node {
			return xml_serialize_text(character_data_string(root), require_well_formed)
		}
		.document_fragment_node {
			return xml_serialize_document_fragment(root, namespace_value, prefix_map, mut counter,
				require_well_formed)
		}
		.document_type_node {
			document_type := root.as_document_type() or { return error('Not a document type') }
			return xml_serialize_document_type(document_type.name(), document_type.public_id(),
				document_type.system_id(), require_well_formed)
		}
		.processing_instruction_node {
			pi := root.as_processing_instruction() or {
				return error('Not a processing instruction')
			}
			return xml_serialize_processing_instruction(pi.target(), character_data_string(root),
				require_well_formed)
		}
		.attribute_node {
			// An Attr object: return an empty string.
			return ''
		}
		else {
			// Anything else: only Nodes and Attr objects can be serialized by this algorithm.
			return error('Can only serialize Nodes or Attributes.')
		}
	}
}

// https://w3c.github.io/DOM-Parsing/#dfn-recording-the-namespace-information
fn xml_record_namespace_information(element &dom.Element, mut prefix_map map[string][]OptName, mut local_prefix_map map[string]string) OptName {
	// 1. Let default namespace attr value be null.
	mut default_namespace_attribute_value := none_name
	// 2. Main: For each attribute attr in element's attributes, in list order:
	attributes := element.attribute_list() or { return default_namespace_attribute_value }
	for attribute_index in 0 .. attributes.length() {
		attribute := attributes.item(attribute_index) or { continue }
		// 1. Let attribute namespace be attr's namespaceURI.
		attribute_namespace := opt_name_from(attribute.namespace_uri())
		// 2. Let attribute prefix be attr's prefix.
		attribute_prefix := opt_name_from(attribute.prefix())
		// 3. If the attribute namespace is the XMLNS namespace:
		if attribute_namespace == some_name(namespace_.xmlns) {
			// 1. If attribute prefix is null, attr is a default namespace declaration.
			if !attribute_prefix.present {
				default_namespace_attribute_value = some_name(attribute.value())
				continue
			}
			// 2. Otherwise attr is a namespace prefix definition. Run these steps:
			// 1. Let prefix definition be attr's localName.
			prefix_definition := attribute.local_name()
			// 2. Let namespace definition be attr's value.
			mut namespace_definition := some_name(attribute.value())
			// 3. If namespace definition is the XML namespace, visit the next attribute.
			if namespace_definition == some_name(namespace_.xml) {
				continue
			}
			// 4. If namespace definition is the empty string, let it be null instead.
			if namespace_definition == some_name('') {
				namespace_definition = none_name
			}
			// 5. If prefix definition is found in map given namespace definition, visit the next attribute.
			if xml_prefix_is_in_prefix_map(prefix_definition, prefix_map, namespace_definition) {
				continue
			}
			// 6. Add prefix definition to map given namespace definition.
			xml_add_prefix_to_namespace_prefix_map(mut prefix_map, some_name(prefix_definition),
				namespace_definition)
			// 7. Add prefix definition to the local prefixes map (null namespace stored as empty string).
			local_prefix_map[prefix_definition] = if namespace_definition.present {
				namespace_definition.value
			} else {
				''
			}
		}
	}
	// 3. Return default namespace attr value.
	return default_namespace_attribute_value
}

// https://w3c.github.io/DOM-Parsing/#dfn-serializing-an-attribute-value
fn xml_serialize_an_attribute_value(attribute_value OptName, require_well_formed RequireWellFormed) !string {
	// 1. Well-formed attribute values must match the XML Char production.
	if require_well_formed == .yes && attribute_value.present
		&& !is_valid_xml_string(attribute_value.value) {
		return error('Attribute value contains characters not allowed in XML')
	}
	// 2. If attribute value is null, return the empty string.
	if !attribute_value.present {
		return ''
	}
	// 3. Otherwise, return the value with the following replacements applied:
	mut final_attribute_value := attribute_value.value
	final_attribute_value = final_attribute_value.replace('&', '&amp;')
	final_attribute_value = final_attribute_value.replace('"', '&quot;')
	final_attribute_value = final_attribute_value.replace('<', '&lt;')
	final_attribute_value = final_attribute_value.replace('>', '&gt;')
	// XML parsers normalize literal attribute whitespace; character references
	// preserve the original value when the serialized markup is parsed again.
	final_attribute_value = final_attribute_value.replace('\t', '&#9;')
	final_attribute_value = final_attribute_value.replace('\n', '&#xA;')
	final_attribute_value = final_attribute_value.replace('\r', '&#xD;')
	return final_attribute_value
}

struct LocalNameSetEntry {
	namespace_uri OptName
	local_name    string
}

// https://w3c.github.io/DOM-Parsing/#dfn-xml-serialization-of-the-attributes
fn xml_serialize_element_attributes(element &dom.Element, mut prefix_map map[string][]OptName, mut counter PrefixIndexCounter, mut local_prefixes_map map[string]string, ignore_namespace_definition_attribute bool, require_well_formed RequireWellFormed) !string {
	// 1. Let result be the empty string.
	mut result := ''
	// 2. Let localname set be a new empty namespace localname set.
	mut local_name_set := []LocalNameSetEntry{}
	// 3. Loop: For each attribute attr in element's attributes, in list order:
	attributes := element.attribute_list() or { return result }
	for attribute_index in 0 .. attributes.length() {
		attribute := attributes.item(attribute_index) or { continue }
		attribute_local_name := attribute.local_name()
		attribute_prefix := opt_name_from(attribute.prefix())
		attribute_value_name := some_name(attribute.value())
		attribute_namespace := opt_name_from(attribute.namespace_uri())
		// 1. Well-formed: reject a duplicate (namespaceURI, localName) tuple.
		if require_well_formed == .yes {
			for entry in local_name_set {
				if entry.namespace_uri == attribute_namespace
					&& entry.local_name == attribute_local_name {
					return error('Element contains two attributes with identical namespaces and local names')
				}
			}
		}
		// 2. Add the (namespaceURI, localName) tuple to the localname set.
		local_name_set << LocalNameSetEntry{
			namespace_uri: attribute_namespace
			local_name:    attribute_local_name
		}
		// 4. Let candidate prefix be null.
		mut candidate_prefix := none_name
		// 5. If attribute namespace is not null:
		if attribute_namespace.present {
			// 1. Retrieve a preferred prefix string for attribute namespace with attr's prefix.
			candidate_prefix = xml_retrieve_a_preferred_prefix_string(attribute_prefix, prefix_map,
				attribute_namespace)
			// 2. If attribute namespace is the XMLNS namespace:
			if attribute_namespace == some_name(namespace_.xmlns) {
				// 1. Skip this attribute if any of the following are true:
				// - attr's value is the XML namespace;
				if attribute_value_name == some_name(namespace_.xml) {
					continue
				}
				// - attr's prefix is null and ignore namespace definition attribute is true;
				if !attribute_prefix.present && ignore_namespace_definition_attribute {
					continue
				}
				// - attr's prefix is not null and either
				if attribute_prefix.present {
					// - localName is not a key in the local prefixes map, or
					// - the local prefixes map value for localName does not match attr's value;
					is_not_local_prefix_definition := attribute_local_name !in local_prefixes_map
						|| local_prefixes_map[attribute_local_name] != attribute.value()
					// and furthermore the same declaration was defined on an ancestor.
					if is_not_local_prefix_definition
						&& xml_prefix_is_in_prefix_map(attribute_local_name, prefix_map,
							attribute_value_name) {
						continue
					}
				}
				// 2. Well-formed: attr's value cannot be the XMLNS namespace.
				if require_well_formed == .yes
					&& attribute_value_name == some_name(namespace_.xmlns) {
					return error("The XMLNS namespace cannot be used as an element's namespace")
				}
				// 3. Well-formed: attr's value cannot be the empty string.
				if require_well_formed == .yes && attribute.value().len == 0 {
					return error("Attribute's value is empty")
				}
				// 4. If attr's prefix matches "xmlns", let candidate prefix be "xmlns".
				if attribute_prefix == some_name('xmlns') {
					candidate_prefix = some_name('xmlns')
				}
			} else if !candidate_prefix.present {
				// 3. Otherwise, if the attribute namespace has no preferred prefix:
				// 1. Keep the attribute's own prefix if it is not already declared.
				// AD-HOC: A binding anywhere in scope also prevents reuse, so an
				// attribute cannot redefine the element's or an ancestor's prefix.
				if attribute_prefix.present && attribute_prefix.value !in local_prefixes_map
					&& !xml_prefix_is_bound_in_prefix_map(attribute_prefix, prefix_map) {
					candidate_prefix = attribute_prefix
				} else {
					// 2. Otherwise generate an unused prefix.
					candidate_prefix = some_name(xml_generate_a_prefix(mut prefix_map,
						attribute_namespace, mut counter))
				}
				// 3-5. Record the new binding in both maps for later attributes.
				xml_add_prefix_to_namespace_prefix_map(mut prefix_map, candidate_prefix,
					attribute_namespace)
				local_prefixes_map[candidate_prefix.value] = attribute_namespace.value
				// 6. Append ' xmlns:<candidate prefix>="<serialized namespace>"' to result.
				result += ' xmlns:'
				result += candidate_prefix.value
				result += '="'
				result +=
					xml_serialize_an_attribute_value(attribute_namespace, require_well_formed)!
				result += '"'
			}
		}
		// 6. Append a space to result.
		result += ' '
		// 7. If candidate prefix is not null, append candidate prefix and ":" to result.
		if candidate_prefix.present {
			result += '${candidate_prefix.value}:'
		}
		// 8. Well-formed checks on attr's localName.
		if require_well_formed == .yes {
			if attribute_local_name.contains(':') {
				return error("Attribute's local name contains a colon")
			}
			if !matches_xml_name(attribute_local_name) {
				return error("Attribute's local name does not match the XML Name production")
			}
			if attribute_local_name == 'xmlns' && !attribute_namespace.present {
				return error("Attribute's local name is 'xmlns' and the attribute has no namespace")
			}
		}
		// 9. Append '<localName>="<serialized value>"' to result.
		result += attribute_local_name
		result += '="'
		result += xml_serialize_an_attribute_value(attribute_value_name, require_well_formed)!
		result += '"'
	}
	// 4. Return result.
	return result
}

// Void elements in the HTML namespace (serialized as self-closing when empty).
const xml_void_elements = ['area', 'base', 'basefont', 'bgsound', 'br', 'col', 'embed', 'frame',
	'hr', 'img', 'input', 'keygen', 'link', 'menuitem', 'meta', 'param', 'source', 'track', 'wbr']

// https://w3c.github.io/DOM-Parsing/#xml-serializing-an-element-node
fn xml_serialize_element(element &dom.Element, namespace_value OptName, prefix_map map[string][]OptName, mut counter PrefixIndexCounter, require_well_formed RequireWellFormed) !string {
	// 1. Well-formed: element's localName cannot contain ":" or fail the XML Name production.
	if require_well_formed == .yes {
		if element.local_name().contains(':') {
			return error("Element's local name contains a colon")
		}
		if !matches_xml_name(element.local_name()) {
			return error("Element's local name does not match the XML Name production")
		}
	}
	// 2. Let markup be "<".
	mut markup := '<'
	// 3. Let qualified name be an empty string.
	mut qualified_name := ''
	// 4. Let skip end tag be false.
	mut skip_end_tag := false
	// 5. Let ignore namespace definition attribute be false.
	mut ignore_namespace_definition_attribute := false
	// 6. Copy prefix map into a local map.
	mut local_map := prefix_map.clone()
	// 7. Let local prefixes map be an empty map (null namespace represented by the empty string).
	mut local_prefixes_map := map[string]string{}
	// 8. Let local default namespace be the result of recording the namespace information.
	local_default_namespace := xml_record_namespace_information(element, mut local_map, mut
		local_prefixes_map)
	// 9. Let inherited ns be a copy of namespace.
	mut inherited_ns := namespace_value
	// 10. Let ns be element's namespaceURI.
	ns := opt_name_from(element.namespace_uri())
	// 11. If inherited ns equals ns:
	if inherited_ns == ns {
		// 1. If local default namespace is not null, set ignore namespace definition attribute to true.
		if local_default_namespace.present {
			ignore_namespace_definition_attribute = true
		}
		// 2. If ns is the XML namespace, prepend "xml:" to the localName.
		if ns == some_name(namespace_.xml) {
			qualified_name += 'xml:${element.local_name()}'
		} else {
			// 3. Otherwise, qualified name is the localName.
			qualified_name += element.local_name()
		}
		// 4. Append qualified name to markup.
		markup += qualified_name
	} else {
		// 12. Otherwise inherited ns is not equal to ns:
		// 1. Let prefix be element's prefix.
		mut prefix := opt_name_from(element.prefix())
		// 2. Let candidate prefix be a preferred prefix string for ns given prefix.
		mut candidate_prefix := xml_retrieve_a_preferred_prefix_string(prefix, local_map, ns)
		// 3. If prefix matches "xmlns":
		if prefix == some_name('xmlns') {
			// 1. Well-formed: an element with prefix "xmlns" cannot round-trip.
			if require_well_formed == .yes {
				return error("Elements prefix is 'xmlns'")
			}
			// 2. Let candidate prefix be prefix.
			candidate_prefix = prefix
		}
		// 4. If candidate prefix is not null:
		if candidate_prefix.present {
			// 1. Append "<candidate prefix>:<localName>" to qualified name.
			qualified_name += '${candidate_prefix.value}:${element.local_name()}'
			// 2. If local default namespace is not null and not the XML namespace, update inherited ns.
			if local_default_namespace.present
				&& local_default_namespace != some_name(namespace_.xml) {
				inherited_ns = if local_default_namespace.value.len != 0 {
					local_default_namespace
				} else {
					none_name
				}
			}
			// 3. Append qualified name to markup.
			markup += qualified_name
		} else if prefix.present {
			// 5. Otherwise, if prefix is not null:
			// 1. If the local prefixes map contains prefix, regenerate prefix.
			if prefix.value in local_prefixes_map {
				prefix = some_name(xml_generate_a_prefix(mut local_map, ns, mut counter))
			}
			// 2. Add prefix to map given ns.
			xml_add_prefix_to_namespace_prefix_map(mut local_map, prefix, ns)
			// 3. Append "<prefix>:<localName>" to qualified name.
			qualified_name += '${prefix.value}:${element.local_name()}'
			// 4. Append qualified name to markup.
			markup += qualified_name
			// 5. Append ' xmlns:<prefix>="<serialized ns>"' to markup.
			markup += ' xmlns:'
			markup += prefix.value
			markup += '="'
			markup += xml_serialize_an_attribute_value(ns, require_well_formed)!
			markup += '"'
			// 7. If local default namespace is not null, update inherited ns.
			if local_default_namespace.present {
				inherited_ns = if local_default_namespace.value.len != 0 {
					local_default_namespace
				} else {
					none_name
				}
			}
		} else if !local_default_namespace.present || local_default_namespace != ns {
			// 6. Otherwise, if local default namespace is null or does not equal ns:
			// 1. Set ignore namespace definition attribute to true.
			ignore_namespace_definition_attribute = true
			// 2. Append localName to qualified name.
			qualified_name += element.local_name()
			// 3. Let inherited ns be ns.
			inherited_ns = ns
			// 4. Append qualified name to markup.
			markup += qualified_name
			// 5. Append ' xmlns="<serialized ns>"' to markup.
			markup += ' xmlns="'
			markup += xml_serialize_an_attribute_value(ns, require_well_formed)!
			markup += '"'
		} else {
			// 7. Otherwise the node has a local default namespace that matches ns.
			qualified_name += element.local_name()
			inherited_ns = ns
			markup += qualified_name
		}
	}
	// 13. Append the serialization of element's attributes.
	markup += xml_serialize_element_attributes(element, mut local_map, mut counter,
		mut local_prefixes_map, ignore_namespace_definition_attribute, require_well_formed)!
	as_node := element.as_node()
	has_children := as_node.has_children()
	// 14. HTML-namespace void element with no children: append " /" and skip end tag.
	if ns == some_name(namespace_.html) && !has_children
		&& element.local_name() in xml_void_elements {
		markup += ' /'
		skip_end_tag = true
	}
	// 15. Non-HTML element with no children: append "/" and skip end tag.
	if ns != some_name(namespace_.html) && !has_children {
		markup += '/'
		skip_end_tag = true
	}
	// 16. Append ">".
	markup += '>'
	// 17. If skip end tag, return markup (leaf node).
	if skip_end_tag {
		return markup
	}
	// 18. HTML template element: serialize its template contents (a DocumentFragment).
	if ns == some_name(namespace_.html) && element.local_name() == 'template' {
		template_element := unsafe { &dom.HTMLTemplateElement(element) }
		markup += xml_serialize_document_fragment(template_element.content().as_node(),
			inherited_ns, local_map, mut counter, require_well_formed)!
	} else {
		// 19. Otherwise, serialize each child in tree order.
		mut child := as_node.first_child()
		for {
			current := child or { break }
			markup += serialize_node_to_xml_string_impl(current, inherited_ns, local_map, mut
				counter, require_well_formed)!
			child = current.next_sibling()
		}
	}
	// 20. Append "</<qualified name>>".
	markup += '</'
	markup += qualified_name
	markup += '>'
	// 21. Return markup.
	return markup
}

// https://w3c.github.io/DOM-Parsing/#xml-serializing-a-document-node
fn xml_serialize_document(document &dom.Document, namespace_value OptName, prefix_map map[string][]OptName, mut counter PrefixIndexCounter, require_well_formed RequireWellFormed) !string {
	// Well-formed: a document must have a document element.
	if require_well_formed == .yes && document.document_element() == none {
		return error('Document has no document element')
	}
	// 1. Let serialized document be the empty string.
	mut serialized_document := ''
	// 2. Serialize each child in tree order.
	mut child := document.as_node().first_child()
	for {
		current := child or { break }
		serialized_document += serialize_node_to_xml_string_impl(current, namespace_value,
			prefix_map, mut counter, require_well_formed)!
		child = current.next_sibling()
	}
	// 3. Return serialized document.
	return serialized_document
}

// https://w3c.github.io/DOM-Parsing/#xml-serializing-a-comment-node
fn xml_serialize_comment(data string, require_well_formed RequireWellFormed) !string {
	// Well-formed: comment data cannot contain "--" or end with "-".
	if require_well_formed == .yes {
		if !is_valid_xml_string(data) {
			return error('Comment data contains characters not allowed in XML')
		}
		if data.contains('--') {
			return error('Comment data contains two adjacent hyphens')
		}
		if data.ends_with('-') {
			return error('Comment data ends with a hyphen')
		}
	}
	// Otherwise, return "<!--<data>-->".
	return '<!--${data}-->'
}

// XML 1.0 Char production: https://www.w3.org/TR/xml/#charsets
fn is_valid_xml_char(code_point u32) bool {
	return code_point == 0x9 || code_point == 0xA || code_point == 0xD
		|| (code_point >= 0x20 && code_point <= 0xD7FF)
		|| (code_point >= 0xE000 && code_point <= 0xFFFD)
		|| (code_point >= 0x10000 && code_point <= 0x10FFFF)
}

fn is_valid_xml_string(value string) bool {
	for code_point in value.runes() {
		if !is_valid_xml_char(u32(code_point)) {
			return false
		}
	}
	return true
}

// XML 1.0 (Fifth Edition) NameStartChar and NameChar productions.
fn is_xml_name_start_char(code_point u32) bool {
	return code_point == `:` || code_point == `_`
		|| (code_point >= `A` && code_point <= `Z`)
		|| (code_point >= `a` && code_point <= `z`)
		|| (code_point >= 0xC0 && code_point <= 0xD6)
		|| (code_point >= 0xD8 && code_point <= 0xF6)
		|| (code_point >= 0xF8 && code_point <= 0x2FF)
		|| (code_point >= 0x370 && code_point <= 0x37D)
		|| (code_point >= 0x37F && code_point <= 0x1FFF)
		|| (code_point >= 0x200C && code_point <= 0x200D)
		|| (code_point >= 0x2070 && code_point <= 0x218F)
		|| (code_point >= 0x2C00 && code_point <= 0x2FEF)
		|| (code_point >= 0x3001 && code_point <= 0xD7FF)
		|| (code_point >= 0xF900 && code_point <= 0xFDCF)
		|| (code_point >= 0xFDF0 && code_point <= 0xFFFD)
		|| (code_point >= 0x10000 && code_point <= 0xEFFFF)
}

fn is_xml_name_char(code_point u32) bool {
	return is_xml_name_start_char(code_point) || code_point == `-`
		|| code_point == `.` || (code_point >= `0` && code_point <= `9`)
		|| code_point == 0xB7 || (code_point >= 0x0300 && code_point <= 0x036F)
		|| (code_point >= 0x203F && code_point <= 0x2040)
}

fn matches_xml_name(value string) bool {
	code_points := value.runes()
	if code_points.len == 0 || !is_xml_name_start_char(u32(code_points[0])) {
		return false
	}
	for code_point in code_points[1..] {
		if !is_xml_name_char(u32(code_point)) {
			return false
		}
	}
	return true
}

// XML 1.0 PubidChar production.
fn is_xml_pubid_char(code_point u32) bool {
	if code_point == 0x20 || code_point == 0xD || code_point == 0xA
		|| (code_point >= `a` && code_point <= `z`)
		|| (code_point >= `A` && code_point <= `Z`)
		|| (code_point >= `0` && code_point <= `9`) {
		return true
	}
	return code_point in [`-`, `'`, `(`, `)`, `+`, `,`, `.`, `/`, `:`, `=`, `?`, `;`, `!`, `*`,
		`#`, `@`, `$`, `_`, `%`]
}

fn is_valid_xml_public_id(value string) bool {
	for code_point in value.runes() {
		if !is_xml_pubid_char(u32(code_point)) {
			return false
		}
	}
	return true
}

// https://w3c.github.io/DOM-Parsing/#xml-serializing-a-text-node
fn xml_serialize_text(data string, require_well_formed RequireWellFormed) !string {
	// 1. Well-formed: text data must match the XML Char production.
	if require_well_formed == .yes {
		for code_point in data.runes() {
			if !is_valid_xml_char(u32(code_point)) {
				return error('Text contains characters not allowed in XML')
			}
		}
	}
	// 2-6. Escape &, <, > and return.
	mut markup := data
	markup = markup.replace('&', '&amp;')
	markup = markup.replace('<', '&lt;')
	markup = markup.replace('>', '&gt;')
	return markup
}

// https://w3c.github.io/DOM-Parsing/#xml-serializing-a-documentfragment-node
fn xml_serialize_document_fragment(document_fragment &dom.Node, namespace_value OptName, prefix_map map[string][]OptName, mut counter PrefixIndexCounter, require_well_formed RequireWellFormed) !string {
	// 1. Let markup be the empty string.
	mut markup := ''
	// 2. Serialize each child in tree order.
	mut child := document_fragment.first_child()
	for {
		current := child or { break }
		markup += serialize_node_to_xml_string_impl(current, namespace_value, prefix_map, mut
			counter, require_well_formed)!
		child = current.next_sibling()
	}
	// 3. Return markup.
	return markup
}

// https://w3c.github.io/DOM-Parsing/#dfn-serialization-of-the-id
fn xml_serialize_doctype_id(id string) string {
	quote := if id.contains('"') { "'" } else { '"' }
	return '${quote}${id}${quote}'
}

// https://w3c.github.io/DOM-Parsing/#xml-serializing-a-documenttype-node
fn xml_serialize_document_type(name string, public_id string, system_id string, require_well_formed RequireWellFormed) !string {
	if require_well_formed == .yes {
		if !is_valid_xml_public_id(public_id) {
			return error('Document type public ID contains characters not allowed by XML PubidChar')
		}
		if !is_valid_xml_string(system_id) {
			return error('Document type system ID contains characters not allowed in XML')
		}
		if system_id.contains('"') && system_id.contains("'") {
			return error('Document type system ID contains both a quotation mark and an apostrophe')
		}
	}
	// 3-6. "<!DOCTYPE <name>".
	mut markup := '<!DOCTYPE '
	markup += name
	// 7. If publicId is not empty, append PUBLIC and the serialization of the ID.
	if public_id.len != 0 {
		markup += ' PUBLIC ${xml_serialize_doctype_id(public_id)}'
	}
	// 8. If systemId is not empty and publicId is empty, append " SYSTEM".
	if system_id.len != 0 && public_id.len == 0 {
		markup += ' SYSTEM'
	}
	// 9. If systemId is not empty, append a space and the serialization of the ID.
	if system_id.len != 0 {
		markup += ' ${xml_serialize_doctype_id(system_id)}'
	}
	// 10-11. Append ">" and return.
	markup += '>'
	return markup
}

// https://w3c.github.io/DOM-Parsing/#dfn-xml-serializing-a-processinginstruction-node
fn xml_serialize_processing_instruction(target string, data string, require_well_formed RequireWellFormed) !string {
	if require_well_formed == .yes {
		// 1. target cannot contain ":" or be an ASCII case-insensitive match for "xml".
		if target.contains(':') {
			return error('Processing instruction target contains a colon')
		}
		if target.to_lower() == 'xml' {
			return error("Processing instruction target is equal to 'xml'")
		}
		// 2. data must match XML Char and cannot contain "?>".
		if !is_valid_xml_string(data) {
			return error('Processing instruction data contains characters not allowed in XML')
		}
		if data.contains('?>') {
			return error('Processing instruction data contains a terminator')
		}
	}
	// 3. "<?<target> <data>?>".
	return '<?${target} ${data}?>'
}

// https://w3c.github.io/DOM-Parsing/#xml-serializing-a-cdatasection-node
fn xml_serialize_cdata_section(data string, require_well_formed RequireWellFormed) !string {
	if require_well_formed == .yes {
		if !is_valid_xml_string(data) {
			return error('CDATA section data contains characters not allowed in XML')
		}
		if data.contains(']]>') {
			return error('CDATA section data contains a CDATA section end delimiter')
		}
	}
	return '<![CDATA[${data}]]>'
}
