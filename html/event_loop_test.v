module html

import dom
import requestidlecallback

struct EventLoopTestCalls {
mut:
	values []string
}

struct RenderingResizeObserverState {
mut:
	gathered_depths []int
	broadcasts      int
	active          bool
}

fn rendering_resize_observer_gather(target voidptr, depth int) {
	mut state := unsafe { &RenderingResizeObserverState(target) }
	state.gathered_depths << depth
	state.active = state.broadcasts == 0
}

fn rendering_resize_observer_broadcast(target voidptr) int {
	mut state := unsafe { &RenderingResizeObserverState(target) }
	state.broadcasts++
	state.active = false
	return 7
}

fn rendering_resize_observer_has_active(target voidptr) bool {
	state := unsafe { &RenderingResizeObserverState(target) }
	return state.active
}

fn rendering_resize_observer_has_skipped(_ voidptr) bool {
	return false
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

fn test_rendering_scheduler_counters_track_tasks_requests_and_updates() {
	mut event_loop := EventLoop.create(.window)
	event_loop.request_rendering_update()
	event_loop.request_rendering_update()
	assert event_loop.rendering_scheduler_counters().update_requests == 2
	assert event_loop.rendering_scheduler_counters().coalesced_update_requests == 1
	assert !event_loop.rendering_opportunity(10, true)
	counters_after_opportunity := event_loop.rendering_scheduler_counters()
	assert counters_after_opportunity.opportunities_received == 1
	assert counters_after_opportunity.watchdog_opportunities == 1
	mut queue := event_loop.task_queue()
	queue.add(Task.create(.posted_message, none, fn () {}))
	event_loop.process()
	assert event_loop.rendering_scheduler_counters().tasks_between_updates == 1
	assert event_loop.rendering_scheduler_counters().posted_message_tasks_between_updates == 1
	event_loop.update_the_rendering()
	assert event_loop.rendering_scheduler_counters().updates_run == 1
	event_loop.reset_rendering_scheduler_counters()
	assert event_loop.rendering_scheduler_counters() == RenderingSchedulerCounters{}
}

fn test_task_ids_are_unique_and_monotonic() {
	first := Task.create(.unspecified, none, fn () {})
	second := Task.create(.unspecified, none, fn () {})
	assert second.id() == first.id() + 1
}

fn test_event_loop_task_generation_advances_once_per_processing_turn() {
	mut event_loop := EventLoop.create(.window)
	assert event_loop.task_generation() == 0
	event_loop.process()
	assert event_loop.task_generation() == 1
	event_loop.process()
	assert event_loop.task_generation() == 2
}

fn test_idle_periods_are_paced_across_nested_callbacks() {
	mut event_loop := main_thread_event_loop()
	event_loop.task_queue_.tasks.clear()
	event_loop.microtask_queue.clear()
	event_loop.idle_period_timer_ = none

	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	document.set_origin(document.url.origin())
	window_pointer := WindowModel.create_top_level(document, none, 'idle-test') or {
		panic(err)
	}
	document.update_the_visibility_state(.visible)
	mut window := window_pointer
	mut calls := &EventLoopTestCalls{}
	second := fn [mut calls] (_ requestidlecallback.IdleDeadline) ! {
		calls.values << 'second'
	}
	cancelled := fn [mut calls] (_ requestidlecallback.IdleDeadline) ! {
		calls.values << 'cancelled'
	}
	first := fn [mut calls, window_pointer, second, cancelled] (_ requestidlecallback.IdleDeadline) ! {
		calls.values << 'first'
		mut callback_window := window_pointer
		cancelled_handle := callback_window.request_idle_callback(cancelled, requestidlecallback.IdleRequestOptions{})
		callback_window.cancel_idle_callback(cancelled_handle)
		callback_window.request_idle_callback(second, requestidlecallback.IdleRequestOptions{})
		queue_a_task(.microtask, main_thread_event_loop(), none, fn [mut calls] () {
			calls.values << 'microtask'
		})
	}
	window.request_idle_callback(first, requestidlecallback.IdleRequestOptions{})

	// The first empty turn opens one idle period and arms its full budget.
	event_loop.process()
	assert event_loop.idle_period_timer_ != none
	assert event_loop.idle_period_timer_active()
	assert window.idle_request_callbacks_.len == 0
	assert window.runnable_idle_callbacks_.len == 1

	// The callback and its microtask run, but its nested registration remains
	// pending while the current period's timer is active.
	event_loop.process()
	assert calls.values == ['first', 'microtask']
	assert window.idle_request_callbacks_.len == 1
	assert window.runnable_idle_callbacks_.len == 0
	event_loop.process()
	assert calls.values == ['first', 'microtask']

	mut timer := event_loop.idle_period_timer_ or { panic('missing idle timer') }
	timer.fire()
	event_loop.process()
	assert window.idle_request_callbacks_.len == 0
	assert window.runnable_idle_callbacks_.len == 1
	event_loop.process()
	assert calls.values == ['first', 'microtask', 'second']
	assert 'cancelled' !in calls.values
}

fn test_hidden_document_keeps_idle_callbacks_pending() {
	mut event_loop := main_thread_event_loop()
	event_loop.task_queue_.tasks.clear()
	event_loop.microtask_queue.clear()
	event_loop.idle_period_timer_ = none

	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	document.set_origin(document.url.origin())
	window_pointer := WindowModel.create_top_level(document, none, 'hidden-idle-test') or {
		panic(err)
	}
	document.update_the_visibility_state(.hidden)
	mut window := window_pointer
	mut calls := &EventLoopTestCalls{}
	callback := fn [mut calls] (_ requestidlecallback.IdleDeadline) ! {
		calls.values << 'idle'
	}
	window.request_idle_callback(callback, requestidlecallback.IdleRequestOptions{})
	window.start_an_idle_period()
	assert window.idle_request_callbacks_.len == 1
	assert window.runnable_idle_callbacks_.len == 0
	event_loop.process()
	assert calls.values.len == 0

	document.update_the_visibility_state(.visible)
	window.start_an_idle_period()
	window.invoke_idle_callbacks()
	assert calls.values == ['idle']
	event_loop.task_queue_.tasks.clear()
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

fn test_remove_and_take_first_runnable_matching() {
	mut event_loop := EventLoop.create(.window)
	mut queue := event_loop.task_queue()
	queue.add(Task.create(.networking, none, fn () {}))
	queue.add(Task.create(.dom_manipulation, none, fn () {}))
	queue.add(Task.create(.networking, none, fn () {}))
	queue.remove_tasks_matching(fn (task &Task) bool {
		return task.source == .dom_manipulation
	})
	first := queue.take_first_runnable_matching(fn (task &Task) bool {
		return task.source == .networking
	}) or { panic('missing first networking task') }
	second := queue.take_first_runnable_matching(fn (task &Task) bool {
		return task.source == .networking
	}) or { panic('missing second networking task') }
	assert first.id() < second.id()
	assert queue.is_empty()
}

fn test_main_thread_event_loop_is_stable() {
	assert main_thread_event_loop() == main_thread_event_loop()
}

fn test_window_document_lifecycle_uses_the_real_main_thread_event_loop() {
	mut document := dom.Document.create(dom.url_about_blank())
	window := WindowModel.create_top_level(document, none, 'lifecycle-test') or { panic('${err}') }
	mut event_loop := main_thread_event_loop()
	mut is_registered := false
	for registered in event_loop.documents_ {
		if voidptr(registered) == voidptr(document) {
			is_registered = true
			break
		}
	}
	assert is_registered
	assert window.environment_settings_ != unsafe { nil }
	assert !window.environment_settings_.settings.execution_ready()

	document.make_active()
	assert window.environment_settings_.settings.execution_ready()

	mut queue := event_loop.task_queue()
	queue.add(Task.create(.dom_manipulation, document, fn () {}))
	assert queue.tasks.any(fn [document] (task &Task) bool {
		task_document := task.document() or { return false }
		return voidptr(task_document) == voidptr(document)
	})
	document.destroy()
	assert !queue.tasks.any(fn [document] (task &Task) bool {
		task_document := task.document() or { return false }
		return voidptr(task_document) == voidptr(document)
	})

	document.finalize()
	for registered in event_loop.documents_ {
		assert voidptr(registered) != voidptr(document)
	}
}

fn test_dom_history_state_uses_html_structured_deserialization() {
	mut document := dom.Document.create(dom.url_about_blank())
	_ = WindowModel.create_top_level(document, none, 'history-state-test') or { panic('${err}') }
	record := structured_serialize_for_storage(dom.js_string('restored')) or { panic('${err}') }
	entry := &dom.SessionHistoryEntry{
		url: dom.URL{ value: 'https://example.test/' }
		classic_history_api_state: dom.DOMSerializationRecord{
			data: record.data.clone()
		}
	}
	document.restore_the_history_object_state(entry)
	assert document.history().state.kind == .string
	assert document.history().state.string_data == 'restored'

	broken_entry := &dom.SessionHistoryEntry{
		classic_history_api_state: dom.DOMSerializationRecord{
			data: [u8(255)]
		}
	}
	document.restore_the_history_object_state(broken_entry)
	assert document.history().state.kind == .null_
	document.finalize()
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

fn test_event_loop_exact_registration_realm_and_pause_algorithms() {
	mut event_loop := EventLoop.create(.window)
	mut queue := event_loop.task_queue()
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

fn test_rendering_updates_content_visibility_proximity_and_resize_observers_to_a_fixed_point() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut html_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or {
		panic('${err}')
	}
	mut far_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(html_element.as_node()) or { panic('${err}') }
	mut html_node := html_element.as_node()
	html_node.append_child(far_element.as_node()) or { panic('${err}') }

	mut close_box := &dom.PaintableBox{
		Paintable: dom.Paintable{
			is_box: true
		}
		dom_node_: html_element.as_node()
		scrollable_overflow_rect_: dom.CSSPixelRect_{
			x_: 25
			y_: 25
			width_: 20
			height_: 20
		}
	}
	mut far_box := &dom.PaintableBox{
		Paintable: dom.Paintable{
			is_box: true
		}
		dom_node_: far_element.as_node()
		scrollable_overflow_rect_: dom.CSSPixelRect_{
			x_: 500
			y_: 500
			width_: 20
			height_: 20
		}
	}
	html_node.set_paintable(unsafe { &dom.Paintable(close_box) })
	mut far_node := far_element.as_node()
	far_node.set_paintable(unsafe { &dom.Paintable(far_box) })
	mut viewport_paintable := &dom.ViewportPaintable{}
	viewport_paintable.set_paintable_boxes_with_auto_content_visibility([close_box, far_box])
	document.set_viewport_paintable(viewport_paintable)
	document.set_viewport_rect(dom.Rect{0, 0, 100, 100})
	document.update_the_visibility_state(.visible)

	mut navigable := &dom.Navigable{
		active_document_: document
		is_top_level_traversable_: true
	}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)

	mut resize_state := &RenderingResizeObserverState{}
	document.register_resize_observer(&dom.ResizeObserver{
		target: voidptr(resize_state)
		gather_at_depth: rendering_resize_observer_gather
		broadcast: rendering_resize_observer_broadcast
		has_active: rendering_resize_observer_has_active
		has_skipped: rendering_resize_observer_has_skipped
	})

	mut event_loop := EventLoop.create(.window)
	event_loop.register_document(document)
	event_loop.update_the_rendering()

	assert html_element.proximity_to_the_viewport() == .close_to_the_viewport
	assert far_element.proximity_to_the_viewport() == .far_away_from_the_viewport
	assert resize_state.gathered_depths == [0, 7]
	assert resize_state.broadcasts == 1
	event_loop.unregister_document(document)
}
