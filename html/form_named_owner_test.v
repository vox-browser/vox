// SPDX-License-Identifier: BSD-2-Clause
module html

import dom

fn test_form_past_name_survives_rename_and_lazy_same_owner_queries() {
	mut document := parse_document('<form><input name=before></form>')
	form_element := document.query_selector('form') or { panic('Missing form') }
	input_element := document.query_selector('input') or { panic('Missing input') }
	mut form := HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(form_element) })
	form.elements().length()
	first := form.named_item_value('before')
	is_element := first is HTMLFormControlsCollectionElement
	assert is_element
	mut input := unsafe { &dom.Element(input_element) }
	input.set_attribute_value('name', 'after')
	mut model := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(input_element) })
	model.control.set_form(unsafe { &dom.HTMLFormElement(form_element) })
	form.get_submittable_elements()
	assert form.is_supported_property_name('before')
	remembered := form.named_item_value('before')
	is_remembered_element := remembered is HTMLFormControlsCollectionElement
	assert is_remembered_element
	assert voidptr((remembered as HTMLFormControlsCollectionElement).element) == voidptr(input_element)
}

fn test_form_owner_change_removes_past_names_from_the_old_form() {
	mut document := parse_document('<form id=f><input name=before></form><form id=g></form>')
	form_element := document.query_selector('#f') or { panic('Missing form') }
	input_element := document.query_selector('input') or { panic('Missing input') }
	mut form := HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(form_element) })
	form.elements().length()
	form.named_item_value('before')
	mut input := unsafe { &dom.Element(input_element) }
	input.set_attribute_value('name', 'after')
	assert form.is_supported_property_name('before')
	input.set_attribute_value('form', 'g')
	assert !form.is_supported_property_name('before') && !form.is_supported_property_name('after')
	result := form.named_item_value('before')
	is_empty := result is HTMLFormControlsCollectionEmpty
	assert is_empty
}

fn test_form_control_registration_and_removal_use_record_identity() {
	mut document := parse_document('<form><button id=a></button><button id=b></button></form>')
	element := document.query_selector('form') or { panic('Missing form') }
	a := document.query_selector('#a') or { panic('Missing button') }
	b := document.query_selector('#b') or { panic('Missing button') }
	mut form := HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(element) })
	mut first := HTMLButtonElementModel.create(unsafe { &dom.HTMLButtonElement(a) })
	second := HTMLButtonElementModel.create(unsafe { &dom.HTMLButtonElement(b) })
	form.add_control(mut first.control)
	assert form.controls().len == 2
	form.remove_control(first.control)
	controls := form.controls()
	assert controls.len == 1 && voidptr(controls[0]) == voidptr(second.control)
	assert first.control.form() == none
}

fn test_saved_form_collection_and_radio_list_follow_the_form_root() {
	mut document := parse_document('<body><input id=outside name=g form=f></body>')
	body := document.query_selector('body') or { panic('Missing body') }
	mut form_element := document.create_element('form')!
	form_element.set_attribute_value('id', 'f')
	for _ in 0 .. 2 {
		mut input := document.create_element('input')!
		input.set_attribute_value('name', 'g')
		form_element.append_child(input)
	}
	mut form := HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(form_element) })
	collection := form.elements()
	result := collection.named_item_value('g')
	is_list := result is HTMLFormControlsCollectionRadioNodeList
	assert is_list
	list := (result as HTMLFormControlsCollectionRadioNodeList).list
	assert collection.length() == 2 && list.length() == 2
	mut parent := unsafe { &dom.Element(body) }
	parent.append_child(form_element)
	assert collection.length() == 3 && list.length() == 3
	first := collection.item(0) or { panic('Missing outside control') }
	assert first.get_attribute_value('id') == 'outside'
	form_element.remove(false)
	assert collection.length() == 2 && list.length() == 2
}
