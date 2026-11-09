module dom

fn test_set_attribute_changes_first_qualified_match_and_preserves_namespace_identity() {
	mut document := Document.create(url_about_blank())
	document.set_document_type(.html)
	defer { document.finalize() }
	for foreign_first in [true, false] {
		mut element := document.create_element('div')!
		if !foreign_first { element.set_attribute_value('data-key', 'null value') }
		element.set_attribute_value_ns('data-key', 'foreign value', none, 'urn:foreign')
		if foreign_first { element.set_attribute_value('data-key', 'null value') }
		foreign := element.get_attribute_node_ns('urn:foreign', 'data-key')?
		null_attribute := element.get_attribute_node_ns(none, 'data-key')?
		before := element.attribute_list()?.attrs.map(voidptr(it))
		version := document.attribute_version()
		element.set_attribute_for_bindings('DATA-KEY', 'changed')!
		assert element.get_attribute('data-key')? == 'changed'
		assert foreign.value() == if foreign_first { 'changed' } else { 'foreign value' }
		assert null_attribute.value() == if foreign_first { 'null value' } else { 'changed' }
		assert element.attribute_list()?.attrs.map(voidptr(it)) == before
		assert foreign.namespace_uri()? == 'urn:foreign' && foreign.prefix() == none
		assert document.attribute_version() > version
	}
}

fn test_set_attribute_preserves_svg_case_prefix_and_falls_back_to_a_null_namespace() {
	mut document := Document.create(url_about_blank())
	document.set_document_type(.html)
	defer { document.finalize() }
	mut element := document.create_element_ns('http://www.w3.org/2000/svg', 'svg')!
	element.set_attribute_value('viewBox', 'upper')
	element.set_attribute_value('viewbox', 'lower')
	element.set_attribute_value_ns('href', 'foreign', 'xlink', 'http://www.w3.org/1999/xlink')
	element.set_attribute_value('xlink:href', 'null')
	foreign := element.get_attribute_node_ns('http://www.w3.org/1999/xlink', 'href')?
	null_attribute := element.get_attribute_node_ns(none, 'xlink:href')?
	element.set_attribute_for_bindings('viewBox', 'new upper')!
	element.set_attribute_for_bindings('xlink:href', 'new foreign')!
	assert element.get_attribute('viewBox')? == 'new upper'
	assert element.get_attribute('viewbox')? == 'lower'
	assert foreign.value() == 'new foreign' && null_attribute.value() == 'null'
	assert foreign.prefix()? == 'xlink' && foreign.local_name() == 'href'
	element.set_attribute_for_bindings('p:missing', 'new')!
	created := element.get_attribute_node('p:missing')?
	assert created.local_name() == 'p:missing' && created.prefix() == none && created.namespace_uri() == none
}
