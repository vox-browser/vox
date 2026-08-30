module html

import dom

const form_controls_html_namespace = 'http://www.w3.org/1999/xhtml'

fn form_controls_accept_input(element &dom.Element) bool {
	return element.local_name() == 'input'
}

fn form_controls_create_input(document &dom.Document, name string, value ?string) !&dom.Element {
	mut input := document.create_element_ns(form_controls_html_namespace, 'input')!
	input.set_attribute_value('type', 'radio')
	input.set_attribute_value('name', name)
	if actual_value := value {
		input.set_attribute_value('value', actual_value)
	}
	return input
}

fn test_radio_node_list_value_is_live_and_updates_checkedness() {
	mut document := dom.Document.create_for_fragment_parsing()
	mut form := document.create_element_ns(form_controls_html_namespace, 'form')!
	first := form_controls_create_input(document, 'choice', none)!
	second := form_controls_create_input(document, 'choice', 'two')!
	form.append_child(first)
	form.append_child(second)
	mut list := RadioNodeList.create(form.as_node(), .descendants, fn (node &dom.Node) bool {
		element := node.as_element() or { return false }
		return element.get_attribute('name') or { '' } == 'choice'
	})
	assert list.length() == 2
	assert list.value() == ''
	list.set_value('on')
	assert list.value() == 'on'
	list.set_value('two')
	assert list.value() == 'two'
	assert !html_input_element_checked(unsafe { &dom.HTMLInputElement(first) })
	assert html_input_element_checked(unsafe { &dom.HTMLInputElement(second) })
	third := form_controls_create_input(document, 'choice', 'three')!
	form.append_child(third)
	assert list.length() == 3
}

fn test_html_form_controls_collection_named_item_result() {
	mut document := dom.Document.create_for_fragment_parsing()
	mut form := document.create_element_ns(form_controls_html_namespace, 'form')!
	mut first := form_controls_create_input(document, 'choice', 'one')!
	first.set_attribute_value('id', 'only-id')
	second := form_controls_create_input(document, 'choice', 'two')!
	form.append_child(first)
	form.append_child(second)
	collection := HTMLFormControlsCollection.create(unsafe { &dom.ParentNode(form) }, .descendants, form_controls_accept_input)
	assert collection.length() == 2
	assert collection.named_item_or_radio_node_list('missing') is HTMLFormControlsCollectionEmpty
	assert collection.named_item_value('missing') is HTMLFormControlsCollectionEmpty
	single := collection.named_item_or_radio_node_list('only-id')
	assert single is HTMLFormControlsCollectionElement
	assert voidptr((single as HTMLFormControlsCollectionElement).element) == voidptr(first)
	multiple := collection.named_item_or_radio_node_list('choice')
	assert multiple is HTMLFormControlsCollectionRadioNodeList
	mut radios := (multiple as HTMLFormControlsCollectionRadioNodeList).list
	assert radios.length() == 2
	radios.set_value('two')
	assert radios.value() == 'two'
}
