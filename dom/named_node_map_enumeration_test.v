// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause

module dom

// Ladybird a77aced1a001b62604dc39474fe658f06ad124c4.
fn test_named_node_map_enumeration_keeps_order_and_deduplicates_qualified_names() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	mut element := document.create_element('div')!
	for index in 0 .. 3000 {
		element.set_attribute_value('data-${index}', index.str())
	}
	element.set_attribute_ns_for_bindings(none, 'Uppercase', 'hidden')!
	element.set_attribute_ns_for_bindings('urn:a', 'duplicate', 'first')!
	element.set_attribute_ns_for_bindings('urn:b', 'duplicate', 'second')!
	attributes := element.attributes()
	names := attributes.supported_property_names()
	assert element.attribute_list_size() == 3003
	assert names.len == 3001
	for index in 0 .. 3000 {
		assert names[index] == 'data-${index}'
	}
	assert names.last() == 'duplicate'
	assert attributes.is_supported_property_name('data-1234')
	assert attributes.is_supported_property_name('duplicate')
	assert !attributes.is_supported_property_name('Uppercase')
	assert !attributes.is_supported_property_name('uppercase')
	assert !attributes.is_supported_property_name('missing')
	assert attributes.get_named_item('duplicate')?.value() == 'first'
}

fn test_named_node_map_uppercase_names_remain_supported_on_svg_and_xml_elements() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut svg := document.create_element_ns(namespace_svg_uri, 'svg')!
	svg.set_attribute_ns_for_bindings(none, 'viewBox', '0 0 10 10')!
	assert svg.attributes().supported_property_names() == ['viewBox']
	assert svg.attributes().is_supported_property_name('viewBox')
	assert !svg.attributes().is_supported_property_name('viewbox')
	document.set_document_type(.xml)
	mut element := document.create_element_ns(namespace_html_uri, 'div')!
	element.set_attribute_ns_for_bindings(none, 'Uppercase', 'kept')!
	assert element.attributes().supported_property_names() == ['Uppercase']
	assert element.attributes().is_supported_property_name('Uppercase')
}
