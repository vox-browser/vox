module html

import dom
import editing

fn history_input(value string) (&dom.Document, &HTMLInputElementModel, &editing.EditingHistory) {
	mut document := parse_document('<!doctype html><body><input id="control" value="${value}"></body>')
	element := document.get_element_by_id('control') or { panic('missing input') }
	mut model := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
	document.set_focused_area(element.as_node())
	history := editing.install_editing_history(document)
	return document, model, history
}

fn test_text_control_history_undoes_and_redoes_utf16_insertion() {
	document, model_pointer, history_pointer := history_input('A😀B')
	mut model := unsafe { &HTMLInputElementModel(model_pointer) }
	mut history := unsafe { &editing.EditingHistory(history_pointer) }
	model.text_control.set_selection_range(1, 3, 'forward')!
	model.text_control.handle_insert(dom.input_type_insert_text, 'xy')!

	assert model.value() == 'AxyB'
	assert model.text_node_?.data() == 'AxyB'
	assert model.text_control.selection_start() == 3
	assert model.text_control.selection_end() == 3
	assert history.undo(document)
	assert model.value() == 'A😀B'
	assert model.text_node_?.data() == 'A😀B'
	assert model.text_control.selection_start() == 1
	assert model.text_control.selection_end() == 3
	assert model.text_control.selection_direction_state() == .forward

	assert history.redo(document)
	assert model.value() == 'AxyB'
	assert model.text_node_?.data() == 'AxyB'
	assert model.text_control.selection_start() == 3
	assert model.text_control.selection_end() == 3
}

fn test_text_control_history_coalesces_backward_deletions() {
	document, model_pointer, history_pointer := history_input('abcd')
	mut model := unsafe { &HTMLInputElementModel(model_pointer) }
	mut history := unsafe { &editing.EditingHistory(history_pointer) }
	model.text_control.set_selection_range(4, 4, 'none')!
	model.text_control.handle_delete(dom.input_type_delete_content_backward)!
	model.text_control.handle_delete(dom.input_type_delete_content_backward)!

	assert model.value() == 'ab'
	assert history.undo(document)
	assert model.value() == 'abcd'
	assert model.text_control.selection_start() == 2
	assert model.text_control.selection_end() == 4
	assert history.undo(document) == false
}

fn test_text_control_paste_does_not_coalesce_with_typing() {
	document, model_pointer, history_pointer := history_input('a')
	mut model := unsafe { &HTMLInputElementModel(model_pointer) }
	mut history := unsafe { &editing.EditingHistory(history_pointer) }
	model.text_control.set_selection_range(1, 1, 'none')!
	model.text_control.handle_insert(dom.input_type_insert_text, 'x')!
	model.text_control.handle_insert(dom.input_type_insert_from_paste, 'y')!

	assert model.value() == 'axy'
	assert history.undo(document)
	assert model.value() == 'ax'
	assert history.undo(document)
	assert model.value() == 'a'
}
