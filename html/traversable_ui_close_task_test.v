module html

import dom
import page

@[heap]
struct TraversableUICloseTaskObservation {
mut:
	events           []string
	blocked_task_ran bool
}

fn traversable_ui_close_task_fixture(address string) !(&dom.Document, &WindowModel, &TraversableNavigable, &dom.Navigable) {
	owner := page.Page.create(1)!
	url := dom.URL{value: address}
	document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	window := unsafe { &WindowModel(document.get_window() or { return error('missing actual Window') }) }
	native := document.navigable() or { return error('missing actual native Navigable') }
	mut traversable := TraversableNavigable.new()
	traversable.set_host_navigable(native)
	traversable.active_document_ = document
	return document, window, traversable, native
}

fn traversable_ui_close_task_observe(document &dom.Document, window &WindowModel, native &dom.Navigable, name string, observation &TraversableUICloseTaskObservation) {
	target := unsafe { &dom.EventTarget(window) }
	target.add_event_listener_without_options('unload', dom.IDLEventListener.create(&dom.CallbackType{
		associated_window: unsafe { &dom.Window(window) }
		handle_event:      fn [document, target, native, name, observation] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert voidptr(event.target() or { panic('missing actual legacy unload target') }) == voidptr(document)
			assert voidptr(event.current_target() or { panic('missing actual Window current target') }) == voidptr(target)
			// The Source task unloads its current Document before destroying the
			// Traversable, whose inherited flag is still live during dispatch.
			assert !native.has_been_destroyed()
			mut state := unsafe { &TraversableUICloseTaskObservation(observation) }
			state.events << name
			return dom.js_undefined()
		}
	}))
}

fn test_ui_close_entry_point_queues_null_document_task_and_unloads_actual_window_once() {
	mut document, window, mut traversable, native := traversable_ui_close_task_fixture('https://ui-close-task.example/current')!
	defer { document.finalize() }
	observation := &TraversableUICloseTaskObservation{}
	traversable_ui_close_task_observe(document, window, native, 'current', observation)
	traversable.run_ui_traversable_close_unload_task()
	mut event_loop := main_thread_event_loop()
	task := event_loop.task_queue().last_added_task()?
	assert task.source() == .navigation_and_traversal
	assert task.document() == none && task.is_runnable() && !task.is_permanently_unrunnable()
	assert observation.events.len == 0 && !document.has_been_destroyed() && !native.has_been_destroyed()
	assert traversable.traversal_queue_.queue.len == 0 && !traversable.close_steps_have_been_appended_
	event_loop.process()
	assert observation.events == ['current']
	assert document.has_been_destroyed() && document.get_unload_counter() == 0
	assert native.has_been_destroyed() && traversable.has_been_destroyed()
	assert native.active_document() == none && navigable_model_for_host(native) == none
	event_loop.process()
	assert observation.events == ['current']
}

fn test_ui_close_task_selects_actual_replacement_at_execution_while_old_document_task_is_blocked() {
	mut original, original_window, mut traversable, native := traversable_ui_close_task_fixture('https://ui-close-task.example/original')!
	observation := &TraversableUICloseTaskObservation{}
	traversable_ui_close_task_observe(original, original_window, native, 'old', observation)
	queue_global_task(.dom_manipulation, unsafe { &dom.Window(original_window) }, fn [observation] () {
		mut state := unsafe { &TraversableUICloseTaskObservation(observation) }
		state.blocked_task_ran = true
	})
	mut event_loop := main_thread_event_loop()
	blocked := event_loop.task_queue().last_added_task()?
	traversable.run_ui_traversable_close_unload_task()
	task := event_loop.task_queue().last_added_task()?
	url := dom.URL{value: 'https://ui-close-task.example/replacement'}
	mut replacement := create_navigation_document_for_page(url, url.origin(), original, original.page())!
	replacement_window := unsafe { &WindowModel(replacement.get_window()?) }
	defer {
		original.destroy()
		original.finalize()
		replacement.finalize()
	}
	traversable_ui_close_task_observe(replacement, replacement_window, native, 'replacement', observation)
	assert voidptr(replacement.navigable()?) == voidptr(native)
	assert voidptr(traversable.active_document_?) == voidptr(original)
	assert voidptr(traversable.active_document()?) == voidptr(replacement)
	assert !original.is_fully_active() && replacement.is_fully_active()
	assert !blocked.is_runnable() && task.document() == none && task.is_runnable()
	event_loop.process()
	assert observation.events == ['replacement'] && !observation.blocked_task_ran
	assert !original.has_been_destroyed() && replacement.has_been_destroyed()
	assert native.has_been_destroyed() && traversable.active_document() == none
	event_loop.process()
	assert observation.events == ['replacement'] && !observation.blocked_task_ran
}

fn test_ui_close_null_document_task_survives_document_destruction_and_destroys_actual_traversable() {
	mut document, window, mut traversable, native := traversable_ui_close_task_fixture('https://ui-close-task.example/null-active')!
	defer { document.finalize() }
	observation := &TraversableUICloseTaskObservation{}
	traversable_ui_close_task_observe(document, window, native, 'destroyed', observation)
	traversable.run_ui_traversable_close_unload_task()
	mut event_loop := main_thread_event_loop()
	queue := event_loop.task_queue()
	task := queue.last_added_task()?
	document.destroy()
	assert native.active_document() == none && traversable.active_document() == none
	assert !native.has_been_destroyed() && navigable_model_for_host(native) != none
	assert queue.tasks.any(voidptr(it) == voidptr(task))
	assert task.document() == none && task.is_runnable() && !task.is_permanently_unrunnable()
	event_loop.process()
	assert observation.events.len == 0 && document.get_unload_counter() == 0
	assert native.has_been_destroyed() && navigable_model_for_host(native) == none
	assert traversable !in user_agent_top_level_traversable_set()
}

fn test_ui_close_current_document_without_node_navigable_is_unloaded_without_a_fully_active_gate() {
	mut document, window, mut traversable, native := traversable_ui_close_task_fixture('https://ui-close-task.example/inactive-current')!
	defer { document.finalize() }
	observation := &TraversableUICloseTaskObservation{}
	traversable_ui_close_task_observe(document, window, native, 'inactive-current', observation)
	traversable.run_ui_traversable_close_unload_task()
	document.set_navigable(none)
	assert !document.is_fully_active() && document.navigable() == none
	assert voidptr(traversable.active_document()?) == voidptr(document)
	mut event_loop := main_thread_event_loop()
	task := event_loop.task_queue().last_added_task()?
	assert task.document() == none && task.is_runnable()
	event_loop.process()
	assert observation.events == ['inactive-current']
	assert document.has_been_destroyed() && native.has_been_destroyed()
	assert native.active_document() == none
}
