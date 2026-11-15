module html

import dom

fn test_checkbox_and_radio_default_on_applies_only_to_absent_value_attribute() {
	for type_ in ['checkbox', 'radio'] {
		mut document := dom.Document.create(dom.url_about_blank())
		mut element := document.create_element('input')!
		element.set_attribute_value('type', type_)
		mut input := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
		assert input.value() == 'on'
		input.set_value('')!
		assert element.has_attribute('value') && input.value() == ''
		element.set_attribute_value('value', 'selected')
		assert input.value() == 'selected'
		element.remove_attribute('value')
		assert input.value() == 'on'
	}
}

fn test_default_on_value_attribute_does_not_change_dirty_checkedness() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element('input')!
	mut input := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
	input.set_type('checkbox')
	input.set_checked_binding(true)
	input.set_value('')!
	assert input.checked() && input.value() == ''
	element.set_attribute_value('value', 'v')
	assert input.checked() && input.value() == 'v'
}
