module layout

import html

fn test_relayout_moves_private_recording_storage_and_preserves_published_lists() {
	mut document := html.parse_document('<!doctype html><div id="changed">before</div>' + '<p>unchanged text</p>'.repeat(16))
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	initial := document.record_display_list()?
	initial_dump := initial.dump()
	initial_commands := display_list_commands(initial)
	mut previous := document_layout_result(document)?
	plan_storage := previous.record_scratch.plan.data
	memo_storage := previous.record_scratch.memo_contexts.data
	mut returned := []PaintCommand{cap: initial_commands.len + 1}
	returned << PaintCommand{kind: 'draw_text', text: 'returned shell vector'}
	returned_storage := returned.data
	recycle_display_list_commands(initial, returned)
	mut changed := document.get_element_by_id('changed')?
	changed.set_inner_html('after')!
	document.update_layout(.debugging)
	mut current := document_layout_result(document)?
	assert voidptr(current) != voidptr(previous)
	assert current.record_scratch.recycled_commands.data == returned_storage
	assert current.record_scratch.plan.data == plan_storage
	assert current.record_scratch.memo_contexts.data == memo_storage
	assert current.record_scratch.plan.len == 0
	assert current.record_scratch.memo_contexts.len == 0
	assert previous.record_scratch.recycled_commands.cap == 0
	assert previous.record_scratch.plan.cap == 0
	assert previous.record_scratch.memo_contexts.cap == 0
	updated := document.record_display_list()?
	assert display_list_commands(updated).data == returned_storage
	assert initial.dump() == initial_dump
	assert display_list_commands(initial).data == initial_commands.data
	assert display_list_commands(initial).any(it.text == 'before')
	assert display_list_commands(updated).any(it.text == 'after')
}

fn test_relayout_recycles_only_vectors_returned_after_the_next_list_is_adopted() {
	mut document := html.parse_document('<!doctype html><style>.collapsed p{display:none}</style><div id="changed">label</div>' + '<p>unchanged text</p>'.repeat(16))
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 300)
	mut current_list := document.record_display_list()?
	initial_list := current_list
	initial_dump := current_list.dump()
	mut adopted := display_list_commands(current_list)
	mut returned_storage := voidptr(0)
	mut changed := document.get_element_by_id('changed')?
	for label in ['one', 'two', 'three', 'four'] {
		changed.set_inner_html(label)!
		document.update_layout(.debugging)
		current_list = document.record_display_list()?
		next := display_list_commands(current_list)
		if returned_storage != unsafe { nil } {
			assert next.data == returned_storage
		}
		assert next.data != adopted.data
		if adopted.data != display_list_commands(initial_list).data {
			recycle_display_list_commands(current_list, adopted)
			returned_storage = adopted.data
		}
		adopted = unsafe { next }
		assert initial_list.dump() == initial_dump
	}
}

fn test_recording_workspace_is_not_moved_between_documents_or_without_layout() {
	mut first := html.parse_document('<!doctype html><p>first document</p>')
	mut second := html.parse_document('<!doctype html><p>second document</p>')
	defer { first.finalize(); second.finalize() }
	assert take_document_recording_scratch(second).recycled_commands.cap == 0
	_ = layout_document_typed_in_viewport(first, 400, 300)
	list := first.record_display_list()?
	mut returned := []PaintCommand{cap: 16}
	returned << PaintCommand{kind: 'draw_text', text: 'private to first'}
	recycle_display_list_commands(list, returned)
	_ = layout_document_typed_in_viewport(second, 400, 300)
	assert document_layout_result(second)?.record_scratch.recycled_commands.cap == 0
	assert document_layout_result(first)?.record_scratch.recycled_commands.data == returned.data
}
