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

fn test_form_associated_text_control_preserves_visual_line_affinity() {
	mut document := dom.Document.create_for_fragment_parsing()
	input := document.create_element_ns(form_associated_html_namespace, 'input')!
	mut control := FormAssociatedElement.create(input)
	mut text := FormAssociatedTextControlElement.create(control, 'abcd efgh')
	text_node := dom.Text.new(document, 'abcd efgh')
	mut node := text_node.as_node()
	node.set_layout_node(&dom.LayoutNode{
		is_text_node_: true
		visual_lines_data_: &dom.LayoutVisualLines{ values: [
			dom.VisualLine{
				start_offset: 0
				end_offset: 4
				end_offset_with_trailing_whitespace: 5
				has_fragments: true
				caret_stops: [
					dom.VisualCaretStop{offset: 0, inline_coordinate: 0},
					dom.VisualCaretStop{offset: 2, inline_coordinate: 20},
					dom.VisualCaretStop{offset: 4, inline_coordinate: 40},
					dom.VisualCaretStop{offset: 5, inline_coordinate: 48},
				]
			},
			dom.VisualLine{
				start_offset: 5
				end_offset: 9
				end_offset_with_trailing_whitespace: 9
				has_fragments: true
				line_index: 1
				caret_stops: [
					dom.VisualCaretStop{offset: 5, inline_coordinate: 0},
					dom.VisualCaretStop{offset: 7, inline_coordinate: 20},
					dom.VisualCaretStop{offset: 9, inline_coordinate: 40},
				]
			},
		] }
	})
	text.text_node_ = text_node
	text.selection_start_ = 5
	text.selection_end_ = 5
	text.selection_end_affinity_ = .upstream

	text.increment_cursor_position_offset(.yes)
	assert text.selection_end_ == 5
	assert text.selection_end_affinity_ == .downstream
	text.decrement_cursor_position_offset(.yes)
	assert text.selection_end_ == 5
	assert text.selection_end_affinity_ == .upstream

	text.selection_start_ = 2
	text.selection_end_ = 2
	text.selection_end_affinity_ = .downstream
	text.increment_cursor_position_to_next_line(.yes)
	assert text.selection_end_ == 7
	assert text.selection_end_affinity_ == .downstream
	text.move_cursor_to_start_of_current_line(.yes)
	assert text.selection_end_ == 5
	text.move_cursor_to_end_of_current_line(.yes)
	assert text.selection_end_ == 9
}

fn test_document_id_notifications_reset_registered_form_owner() {
	mut document := dom.Document.create_for_fragment_parsing()
	mut root := document.create_element_ns(form_associated_html_namespace, 'html')!
	mut form := document.create_element_ns(form_associated_html_namespace, 'form')!
	form.set_attribute_value('id', 'owner')
	mut input := document.create_element_ns(form_associated_html_namespace, 'input')!
	input.set_attribute_value('form', 'owner')
	root.append_child(form)
	root.append_child(input)
	document.append_child(root)

	mut control := FormAssociatedElement.create(input)
	control.form_node_was_inserted()
	assert control.form() != none
	assert document.form_associated_elements_with_form_attribute.len == 1

	form.set_attribute_value('id', 'renamed')
	assert control.form() == none

	input.remove_attribute('form')
	control.form_node_attribute_changed('form')
	assert document.form_associated_elements_with_form_attribute.len == 0
}
