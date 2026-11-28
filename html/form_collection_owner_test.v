// SPDX-License-Identifier: BSD-2-Clause
module html

import dom

fn test_form_length_counts_lazy_controls_and_external_form_owners() {
	mut document := parse_document('<input form=f><form id=f><input><textarea></textarea><button></button><input type=image></form>')
	element := document.query_selector('form') or { panic('Missing form') }
	mut model := HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(element) })
	assert model.length() == 4
	mut input := document.create_element('input')!
	mut form := unsafe { &dom.Element(element) }
	form.append_child(input)
	assert model.length() == 5 && model.elements().length() == 5
	input.remove(false)
	assert model.length() == 4
}

fn test_radio_named_list_value_does_not_uncheck_an_unrelated_group_with_the_same_id() {
	mut document := parse_document('<form><input id=shared type=radio name=a value=a checked><input id=shared type=radio name=b value=b></form>')
	form := document.query_selector('form') or { panic('Missing form') }
	mut model := HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(form) })
	named := model.elements().named_item_or_radio_node_list('shared')
	assert named is HTMLFormControlsCollectionRadioNodeList
	mut list := (named as HTMLFormControlsCollectionRadioNodeList).list
	list.set_value('b')
	assert html_input_element_checked(unsafe { &dom.HTMLInputElement(list.item(0)?) })
	assert html_input_element_checked(unsafe { &dom.HTMLInputElement(list.item(1)?) })
}

fn test_radio_named_list_value_updates_group_members_outside_the_named_list() {
	mut document := parse_document('<form><input id=shared type=radio name=a value=target><input id=shared type=text><input id=other type=radio name=a value=old checked></form>')
	form := document.query_selector('form') or { panic('Missing form') }
	mut model := HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(form) })
	named := model.elements().named_item_or_radio_node_list('shared')
	assert named is HTMLFormControlsCollectionRadioNodeList
	mut list := (named as HTMLFormControlsCollectionRadioNodeList).list
	list.set_value('target')
	other := document.query_selector('#other') or { panic('Missing radio') }
	assert list.value() == 'target'
	assert !html_input_element_checked(unsafe { &dom.HTMLInputElement(other) })
}
