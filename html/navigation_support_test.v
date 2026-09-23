@[has_globals]
module html

import dom

__global (
	navigation_test_run_count     int
	navigation_test_first_promise &TraversalPromiseState
)

fn navigation_test_first_steps(signal &TraversalPromiseState) {
	unsafe {
		navigation_test_run_count++
		navigation_test_first_promise = signal
	}
}

fn navigation_test_second_steps(signal &TraversalPromiseState) {
	unsafe {
		navigation_test_run_count++
	}
	signal.resolve()
}

fn test_x_frame_options_adherence() {
	destination := dom.Origin{
		value: 'https://example.com'
	}
	mut top_document := dom.Document.create(dom.URL{ value: 'https://example.com/' })
	top_document.set_origin(destination)
	mut top := &dom.Navigable{}
	top.set_active_document(top_document)
	child := &dom.Navigable{
		parent_: top
	}
	assert check_a_navigation_responses_adherence_to_x_frame_options(top, [], [
		'DENY',
	], destination)
	assert !check_a_navigation_responses_adherence_to_x_frame_options(child, [], [
		'deny',
	], destination)
	assert !check_a_navigation_responses_adherence_to_x_frame_options(child, [], [
		'deny',
		'sameorigin',
	], destination)
	assert check_a_navigation_responses_adherence_to_x_frame_options(child, [], [
		'unknown',
		'other',
	], destination)
	assert check_a_navigation_responses_adherence_to_x_frame_options(child, [], [
		'sameorigin',
	], destination)
	policy := SerializedCSPPolicy{
		directives:  [SerializedCSPDirective{ name: 'frame-ancestors' }]
		disposition: .enforce
	}
	assert check_a_navigation_responses_adherence_to_x_frame_options(child, [policy], [
		'deny',
	], destination)

	mut foreign_document := dom.Document.create(dom.URL{ value: 'https://other.example/' })
	foreign_document.set_origin(dom.Origin{ value: 'https://other.example' })
	mut foreign_parent := &dom.Navigable{}
	foreign_parent.set_active_document(foreign_document)
	remote_child := &dom.Navigable{
		parent_: foreign_parent
		// There is intentionally no local container document. The decision
		// must come from the logical parent navigable.
		container_document_: none
	}
	assert !check_a_navigation_responses_adherence_to_x_frame_options(remote_child, [], [
		'sameorigin',
	], destination)
}

fn test_session_history_traversal_queue_waits_for_current_promise() {
	unsafe {
		navigation_test_run_count = 0
		navigation_test_first_promise = &TraversalPromiseState{}
	}
	mut queue := SessionHistoryTraversalQueue{}
	queue.append(navigation_test_first_steps)
	queue.append(navigation_test_second_steps)
	queue.process()
	unsafe {
		assert navigation_test_run_count == 1
		navigation_test_first_promise.resolve()
	}
	unsafe {
		assert navigation_test_run_count == 2
	}
	assert queue.queue.len == 0
	assert queue.current_promise == none
}

fn test_session_history_traversal_queue_retains_a_pending_final_promise() {
	unsafe {
		navigation_test_run_count = 0
		navigation_test_first_promise = &TraversalPromiseState{}
	}
	mut queue := SessionHistoryTraversalQueue{}
	queue.append(navigation_test_first_steps)
	queue.process()
	assert queue.queue.len == 0
	assert queue.scheduled
	assert queue.current_promise? == navigation_test_first_promise

	unsafe {
		navigation_test_first_promise.resolve()
	}
	assert !queue.scheduled
	assert queue.current_promise == none
}

fn test_session_history_traversal_queue_extracts_sync_entry() {
	first := &dom.Navigable{}
	second := &dom.Navigable{}
	mut queue := SessionHistoryTraversalQueue{}
	queue.append_sync(navigation_test_first_steps, first)
	queue.append_sync(navigation_test_second_steps, second)
	entry := queue.first_synchronous_navigation_steps_with_target_navigable_not_contained_in([
		first,
	]) or { panic('missing entry') }
	assert voidptr(entry.target_navigable?) == voidptr(second)
	assert queue.queue.len == 1
	created := SessionHistoryTraversalQueueEntry.create(navigation_test_first_steps, first)
	assert created.target_navigable? == first
	signal := &TraversalPromiseState{}
	created.execute_steps(signal)
	assert navigation_test_first_promise == signal
}

fn test_session_history_traversal_queue_does_not_jump_unready_child_bookkeeping() {
	document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	mut target := &dom.Navigable{
		active_document_: document
	}
	mut model := NavigableModel.create(target, none) or { panic(err) }
	model.has_session_history_entry_and_ready_ = false
	mut queue := SessionHistoryTraversalQueue{}
	queue.append_sync(navigation_test_first_steps, target)
	assert queue.first_synchronous_navigation_steps_with_target_navigable_not_contained_in([]) == none

	model.set_has_session_history_entry_and_ready_for_navigation()
	entry := queue.first_synchronous_navigation_steps_with_target_navigable_not_contained_in([]) or {
		panic('ready child navigation did not jump the queue')
	}
	assert entry.target_navigable()? == target
}
