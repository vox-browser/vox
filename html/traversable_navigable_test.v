module html

import dom

fn traversal_entry(step int, url string, document &dom.Document) &SessionHistoryEntry {
	return &SessionHistoryEntry{
		step:           step
		url:            dom.URL{
			value: url
		}
		document_state: &DocumentState{
			document: document
			origin:   document.origin()
		}
	}
}

fn test_traversable_used_steps_length_index_and_delta() {
	mut traversable := TraversableNavigable.create_a_fresh_top_level_traversable(dom.URL{
		value: 'https://example.test/zero'
	}, EmptyDocumentResource{})!
	document := traversable.active_document() or { panic('missing document') }
	first := traversable.active_session_history_entry() or { panic('missing entry') }
	mut state := unsafe { &DocumentState(first.document_state?) }
	state.nested_histories = [
		NestedHistory{
			id:      'child'
			entries: [traversal_entry(1, 'https://example.test/child', document)]
		},
	]
	second := traversal_entry(2, 'https://example.test/two', document)
	traversable.append_session_history_entry(second)
	assert traversable.get_all_used_history_steps() == [0, 1, 2]
	position := traversable.get_the_history_object_length_and_index(1)!
	assert position.script_history_length == 3
	assert position.script_history_index == 1
	assert traversable.get_the_used_step(9)! == 2
	assert traversable.can_go_forward()
	traversable.traverse_the_history_by_delta(2, none)
	assert traversable.current_session_history_step() == 2
	assert traversable.active_session_history_entry()? == second
}

fn test_traversable_clear_forward_and_finalize_navigation() {
	mut traversable := TraversableNavigable.create_a_fresh_top_level_traversable(dom.URL{
		value: 'https://example.test/zero'
	}, EmptyDocumentResource{})!
	document := traversable.active_document() or { panic('missing document') }
	one := traversal_entry(1, 'https://example.test/one', document)
	two := traversal_entry(2, 'https://example.test/two', document)
	traversable.append_session_history_entry(one)
	traversable.append_session_history_entry(two)
	assert traversable.apply_the_traverse_history_step(1, none, none, .none_) == .applied
	traversable.clear_the_forward_session_history()
	assert traversable.session_history_entries().len == 2
	assert !traversable.can_go_forward()

	replacement := traversal_entry(99, 'https://example.test/replaced', document)
	finalize_a_same_document_navigation(mut traversable, replacement, one, .replace, .none_)
	assert traversable.current_session_history_step() == 1
	assert traversable.active_session_history_entry()? == replacement
}

fn cancel_traversable_before_unload(documents []&dom.Document) CheckIfUnloadingIsCanceledResult {
	assert documents.len == 1
	return .canceled_by_before_unload
}

fn test_traversable_cancellation_visibility_focus_and_close() {
	mut traversable := TraversableNavigable.create_a_fresh_top_level_traversable(dom.URL{
		value: 'https://example.test/zero'
	}, EmptyDocumentResource{})!
	first_document := traversable.active_document() or { panic('missing document') }
	mut second_document := &dom.Document{}
	second_document.set_url(dom.URL{ value: 'https://example.test/two' })
	second := traversal_entry(2, 'https://example.test/two', second_document)
	traversable.append_session_history_entry(second)
	traversable.set_before_unload_hook(cancel_traversable_before_unload)
	assert traversable.apply_the_traverse_history_step(2, none, none, .none_) == .canceled_by_before_unload
	assert traversable.active_document()? == first_document

	traversable.set_before_unload_hook(none)
	assert traversable.apply_the_traverse_history_step(2, none, none, .none_) == .applied
	traversable.set_system_visibility_state(.visible)
	assert traversable.system_visibility_state() == .visible
	traversable.set_has_system_focus(true)
	assert traversable.currently_focused_area()? == unsafe { &dom.Node(second_document) }
	traversable.close_top_level_traversable()
	assert traversable.has_been_destroyed()
}
