// SPDX-License-Identifier: BSD-2-Clause
module html

import dom

fn test_select_validity_state_observes_live_selectedness_and_required_attribute() {
	mut document := parse_document('<select required><option value="">Choose</option><option value="v">V</option></select>')
	element := document.query_selector('select') or { panic('Missing select') }
	native := unsafe { &dom.HTMLSelectElement(element) }
	mut model := HTMLSelectElementModel.create(native)
	state := ValidityState.create(model.control)
	assert state.value_missing() && !state.valid()
	set_html_select_element_value(native, 'v')
	assert !state.value_missing() && state.valid()
	set_html_select_element_selected_index(native, -1)
	assert state.value_missing()
	mut mutable_element := unsafe { &dom.Element(element) }
	mutable_element.remove_attribute('required')
	assert !state.value_missing() && state.valid()
}

fn test_textarea_validity_state_observes_clean_default_value_changes() {
	mut document := parse_document('<textarea required>initial</textarea>')
	element := document.query_selector('textarea') or { panic('Missing textarea') }
	mut model := HTMLTextAreaElementModel.create(unsafe { &dom.HTMLTextAreaElement(element) })
	state := ValidityState.create(model.control)
	assert state.valid()
	model.set_default_value('')
	assert state.value_missing() && !state.valid()
	model.set_default_value('restored')
	assert state.valid() && !model.dirty_value
}

fn test_validity_state_refreshes_input_owner_without_relying_on_snapshots() {
	mut document := parse_document('<input required>')
	element := document.query_selector('input') or { panic('Missing input') }
	mut model := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
	state := ValidityState.create(model.control)
	assert state.value_missing()
	model.value_ = 'live'
	assert state.valid() && !state.value_missing()
	model.value_ = ''
	assert !model.control.satisfies_its_constraints()
}

fn test_custom_validity_normalizes_to_lf_and_retains_error_while_barred() {
	mut document := parse_document('<input>')
	element := document.query_selector('input') or { panic('Missing input') }
	mut model := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
	state := ValidityState.create(model.control)
	model.control.set_custom_validity('first\r\nsecond\rthird')
	assert model.control.validation_message() == 'first\nsecond\nthird'
	mut mutable_element := unsafe { &dom.Element(element) }
	mutable_element.set_attribute_value('disabled', '')
	assert !model.control.will_validate() && model.control.validation_message() == ''
	assert state.custom_error() && !state.valid() && model.control.check_validity()
	model.control.set_custom_validity('')
	assert state.valid()
}

fn test_form_validation_includes_live_select_owner_constraints() {
	mut document := parse_document('<form><select required><option value="">Choose</option><option value="v">V</option></select></form>')
	form_element := document.query_selector('form') or { panic('Missing form') }
	mut form := HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(form_element) })
	assert !form.check_validity()
	select_element := document.query_selector('select') or { panic('Missing select') }
	set_html_select_element_value(unsafe { &dom.HTMLSelectElement(select_element) }, 'v')
	assert form.check_validity()
}

fn test_readonly_form_associated_custom_element_is_barred_from_validation() {
	mut document := parse_document('<div readonly></div>')
	element := document.query_selector('div') or { panic('Missing element') }
	mut control := FormAssociatedElement.create_custom(element)
	control.set_custom_validity('invalid')
	assert !control.will_validate() && control.check_validity()
	assert !ValidityState.create(control).valid()
}

fn test_live_radio_validation_distinguishes_control_and_form_identity() {
	mut document := parse_document('<form id=f><input id=a type=radio name=g required><input id=b type=radio name=g></form><form><input id=c type=radio name=g required></form>')
	a := document.query_selector('#a') or { panic('Missing radio') }
	b := document.query_selector('#b') or { panic('Missing radio') }
	c := document.query_selector('#c') or { panic('Missing radio') }
	first := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(a) })
	mut second := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(b) })
	other_form := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(c) })
	assert !first.control.satisfies_its_constraints()
	second.set_checked_binding(true)
	assert first.control.satisfies_its_constraints()
	assert !other_form.control.satisfies_its_constraints()
}
