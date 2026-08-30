module html

import dom

const form_associated_html_namespace = 'http://www.w3.org/1999/xhtml'

fn test_form_associated_validity_and_form_owner() {
	mut document := dom.Document.create_for_fragment_parsing()
	mut form := document.create_element_ns(form_associated_html_namespace, 'form')!
	mut input := document.create_element_ns(form_associated_html_namespace, 'input')!
	form.append_child(input)
	mut control := FormAssociatedElement.create(input)
	control.form_node_was_inserted()
	assert control.form() != none
	assert (control.form()?).associated_elements_.len == 1
	assert control.will_validate()
	control.missing_ = true
	validity := ValidityState.create(control)
	assert validity.value_missing()
	assert !validity.valid()
	assert !control.check_validity()
	assert control.validation_message() == 'Invalid form'
	control.set_custom_validity('line one\nline two')
	assert validity.custom_error()
	assert control.validation_message() == 'line one\r\nline two'
	control.missing_ = false
	control.set_custom_validity('')
	assert validity.valid()
	assert control.check_validity()
}

fn test_form_associated_candidate_rules_and_form_action() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/forms/page' })
	mut hidden := document.create_element_ns(form_associated_html_namespace, 'input')!
	hidden.set_attribute_value('type', 'hidden')
	mut hidden_control := FormAssociatedElement.create(hidden)
	assert !hidden_control.will_validate()
	hidden.set_attribute_value('type', 'text')
	assert hidden_control.will_validate()
	hidden.set_attribute_value('readonly', '')
	assert !hidden_control.will_validate()
	hidden.remove_attribute('readonly')
	hidden.set_attribute_value('formaction', '../submit')
	assert hidden_control.form_action() == 'https://example.test/submit'
}

fn test_form_associated_text_control_selection_and_utf16_ranges() {
	mut document := dom.Document.create_for_fragment_parsing()
	input := document.create_element_ns(form_associated_html_namespace, 'input')!
	mut control := FormAssociatedElement.create(input)
	mut text := FormAssociatedTextControlElement.create(control, 'A😀BC')
	text_node := dom.Text.new(document, 'A😀BC')
	text.text_node_ = text_node
	text.set_selection_range(1, 3, 'forward')!
	assert text.selection_start_binding()? == 1
	assert text.selection_end_binding()? == 3
	assert text.selected_text_for_stringifier()? == '😀'
	text.set_range_text('xy', 1, 3, .select)!
	assert text.relevant_value() == 'AxyBC'
	assert text.selection_start() == 1
	assert text.selection_end() == 3
	text.handle_insert('insertText', 'Z')!
	assert text.relevant_value() == 'AZBC'
	assert text.selection_start() == 2
	text.handle_delete('deleteContentBackward')!
	assert text.relevant_value() == 'ABC'
}
