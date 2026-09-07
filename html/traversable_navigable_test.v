module html

import dom

__global traversable_deactivation_completed bool

fn traversable_deactivation_completion() {
	traversable_deactivation_completed = true
}

fn traversal_entry(step int, url string, document &dom.Document) &SessionHistoryEntry {
	return &SessionHistoryEntry{
		step: step
		url: dom.URL{
			value: url
		}
		document_state: &DocumentState{
			document: document
			origin: document.origin()
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
			id: 'child'
			entries: [traversal_entry(1, 'https://example.test/child', document)]
		},
	]
	second := traversal_entry(2, 'https://example.test/two', document)
	traversable.append_session_history_entry(second)
	host := traversable.host_navigable_ or { panic('missing host navigable') }
	assert traversable.get_all_navigables_that_only_need_history_object_length_index_update(0) == [
		host,
	]
	assert traversable.get_all_navigables_whose_current_session_history_entry_will_change_or_reload(2) == [
		host,
	]
	assert traversable.get_all_navigables_that_might_experience_a_cross_document_traversal(2).len == 0
	assert traversable.get_session_history_entries_for_the_navigation_api(host, 2).len == 1
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
	assert traversable !in user_agent_top_level_traversable_set()
}

fn test_top_level_traversable_registry_creation_and_deactivation() {
	created := create_a_new_top_level_browsing_context_and_document(&dom.Page{})!
	assert created.document != unsafe { nil }
	mut traversable := TraversableNavigable.create_a_fresh_top_level_traversable(dom.URL{
		value: 'https://example.test/active'
	}, EmptyDocumentResource{})!
	assert traversable in user_agent_top_level_traversable_set()
	document := traversable.active_document() or { panic('missing active document') }
	host := traversable.host_navigable_ or { panic('missing host navigable') }
	mut model := NavigableModel.create(host, none)!
	model.set_ongoing_navigation(NavigableOngoingNavigation{
		kind: .navigation
		id: 'pending'
	})
	entry := traversable.active_session_history_entry() or { panic('missing entry') }
	unsafe { traversable_deactivation_completed = false }
	deactivate_a_document_for_cross_document_navigation(document, none, entry, traversable_deactivation_completion)
	assert model.ongoing_navigation().kind == .empty
	assert document.has_been_destroyed()
	unsafe { assert traversable_deactivation_completed }
	traversable.destroy_top_level_traversable()
}

fn test_top_level_traversable_status_follows_the_host_parent() {
	mut traversable := TraversableNavigable.create_a_new_top_level_traversable('')!
	assert traversable.is_top_level_traversable()

	parent := &dom.Navigable{}
	mut child := &dom.Navigable{
		parent_: parent
	}
	traversable.set_host_navigable(child)
	assert !traversable.is_top_level_traversable()

	child.parent_ = none
	assert traversable.is_top_level_traversable()
	traversable.destroy_top_level_traversable()
}
