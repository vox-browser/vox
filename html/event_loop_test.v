module html

import dom

struct EventLoopTestCalls {
mut:
	values []string
}

fn test_task_queue_runs_runnable_tasks_in_order() {
	mut event_loop := EventLoop.create(.window)
	mut calls := &EventLoopTestCalls{}
	first := Task.create(.dom_manipulation, none, fn [mut calls] () {
		calls.values << '1'
	})
	second := Task.create(.networking, none, fn [mut calls] () {
		calls.values << '2'
	})
	mut queue := event_loop.task_queue()
	queue.add(first)
	queue.add(second)
	assert queue.has_runnable_tasks()
	event_loop.process()
	assert calls.values == ['1']
	event_loop.process()
	assert calls.values == ['1', '2']
	assert queue.is_empty()
}

fn test_task_ids_are_unique_and_monotonic() {
	first := Task.create(.unspecified, none, fn () {})
	second := Task.create(.unspecified, none, fn () {})
	assert second.id() == first.id() + 1
}

fn test_microtask_checkpoint_after_task() {
	mut event_loop := EventLoop.create(.window)
	mut calls := &EventLoopTestCalls{}
	microtask := Task.create(.microtask, none, fn [mut calls] () {
		calls.values << 'microtask'
	})
	task := Task.create(.dom_manipulation, none, fn [mut calls, mut event_loop, microtask] () {
		calls.values << 'task'
		event_loop.enqueue_microtask(microtask)
	})
	mut queue := event_loop.task_queue()
	queue.add(task)
	event_loop.process()
	assert calls.values == ['task', 'microtask']
}

fn test_remove_and_take_tasks_matching() {
	mut event_loop := EventLoop.create(.window)
	mut queue := event_loop.task_queue()
	queue.add(Task.create(.networking, none, fn () {}))
	queue.add(Task.create(.dom_manipulation, none, fn () {}))
	queue.add(Task.create(.networking, none, fn () {}))
	queue.remove_tasks_matching(fn (task &Task) bool {
		return task.source == .dom_manipulation
	})
	matching := queue.take_tasks_matching(fn (task &Task) bool {
		return task.source == .networking
	})
	assert matching.len == 2
	assert queue.is_empty()
}

fn test_main_thread_event_loop_is_stable() {
	assert main_thread_event_loop() == main_thread_event_loop()
}

fn test_parallel_queue_exact_create_and_enqueue() {
	mut calls := &EventLoopTestCalls{}
	queue := ParallelQueue.create()
	task_id := queue.enqueue(fn [mut calls] () {
		calls.values << 'parallel'
	})
	assert task_id > 0
	mut event_loop := main_thread_event_loop()
	event_loop.process()
	assert calls.values == ['parallel']
}

fn test_event_loop_exact_source_spin_registration_realm_and_pause_algorithms() {
	mut event_loop := EventLoop.create(.window)
	mut calls := &EventLoopTestCalls{}
	mut queue := event_loop.task_queue()
	queue.add(Task.create(.networking, none, fn [mut calls] () {
		calls.values << 'network'
	}))
	queue.add(Task.create(.dom_manipulation, none, fn [mut calls] () {
		calls.values << 'dom'
	}))
	event_loop.spin_processing_tasks_with_source_until(.networking, fn [calls] () bool {
		return calls.values.len == 1
	})
	assert calls.values == ['network']
	assert !queue.is_empty()

	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	mut navigable := &dom.Navigable{
		active_document_: document
		is_top_level_traversable_: true
	}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)
	event_loop.register_document(document)
	active := event_loop.documents_in_this_event_loop_matching(fn (candidate &dom.Document) bool {
		return candidate.is_fully_active()
	})
	assert active == [document]
	realm := &ScriptingRealm{}
	event_loop.push_onto_backup_incumbent_realm_stack(realm)
	assert event_loop.top_of_backup_incumbent_realm_stack() == realm
	event_loop.pop_backup_incumbent_realm_stack()
	assert event_loop.is_backup_incumbent_realm_stack_empty()

	event_loop.queue_task_to_update_the_rendering()
	assert queue.has_rendering_tasks()
	handle := event_loop.pause()
	assert event_loop.execution_paused()
	event_loop.unpause(handle)
	assert !event_loop.execution_paused()
	assert event_loop.compute_deadline() >= 0
	event_loop.unregister_document(document)
}
