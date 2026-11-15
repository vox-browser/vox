module html

import dom

fn test_input_range_replacement_reaches_concrete_value_and_dirty_owner() {
	mut document := parse_document('<input value="base">')
	element := document.query_selector('input') or { panic('Missing input') }
	mut model := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
	model.text_control.set_range_text('X', 0, 2, .select)!
	assert model.value() == 'Xse' && model.value_ == 'Xse'
	assert model.dirty_value_ && model.text_control.dirty_value_flag
	mut mutable_element := unsafe { &dom.Element(element) }
	mutable_element.set_attribute_value('value', 'new default')
	assert model.value() == 'Xse' && model.default_value() == 'new default'
}

fn test_textarea_range_replacement_preserves_live_value_after_default_change() {
	mut document := parse_document('<textarea>base</textarea>')
	element := document.query_selector('textarea') or { panic('Missing textarea') }
	mut model := HTMLTextAreaElementModel.create(unsafe { &dom.HTMLTextAreaElement(element) })
	model.text.set_range_text('X', 0, 2, .select)!
	model.set_default_value('later')
	assert model.value() == 'Xse' && model.default_value() == 'later'
	assert model.dirty_value && model.text.dirty_value_flag && !model.value_user_edited
}

fn test_invalid_range_marks_concrete_owner_dirty_before_throwing_index_size_error() {
	mut document := parse_document('<input value="base"><textarea>base</textarea>')
	input := document.query_selector('input') or { panic('Missing input') }
	mut model := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(input) })
	if _ := model.text_control.set_range_text('x', 3, 1, .preserve) { assert false }
	else { assert err.msg().starts_with('IndexSizeError:') }
	assert model.dirty_value_ && model.value() == 'base'
	area := document.query_selector('textarea') or { panic('Missing textarea') }
	mut textarea := HTMLTextAreaElementModel.create(unsafe { &dom.HTMLTextAreaElement(area) })
	if _ := textarea.text.set_range_text('x', 3, 1, .preserve) { assert false }
	else { assert err.msg().starts_with('IndexSizeError:') }
	assert textarea.dirty_value && textarea.value() == 'base'
}

fn test_textarea_selection_and_replacement_count_normalized_api_newlines() {
	mut document := parse_document('<textarea></textarea>')
	element := document.query_selector('textarea') or { panic('Missing textarea') }
	mut model := HTMLTextAreaElementModel.create(unsafe { &dom.HTMLTextAreaElement(element) })
	model.set_value('a\r\nb\rc')
	assert model.raw_value_ == 'a\r\nb\rc' && model.value() == 'a\nb\nc'
	assert model.text.selection_end() == 5
	model.text.set_range_text('X', 2, 3, .select)!
	assert model.value() == 'a\nX\nc'
	assert model.text.selection_start() == 2 && model.text.selection_end() == 3
}

fn test_textarea_clone_keeps_raw_value_and_normalized_selection_text() {
	mut document := parse_document('<textarea></textarea><textarea></textarea>')
	elements := document.query_selector_all('textarea') or { panic('Missing textareas') }
	mut source := HTMLTextAreaElementModel.create(unsafe { &dom.HTMLTextAreaElement(elements.item(0)?) })
	mut copy := HTMLTextAreaElementModel.create(unsafe { &dom.HTMLTextAreaElement(elements.item(1)?) })
	source.set_value('a\r\nb')
	source.cloned(mut copy, false)
	assert copy.raw_value_ == source.raw_value_ && copy.value() == 'a\nb'
	assert copy.text.relevant_value() == 'a\nb'
}

fn test_script_range_replacement_clears_user_edit_length_constraint_state() {
	mut document := parse_document('<input maxlength=1 value="abc">')
	element := document.query_selector('input') or { panic('Missing input') }
	mut model := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
	model.set_value('abc')!
	model.value_last_changed_by_user_edit_ = true; model.update_validity()
	assert model.control.suffering_from_being_too_long()
	model.text_control.set_range_text('d', 0, 1, .preserve)!
	assert model.value() == 'dbc' && !model.value_last_changed_by_user_edit_
	assert !model.control.suffering_from_being_too_long()
}

fn test_select_has_broader_input_applicability_than_selection_range() {
	mut document := parse_document('<input type=email value="a@example.test">')
	element := document.query_selector('input') or { panic('Missing input') }
	mut model := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
	model.text_control.select()
	assert model.text_control.selection_start() == 0
	assert model.text_control.selection_end() == 14
	assert model.text_control.selection_start_binding() == none
}
