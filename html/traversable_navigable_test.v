module html

import dom

__global traversable_deactivation_completed bool

@[heap]
struct HistoryStepObservation {
mut:
	completed bool
	result    HistoryStepResult
}

@[heap]
struct SynchronousHistoryStepObservation {
mut:
	ran_while_outer_step_was_paused bool
}

fn (mut observation HistoryStepObservation) complete(result HistoryStepResult) {
	observation.completed = true
	observation.result = result
}

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
	assert traversable.current_session_history_step() == 0
	traversable.process_session_history_traversal_queue()
	assert traversable.current_session_history_step() == 0
	mut traversal_event_loop := main_thread_event_loop()
	traversal_event_loop.process()
	traversal_event_loop.process()
	assert traversable.current_session_history_step() == 2
	assert traversable.active_session_history_entry()? == second
	mut mutable_document := unsafe { &dom.Document(document) }
	assert mutable_document.history().length == 3
	assert mutable_document.history().index == 2
}

fn test_synchronous_navigation_steps_jump_the_queue_while_history_application_is_paused() {
	mut traversable := TraversableNavigable.create_a_fresh_top_level_traversable(dom.URL{
		value: 'https://example.test/zero'
	}, EmptyDocumentResource{})!
	document := traversable.active_document() or { panic('missing document') }
	second := traversal_entry(1, 'https://example.test/one', document)
	traversable.append_session_history_entry(second)
	host := traversable.host_navigable_ or { panic('missing host navigable') }
	mut sync_observation := &SynchronousHistoryStepObservation{}
	traversable.append_session_history_synchronous_navigation_steps(host, fn [mut sync_observation, traversable] (signal &TraversalPromiseState) {
		sync_observation.ran_while_outer_step_was_paused = traversable.running_nested_apply_history_step()
		signal.resolve()
	})

	mut completion := &HistoryStepObservation{}
	traversable.apply_the_traverse_history_step(1, none, none, .none_, fn [mut completion] (result HistoryStepResult) {
		completion.complete(result)
	})
	mut event_loop := main_thread_event_loop()
	event_loop.process()
	assert sync_observation.ran_while_outer_step_was_paused
	assert !completion.completed
	event_loop.process()
	assert completion.completed
	assert completion.result == .applied
}

fn test_synchronous_history_step_does_not_strand_a_fresh_navigation() {
	mut traversable := TraversableNavigable.create_a_fresh_top_level_traversable(dom.URL{
		value: 'https://example.test/current'
	}, EmptyDocumentResource{})!
	current := traversable.active_session_history_entry() or { panic('missing current entry') }
	target := traversal_entry(1, 'https://example.test/replaced', traversable.active_document() or {
		panic('missing active document')
	})
	traversable.append_session_history_entry(target)
	host := traversable.host_navigable_ or { panic('missing host navigable') }
	mut model := NavigableModel.create(host, none)!
	model.set_ongoing_navigation(NavigableOngoingNavigation{
		kind: .navigation
		id: 'fresh-navigation'
	})
	mut completion := &HistoryStepObservation{}
	traversable.apply_the_push_or_replace_history_step(1, .replace, .none_, .yes, fn [mut completion] (result HistoryStepResult) {
		completion.complete(result)
	})

	assert completion.completed
	assert completion.result == .applied
	assert model.ongoing_navigation() == NavigableOngoingNavigation{
		kind: .navigation
		id: 'fresh-navigation'
	}
	assert traversable.active_session_history_entry()? == current
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
	mut observation := &HistoryStepObservation{}
	traversable.apply_the_traverse_history_step(1, none, none, .none_, fn [mut observation] (result HistoryStepResult) {
		observation.complete(result)
	})
	assert !observation.completed
	mut event_loop := main_thread_event_loop()
	event_loop.process()
	assert !observation.completed
	event_loop.process()
	assert observation.completed
	assert observation.result == .applied
	traversable.clear_the_forward_session_history()
	assert traversable.session_history_entries().len == 2
	assert !traversable.can_go_forward()

	replacement := traversal_entry(99, 'https://example.test/replaced', document)
	traversable.active_session_history_entry_ = replacement
	mut replacement_observation := &HistoryStepObservation{}
	finalize_a_same_document_navigation(mut traversable, replacement, one, .replace, .none_, fn [mut replacement_observation] (result HistoryStepResult) {
		replacement_observation.complete(result)
	})
	assert !replacement_observation.completed
	event_loop.process()
	event_loop.process()
	assert replacement_observation.completed
	assert traversable.current_session_history_step() == 1
	assert traversable.active_session_history_entry()? == replacement
}

