module html

import dom

fn dataset_test_element() &dom.Element {
	document := parse_document('<div data-user-id="42" data-empty="" data--odd="x"></div>')
	document_element := document.document_element() or { panic('missing html') }
	body := document_element.as_node().children_as_vector()[1]
	return body.children_as_vector()[0].as_element() or { panic('missing div') }
}

fn test_dom_string_map_pairs_and_named_property() {
	element := dataset_test_element()
	dataset := DOMStringMap.create(element)
	assert dataset.supported_property_names() == ['userId', 'empty', 'Odd']
	assert dataset.determine_value_of_named_property('userId') == '42'
}

fn test_dom_string_map_set_and_delete() {
	element := dataset_test_element()
	mut dataset := DOMStringMap.create(element)
	dataset.set_value_of_named_property('accountName', 'alice')!
	assert element.get_attribute('data-account-name')? == 'alice'
	dataset.delete_value('accountName')
	assert element.get_attribute('data-account-name') == none

	if _ := dataset.set_value_of_named_property('bad-name', 'x') {
		assert false
	} else {
		assert err.msg().contains("'-' followed by a lowercase")
	}
}