fn test_superseded_same_document_navigation_retains_replacement_without_becoming_active() {
	mut traversable := TraversableNavigable.create_a_fresh_top_level_traversable(dom.URL{
		value: 'https://example.test/zero'
	}, EmptyDocumentResource{})!
	document := traversable.active_document() or { panic('missing document') }
	replaced := traversable.active_session_history_entry() or { panic('missing entry') }
	superseded := traversal_entry(99, 'https://example.test/replaced', document)
	newer := traversal_entry(1, 'https://example.test/newer', document)
	traversable.append_session_history_entry(newer)
	traversable.active_session_history_entry_ = newer

	mut observation := &HistoryStepObservation{}
	finalize_a_same_document_navigation(mut traversable, superseded, replaced, .replace, .none_, fn [mut observation] (result HistoryStepResult) {
		observation.complete(result)
	})

	entries := traversable.session_history_entries()
	assert entries.len == 2
	assert entries[0] == superseded
	assert session_history_entry_step(superseded)? == 0
	assert entries[1] == newer
	assert traversable.current_session_history_step() == 0
	assert traversable.active_session_history_entry()? == newer
	assert observation.completed
	assert observation.result == .applied
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
	mut cancellation := &HistoryStepObservation{}
	traversable.apply_the_traverse_history_step(2, none, none, .none_, fn [mut cancellation] (result HistoryStepResult) {
		cancellation.complete(result)
	})
	assert !cancellation.completed
	mut event_loop := main_thread_event_loop()
	event_loop.process()
	assert cancellation.completed
	assert cancellation.result == .canceled_by_before_unload
	assert traversable.active_document()? == first_document

	traversable.set_before_unload_hook(none)
	mut application := &HistoryStepObservation{}
	traversable.apply_the_traverse_history_step(2, none, none, .none_, fn [mut application] (result HistoryStepResult) {
		application.complete(result)
	})
	assert !application.completed
	event_loop.process()
	assert !application.completed
	event_loop.process()
	event_loop.process()
	assert application.completed
	assert application.result == .applied
	traversable.set_system_visibility_state(.visible)
	assert traversable.system_visibility_state() == .visible
	traversable.set_has_system_focus(true)
	assert traversable.currently_focused_area()? == unsafe { &dom.Node(second_document) }
	assert !traversable.is_closing()
	traversable.close_top_level_traversable()
	assert traversable.is_closing()
	assert !traversable.has_been_destroyed()
	// The maintained document back-pointer makes the active document visible to
	// the unload check, whose task must run before the queued destruction step.
	event_loop.process()
	traversable.process_session_history_traversal_queue()
	assert traversable.has_been_destroyed()
	assert traversable !in user_agent_top_level_traversable_set()
	// A repeated close is ignored after the flag has been set.
	traversable.close_top_level_traversable()
	assert traversable.is_closing()
}

fn test_history_application_populates_a_missing_document_before_activation() {
	mut traversable := TraversableNavigable.create_a_fresh_top_level_traversable(dom.URL{
		value: 'https://example.test/zero'
	}, EmptyDocumentResource{})!
	old_document := traversable.active_document() or { panic('missing active document') }
	target := &SessionHistoryEntry{
		step: 1
		url: dom.URL{ value: 'https://example.test/restored' }
		document_state: &DocumentState{
			origin: dom.Origin{ value: 'https://example.test' }
			resource: '<!doctype html><html><body>restored</body></html>'
			ever_populated: true
		}
	}
	traversable.append_session_history_entry(target)
	mut observation := &HistoryStepObservation{}
	traversable.apply_the_traverse_history_step(1, none, none, .none_, fn [mut observation] (result HistoryStepResult) {
		observation.complete(result)
	})
	mut event_loop := main_thread_event_loop()
	for _ in 0 .. 20 {
		if observation.completed {
			break
		}
		event_loop.process()
	}

	assert observation.completed
	assert observation.result == .applied
	assert traversable.active_session_history_entry()? == target
	new_document := target.document() or { panic('history entry was not populated') }
	assert new_document.url.serialize() == 'https://example.test/restored'
	assert new_document.body() != none
	assert old_document.has_been_destroyed()
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

fn test_queue_screenshot_task_marks_the_traversable_for_repaint() {
	mut traversable := TraversableNavigable.create_a_fresh_top_level_traversable(dom.URL{
		value: 'https://example.test/screenshot'
	}, EmptyDocumentResource{})!
	host := traversable.host_navigable_ or { panic('missing host navigable') }
	mut model := NavigableModel.create(host, none)!
	model.record_display_list_and_scroll_state(dom.PaintConfig{})
	assert !model.needs_repaint()

	traversable.queue_screenshot_task(none)
	assert model.needs_repaint()
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
